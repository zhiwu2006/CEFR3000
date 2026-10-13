import '../../../models/exposure_event.dart';
import '../../../models/review_event.dart';
import '../../../models/test_run.dart';
import '../domain/sync_repository.dart';

/// 云端表的最小读写接口，便于在测试里替换 Supabase。
abstract interface class SyncRemote {
  /// 按主键 (user_id, id) 插入；[updateExisting] 为 false 时已存在的行保持不变。
  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required bool updateExisting,
  });

  /// 读取 updated_at 晚于 [since] 的行，按 updated_at 升序。
  Future<List<Map<String, dynamic>>> fetchSince(
    String table,
    DateTime? since, {
    required int offset,
    required int limit,
  });
}

class SyncReport {
  final int pushedEvents;
  final int pushedExposures;
  final int pushedRuns;
  final SyncMergeResult merged;
  final DateTime finishedAt;

  const SyncReport({
    required this.pushedEvents,
    required this.pushedExposures,
    required this.pushedRuns,
    required this.merged,
    required this.finishedAt,
  });
}

/// 把本地学习事实推到云端，再把其它设备的新记录拉回本地合并。
class CloudSyncService {
  static const eventsTable = 'sync_review_events';
  static const exposuresTable = 'sync_exposure_events';
  static const runsTable = 'sync_test_runs';

  /// 拉取时向前回看一段时间，覆盖云端并发提交造成的 updated_at 先后错位；
  /// 重复拉到的行在合并时按 id 去重。
  static const pullOverlap = Duration(minutes: 2);

  final SyncableProgressRepository repository;
  final SyncRemote remote;
  final String userId;
  final DateTime Function() now;
  final int pageSize;

  CloudSyncService({
    required this.repository,
    required this.remote,
    required this.userId,
    DateTime Function()? now,
    this.pageSize = 500,
  }) : now = now ?? DateTime.now;

  /// 游标按账号区分：同一设备换账号登录不会把上一个账号的进度当成已同步。
  String _key(String name) => '$userId:$name';

  Future<SyncReport> syncNow() async {
    final pushed = await _push();
    final merged = await _pull();
    return SyncReport(
      pushedEvents: pushed.$1,
      pushedExposures: pushed.$2,
      pushedRuns: pushed.$3,
      merged: merged,
      finishedAt: now(),
    );
  }

  Future<(int, int, int)> _push() async {
    var events = 0, exposures = 0, runs = 0;
    while (true) {
      final eventsAfter = await _intMeta('push:events');
      final exposuresAfter = await _intMeta('push:exposures');
      final runsAfter = await _intMeta('push:runs');
      final outbox = await repository.pendingOutbox(
        eventsAfter: eventsAfter,
        exposuresAfter: exposuresAfter,
        runsAfter: runsAfter,
        limit: pageSize,
      );
      if (outbox.isEmpty) break;

      if (outbox.events.isNotEmpty) {
        await remote.upsert(eventsTable, [
          for (final (_, e) in outbox.events) _eventRow(e),
        ], updateExisting: false);
        await _setMeta('push:events', outbox.events.last.$1);
        events += outbox.events.length;
      }
      if (outbox.exposures.isNotEmpty) {
        await remote.upsert(exposuresTable, [
          for (final (_, e) in outbox.exposures) _exposureRow(e),
        ], updateExisting: false);
        await _setMeta('push:exposures', outbox.exposures.last.$1);
        exposures += outbox.exposures.length;
      }
      if (outbox.runs.isNotEmpty) {
        // 轮次可能先以未完成状态上传、完成后再上传，所以允许覆盖。
        await remote.upsert(runsTable, [
          for (final (_, r) in outbox.runs) _runRow(r),
        ], updateExisting: true);
        await _setMeta('push:runs', outbox.runs.last.$1);
        runs += outbox.runs.length;
      }
      final full =
          outbox.events.length >= pageSize ||
          outbox.exposures.length >= pageSize ||
          outbox.runs.length >= pageSize;
      if (!full) break;
    }
    return (events, exposures, runs);
  }

  Future<SyncMergeResult> _pull() async {
    final eventRows = await _fetchAll(eventsTable, 'pull:events');
    final exposureRows = await _fetchAll(exposuresTable, 'pull:exposures');
    final runRows = await _fetchAll(runsTable, 'pull:runs');
    if (eventRows.rows.isEmpty &&
        exposureRows.rows.isEmpty &&
        runRows.rows.isEmpty) {
      return SyncMergeResult.empty;
    }
    final result = await repository.mergeSyncedData(
      events: [
        for (final row in eventRows.rows) ReviewEvent.fromJson(_payload(row)),
      ],
      exposures: [
        for (final row in exposureRows.rows)
          ExposureEvent.fromJson(_payload(row)),
      ],
      runs: [for (final row in runRows.rows) TestRun.fromJson(_payload(row))],
    );
    // 合并成功后才推进游标；中途失败下次会重新拉取同一批。
    for (final (name, fetched) in [
      ('pull:events', eventRows),
      ('pull:exposures', exposureRows),
      ('pull:runs', runRows),
    ]) {
      final latest = fetched.latest;
      if (latest != null) {
        await repository.setSyncMeta(_key(name), latest.toIso8601String());
      }
    }
    return result;
  }

  Future<({List<Map<String, dynamic>> rows, DateTime? latest})> _fetchAll(
    String table,
    String cursorName,
  ) async {
    final raw = await repository.getSyncMeta(_key(cursorName));
    final cursor = raw == null ? null : DateTime.tryParse(raw);
    final since = cursor?.subtract(pullOverlap);
    final rows = <Map<String, dynamic>>[];
    DateTime? latest = cursor;
    for (var offset = 0; ; offset += pageSize) {
      final page = await remote.fetchSince(
        table,
        since,
        offset: offset,
        limit: pageSize,
      );
      rows.addAll(page);
      for (final row in page) {
        final updated = DateTime.tryParse('${row['updated_at']}');
        if (updated != null && (latest == null || updated.isAfter(latest))) {
          latest = updated;
        }
      }
      if (page.length < pageSize) break;
    }
    return (rows: rows, latest: latest);
  }

  Map<String, dynamic> _eventRow(ReviewEvent event) => {
    'user_id': userId,
    'id': event.id,
    'word_id': event.attempt.wordId,
    'created_at': event.createdAt.toUtc().toIso8601String(),
    'payload': event.toJson(),
  };

  Map<String, dynamic> _exposureRow(ExposureEvent event) => {
    'user_id': userId,
    'id': event.id,
    'word_id': event.wordId,
    'local_date': event.localDate,
    'payload': event.toJson(),
  };

  Map<String, dynamic> _runRow(TestRun run) => {
    'user_id': userId,
    'id': run.id,
    'started_at': run.startedAt.toUtc().toIso8601String(),
    'finished_at': run.finishedAt?.toUtc().toIso8601String(),
    'payload': run.toJson(),
  };

  static Map<String, dynamic> _payload(Map<String, dynamic> row) =>
      Map<String, dynamic>.from(row['payload'] as Map);

  Future<int> _intMeta(String name) async =>
      int.tryParse(await repository.getSyncMeta(_key(name)) ?? '') ?? 0;

  Future<void> _setMeta(String name, int value) =>
      repository.setSyncMeta(_key(name), '$value');
}
