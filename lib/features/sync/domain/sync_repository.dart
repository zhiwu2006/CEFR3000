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

  /// 采用了远程标记（疑难、已认识、暂不学习）的词数。
  final int changedFlags;

  const SyncMergeResult({
    required this.newEvents,
    required this.newExposures,
    required this.newRuns,
    required this.rebuiltCards,
    this.changedFlags = 0,
  });

  SyncMergeResult withFlags(int changedFlags) => SyncMergeResult(
    newEvents: newEvents,
    newExposures: newExposures,
    newRuns: newRuns,
    rebuiltCards: rebuiltCards,
    changedFlags: changedFlags,
  );

  static const empty = SyncMergeResult(
    newEvents: 0,
    newExposures: 0,
    newRuns: 0,
    rebuiltCards: 0,
  );

  bool get changed => newEvents + newExposures + newRuns + changedFlags > 0;
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

/// 一个词的用户标记快照（疑难、已认识、暂不学习），按 [changedAt] 后写者胜。
///
/// 标记是用户意图而不是学习事实，没法像作答事件那样合并，只能取最新的一次。
class WordFlagChange {
  final int wordId;
  final bool difficult;
  final bool known;
  final bool suspended;
  final DateTime changedAt;

  const WordFlagChange({
    required this.wordId,
    required this.difficult,
    required this.known,
    required this.suspended,
    required this.changedAt,
  });

  String get id => 'w:$wordId';

  bool sameFlags(WordFlagChange other) =>
      difficult == other.difficult &&
      known == other.known &&
      suspended == other.suspended;

  /// 时间相同（比如两台设备都在首次同步时补录）时按内容决胜，保证各端结果一致。
  bool isNewerThan(WordFlagChange other) {
    final byTime = changedAt.compareTo(other.changedAt);
    if (byTime != 0) return byTime > 0;
    return _rank > other._rank;
  }

  int get _rank => (difficult ? 4 : 0) | (known ? 2 : 0) | (suspended ? 1 : 0);

  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'difficult': difficult,
    'known': known,
    'suspended': suspended,
    'changedAt': changedAt.toUtc().toIso8601String(),
  };

  factory WordFlagChange.fromJson(Map<String, dynamic> json) => WordFlagChange(
    wordId: json['wordId'] as int,
    difficult: json['difficult'] as bool,
    known: json['known'] as bool,
    suspended: json['suspended'] as bool,
    changedAt: DateTime.parse(json['changedAt'] as String),
  );
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

  /// 本地标记变更里序号在 [after] 之后的（序号, 快照），按序号升序。
  Future<List<(int, WordFlagChange)>> pendingFlagChanges({
    required int after,
    int limit = 500,
  });

  /// 应用比本地更新的远程标记，返回实际改动的词数。
  Future<int> mergeFlagChanges(List<WordFlagChange> changes);
}
