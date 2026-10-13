import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/secure_credential_store.dart';
import '../../../session/base_providers.dart';
import '../application/cloud_sync_service.dart';
import '../domain/sync_repository.dart';

class SyncHttpException implements Exception {
  final int statusCode;
  final String message;

  const SyncHttpException(this.statusCode, this.message);

  @override
  String toString() =>
      statusCode == 401 ? '同步密钥不正确' : 'HTTP $statusCode：$message';
}

/// 对接 `cloudflare/sync-worker` 的同步客户端（Bearer 密钥认证）。
class CloudflareSyncRemote implements SyncRemote {
  final Uri baseUri;
  final String token;
  final HttpClient _client;

  static const timeout = Duration(seconds: 20);

  CloudflareSyncRemote({
    required this.baseUri,
    required this.token,
    HttpClient? client,
  }) : _client = client ?? (HttpClient()..connectionTimeout = timeout);

  /// 检查地址、密钥和数据库是否可用。
  Future<void> checkHealth() async {
    await _send('GET', baseUri.resolve('/v1/health'));
  }

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required bool updateExisting,
  }) async {
    if (rows.isEmpty) return;
    await _send(
      'POST',
      baseUri.resolve('/v1/push'),
      body: {'table': table, 'rows': rows, 'updateExisting': updateExisting},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince(
    String table,
    DateTime? since, {
    required int offset,
    required int limit,
  }) async {
    final uri = baseUri
        .resolve('/v1/pull')
        .replace(
          queryParameters: {
            'table': table,
            if (since != null) 'since': since.toUtc().toIso8601String(),
            'offset': '$offset',
            'limit': '$limit',
          },
        );
    final body = await _send('GET', uri);
    return List<Map<String, dynamic>>.from(
      (body['rows'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(text) as Map);
    } catch (_) {
      decoded = {'error': text};
    }
    if (response.statusCode != 200) {
      throw SyncHttpException(
        response.statusCode,
        '${decoded['error'] ?? text}',
      );
    }
    return decoded;
  }

  void close() => _client.close(force: true);
}

/// 同步地址存在普通设置里，密钥存在系统安全存储里。
class CloudSyncConfigStore {
  static const _urlKey = 'cloud_sync_url';
  static const _tokenKey = 'vocab_flash.sync.token';
  static const _lastSyncedKey = 'cloud_sync_last_at';

  final Future<SharedPreferences> Function() _prefs;
  final CredentialStore _credentials;

  CloudSyncConfigStore(this._prefs, this._credentials);

  Future<Uri?> readUrl() async {
    final raw = (await _prefs()).getString(_urlKey);
    return raw == null ? null : Uri.tryParse(raw);
  }

  Future<String?> readToken() => _credentials.read(_tokenKey);

  Future<DateTime?> readLastSynced() async {
    final raw = (await _prefs()).getString(_lastSyncedKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSynced(DateTime at) async =>
      (await _prefs()).setString(_lastSyncedKey, at.toIso8601String());

  Future<void> save(Uri url, String token) async {
    await _credentials.write(_tokenKey, token);
    await (await _prefs()).setString(_urlKey, url.toString());
  }

  Future<void> clear() async {
    await (await _prefs()).remove(_urlKey);
    await (await _prefs()).remove(_lastSyncedKey);
    await _credentials.delete(_tokenKey);
  }
}

class CloudSyncState {
  final Uri? url;
  final bool busy;
  final String? message;
  final String? error;
  final SyncReport? lastReport;

  /// 最近一次成功同步的时间（跨重启保留）。
  final DateTime? lastSyncedAt;

  const CloudSyncState({
    this.url,
    this.busy = false,
    this.message,
    this.error,
    this.lastReport,
    this.lastSyncedAt,
  });

  bool get configured => url != null;

  CloudSyncState copyWith({
    Uri? url,
    bool? busy,
    String? message,
    String? error,
    SyncReport? lastReport,
    DateTime? lastSyncedAt,
    bool clearMessages = false,
  }) => CloudSyncState(
    url: url ?? this.url,
    busy: busy ?? this.busy,
    message: clearMessages ? message : message ?? this.message,
    error: clearMessages ? error : error ?? this.error,
    lastReport: lastReport ?? this.lastReport,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

class CloudSyncController extends StateNotifier<CloudSyncState> {
  final Ref _ref;
  final CloudSyncConfigStore _config;
  bool _syncing = false;

  CloudSyncController(this._ref, this._config) : super(const CloudSyncState()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final url = await _config.readUrl();
      final lastSynced = await _config.readLastSynced();
      if (url != null && mounted) {
        state = state.copyWith(url: url, lastSyncedAt: lastSynced);
      }
    } catch (error) {
      debugPrint('Cloud sync config unavailable: $error');
    }
    await importConfigFile();
  }

  /// 从应用专属目录导入 `sync_config.json`（{"url": ..., "token": ...}），
  /// 用来避免在设备上手输 64 位密钥：`adb push` 到
  /// /sdcard/Android/data/<包名>/files/ 后启动应用即可。
  /// 读到后立即删除文件，密钥只保存在系统安全存储里。
  Future<bool> importConfigFile() async {
    final File file;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return false;
      file = File('${dir.path}/$configFileName');
      if (!await file.exists()) return false;
    } catch (error) {
      debugPrint('Sync config file unavailable: $error');
      return false;
    }
    String url = '';
    String token = '';
    try {
      final json = jsonDecode(await file.readAsString()) as Map;
      url = '${json['url'] ?? ''}';
      token = '${json['token'] ?? ''}';
    } catch (error) {
      debugPrint('Sync config file unreadable: $error');
    } finally {
      try {
        await file.delete();
      } catch (error) {
        debugPrint('Unable to delete sync config file: $error');
      }
    }
    if (url.isEmpty || token.isEmpty) {
      if (mounted) {
        state = state.copyWith(clearMessages: true, error: '同步配置文件格式不对');
      }
      return false;
    }
    await connect(url, token);
    return state.configured;
  }

  static const configFileName = 'sync_config.json';

  /// 校验地址与密钥后保存，并立即同步一次。
  Future<void> connect(String rawUrl, String rawToken) async {
    final token = rawToken.trim();
    var text = rawUrl.trim();
    if (text.isNotEmpty && !text.contains('://')) text = 'https://$text';
    final url = Uri.tryParse(text);
    // 只接受 ASCII 主机名：输入法替换出的全角符号会让请求阶段才抛出难懂的错误。
    final validHost =
        url != null &&
        url.host.contains('.') &&
        RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(url.host);
    if (url == null ||
        !url.hasAuthority ||
        url.scheme != 'https' ||
        !validHost) {
      state = state.copyWith(
        clearMessages: true,
        error: '请输入 https:// 开头的 Worker 地址',
      );
      return;
    }
    if (token.length < 32 || !RegExp(r'^[\x21-\x7E]+$').hasMatch(token)) {
      state = state.copyWith(
        clearMessages: true,
        error: '同步密钥至少 32 个字符，只能包含英文字母、数字和符号',
      );
      return;
    }
    state = state.copyWith(busy: true, clearMessages: true);
    final remote = CloudflareSyncRemote(baseUri: url, token: token);
    try {
      await remote.checkHealth();
      await _config.save(url, token);
      state = CloudSyncState(url: url, message: '已连接');
    } catch (error) {
      state = state.copyWith(busy: false, error: '连接失败：$error');
      return;
    } finally {
      remote.close();
    }
    await syncNow();
  }

  Future<void> disconnect() async {
    await _config.clear();
    state = const CloudSyncState(message: '已断开同步，本地数据保留');
  }

  /// 已配置时同步；未配置或已有同步在跑时直接返回。
  Future<SyncReport?> syncNow({bool quiet = false}) async {
    if (_syncing) return null;
    final repository = _ref.read(progressRepositoryProvider);
    if (repository is! SyncableProgressRepository) return null;
    final Uri? url;
    final String? token;
    try {
      url = await _config.readUrl();
      if (url == null) return null;
      token = await _config.readToken();
    } catch (error) {
      debugPrint('Cloud sync config unavailable: $error');
      return null;
    }
    if (token == null) return null;

    _syncing = true;
    if (mounted) {
      // 后台同步也标记 busy，首页状态才能显示「同步中」；只有手动同步清掉旧提示。
      state = quiet
          ? state.copyWith(busy: true)
          : state.copyWith(busy: true, clearMessages: true);
    }
    final remote = CloudflareSyncRemote(baseUri: url, token: token);
    try {
      await _ref.read(initializationProvider.future);
      final report = await CloudSyncService(
        repository: repository as SyncableProgressRepository,
        remote: remote,
        accountKey: url.origin,
      ).syncNow();
      if (report.merged.changed) {
        // 合并了另一台设备的记录：首页、统计和计划按新数据重算。
        _ref.invalidate(learningStatsProvider);
        _ref.invalidate(todayStudyPlanProvider);
        _ref.invalidate(todayRecognitionPlanProvider);
        _ref.invalidate(todayDeckProvider);
      }
      await _config.saveLastSynced(report.finishedAt);
      if (mounted) {
        state = state.copyWith(
          url: url,
          busy: false,
          lastReport: report,
          lastSyncedAt: report.finishedAt,
          clearMessages: true,
          message: '同步完成',
        );
      }
      return report;
    } catch (error) {
      debugPrint('Cloud sync failed: $error');
      if (mounted) {
        state = state.copyWith(busy: false, error: '同步失败：$error');
      }
      return null;
    } finally {
      remote.close();
      _syncing = false;
    }
  }
}

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncController, CloudSyncState>(
      (ref) => CloudSyncController(
        ref,
        CloudSyncConfigStore(
          () => ref.read(sharedPreferencesProvider.future),
          FlutterCredentialStore(),
        ),
      ),
    );
