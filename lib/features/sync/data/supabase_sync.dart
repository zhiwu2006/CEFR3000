import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../session/base_providers.dart';
import '../application/cloud_sync_service.dart';
import '../domain/sync_repository.dart';

/// 项目地址与客户端 publishable key 只能访问 RLS 允许的数据，可以随应用分发；
/// 可用 --dart-define 覆盖。secret / service key 绝不能放进应用。
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://evbhjvxtclkzouylwwlq.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_40_PXzqnDxiUYF9Y5W2snQ_VFajaO--',
);

class SupabaseSyncRemote implements SyncRemote {
  final SupabaseClient client;

  SupabaseSyncRemote(this.client);

  @override
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required bool updateExisting,
  }) async {
    if (rows.isEmpty) return;
    await client
        .from(table)
        .upsert(
          rows,
          onConflict: 'user_id,id',
          ignoreDuplicates: !updateExisting,
        );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSince(
    String table,
    DateTime? since, {
    required int offset,
    required int limit,
  }) async {
    var query = client.from(table).select('payload, updated_at');
    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }
}

/// 只初始化一次；不联网，只恢复本地保存的登录会话。
///
/// `flutter test` 下不初始化：组件测试没有平台插件，初始化会挂起。
final supabaseClientProvider = FutureProvider<SupabaseClient>((ref) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    throw StateError('Cloud sync is disabled in tests');
  }
  if (!_supabaseReady) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    _supabaseReady = true;
  }
  return Supabase.instance.client;
});

bool _supabaseReady = false;

enum CloudSyncPhase { signedOut, codeSent, signedIn }

class CloudSyncState {
  final CloudSyncPhase phase;
  final String? email;
  final bool busy;
  final String? message;
  final String? error;
  final SyncReport? lastReport;

  const CloudSyncState({
    this.phase = CloudSyncPhase.signedOut,
    this.email,
    this.busy = false,
    this.message,
    this.error,
    this.lastReport,
  });

  CloudSyncState copyWith({
    CloudSyncPhase? phase,
    String? email,
    bool? busy,
    String? message,
    String? error,
    SyncReport? lastReport,
    bool clearMessages = false,
  }) => CloudSyncState(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    busy: busy ?? this.busy,
    message: clearMessages ? message : message ?? this.message,
    error: clearMessages ? error : error ?? this.error,
    lastReport: lastReport ?? this.lastReport,
  );
}

/// 邮箱验证码登录与同步。
class CloudSyncController extends StateNotifier<CloudSyncState> {
  final Ref _ref;
  bool _syncing = false;

  CloudSyncController(this._ref) : super(const CloudSyncState()) {
    _restore();
  }

  Future<SupabaseClient> get _client =>
      _ref.read(supabaseClientProvider.future);

  Future<void> _restore() async {
    try {
      final user = (await _client).auth.currentUser;
      if (user != null && mounted) {
        state = state.copyWith(
          phase: CloudSyncPhase.signedIn,
          email: user.email,
        );
      }
    } catch (error) {
      debugPrint('Supabase restore failed: $error');
    }
  }

  Future<void> sendCode(String email) async {
    final address = email.trim();
    if (!address.contains('@')) {
      state = state.copyWith(clearMessages: true, error: '请输入有效的邮箱地址');
      return;
    }
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      await (await _client).auth.signInWithOtp(email: address);
      state = state.copyWith(
        phase: CloudSyncPhase.codeSent,
        email: address,
        busy: false,
        message: '验证码已发送到 $address',
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: '发送失败：${_describe(error)}');
    }
  }

  Future<void> verifyCode(String code) async {
    final email = state.email;
    if (email == null) return;
    state = state.copyWith(busy: true, clearMessages: true);
    try {
      await (await _client).auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code.trim(),
      );
      state = state.copyWith(
        phase: CloudSyncPhase.signedIn,
        busy: false,
        message: '已登录',
      );
      await syncNow();
    } catch (error) {
      state = state.copyWith(busy: false, error: '验证失败：${_describe(error)}');
    }
  }

  void changeEmail() {
    state = const CloudSyncState();
  }

  Future<void> signOut() async {
    try {
      await (await _client).auth.signOut();
    } catch (error) {
      debugPrint('Supabase sign out failed: $error');
    }
    state = const CloudSyncState(message: '已退出登录，本地数据保留');
  }

  /// 已登录时同步；未登录或已有同步在跑时直接返回。
  Future<SyncReport?> syncNow({bool quiet = false}) async {
    if (_syncing) return null;
    final repository = _ref.read(progressRepositoryProvider);
    if (repository is! SyncableProgressRepository) return null;
    final SupabaseClient client;
    try {
      client = await _client;
    } catch (error) {
      debugPrint('Cloud sync unavailable: $error');
      return null;
    }
    final user = client.auth.currentUser;
    if (user == null) return null;
    _syncing = true;
    if (!quiet && mounted) {
      state = state.copyWith(busy: true, clearMessages: true);
    }
    try {
      await _ref.read(initializationProvider.future);
      final report = await CloudSyncService(
        repository: repository as SyncableProgressRepository,
        remote: SupabaseSyncRemote(client),
        userId: user.id,
      ).syncNow();
      if (report.merged.changed) {
        // 合并了其它设备的记录：让首页、统计和计划按新数据重算。
        _ref.invalidate(learningStatsProvider);
        _ref.invalidate(todayStudyPlanProvider);
        _ref.invalidate(todayRecognitionPlanProvider);
        _ref.invalidate(todayDeckProvider);
      }
      if (mounted) {
        state = state.copyWith(
          busy: false,
          lastReport: report,
          message: '同步完成',
        );
      }
      return report;
    } catch (error) {
      debugPrint('Cloud sync failed: $error');
      if (mounted) {
        state = state.copyWith(busy: false, error: '同步失败：${_describe(error)}');
      }
      return null;
    } finally {
      _syncing = false;
    }
  }

  static String _describe(Object error) =>
      error is AuthException || error is PostgrestException
      ? error.toString().replaceFirst(RegExp(r'^\w+Exception\(?'), '')
      : '$error';
}

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncController, CloudSyncState>(
      CloudSyncController.new,
    );
