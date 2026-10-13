import '../../../models/exposure_event.dart';
import '../../../models/review_event.dart';
import '../../../models/test_run.dart';

/// 一次合并远程数据的结果。
class SyncMergeResult {
  final int newEvents;
  final int newExposures;
  final int newRuns;

  /// 因新事件而按事件历史重算了卡片状态的词数。
  final int rebuiltCards;

  const SyncMergeResult({
    required this.newEvents,
    required this.newExposures,
    required this.newRuns,
    required this.rebuiltCards,
  });

  static const empty = SyncMergeResult(
    newEvents: 0,
    newExposures: 0,
    newRuns: 0,
    rebuiltCards: 0,
  );

  bool get changed => newEvents + newExposures + newRuns > 0;
}

/// 待上传的本地记录，按本地写入顺序（rowid）增量读取。
///
/// 用写入顺序而不是作答时间做游标：一轮作答在结束时才落盘，时间戳可能早于
/// 上次同步，按时间会被漏传。
class SyncOutbox {
  final List<(int, ReviewEvent)> events;
  final List<(int, ExposureEvent)> exposures;
  final List<(int, TestRun)> runs;

  const SyncOutbox({
    required this.events,
    required this.exposures,
    required this.runs,
  });

  bool get isEmpty => events.isEmpty && exposures.isEmpty && runs.isEmpty;
}

/// 支持云同步的本地仓储能力。
///
/// 同步只交换只追加的学习事实；卡片状态由 [mergeSyncedData] 按事件历史
/// 在本地重算，所以两台设备各自学习后合并，结果与提交顺序无关。
abstract interface class SyncableProgressRepository {
  Future<String?> getSyncMeta(String key);

  Future<void> setSyncMeta(String key, String value);

  /// 读取写入顺序在各游标之后的记录（只含已提交事件）。
  Future<SyncOutbox> pendingOutbox({
    required int eventsAfter,
    required int exposuresAfter,
    required int runsAfter,
    int limit = 500,
  });

  /// 在一个事务里写入本地缺少的事件、接触与轮次，并重算受影响的卡片。
  Future<SyncMergeResult> mergeSyncedData({
    required List<ReviewEvent> events,
    required List<ExposureEvent> exposures,
    required List<TestRun> runs,
  });
}
