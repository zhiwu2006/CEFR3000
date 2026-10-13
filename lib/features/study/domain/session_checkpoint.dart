import 'dart:convert';

import '../../../models/attempt.dart';
import '../../../session/session_models.dart';

/// 可版本化的会话快照。它保存恢复所需的队列和当前题，而不是只保存词 ID。
class SessionCheckpoint {
  final int schemaVersion;
  final String sessionId;
  final int revision;
  final String status;
  final List<int> mainQueueWordIds;
  final List<Map<String, dynamic>> delayedQueue;
  final int? currentWordId;
  final List<String>? currentOptions;
  final int? currentCorrectIndex;
  final int? selectedOption;
  final int millisLeft;
  final int currentProgress;
  final List<Map<String, dynamic>> attempts;
  final Map<String, dynamic> config;
  final DateTime savedAt;
  final Map<int, int> retryCounts;
  final Set<int> unresolvedWordIds;

  const SessionCheckpoint({
    this.schemaVersion = 2,
    required this.sessionId,
    required this.revision,
    required this.status,
    required this.mainQueueWordIds,
    required this.delayedQueue,
    required this.currentWordId,
    required this.currentOptions,
    required this.currentCorrectIndex,
    required this.selectedOption,
    required this.millisLeft,
    required this.currentProgress,
    required this.attempts,
    required this.config,
    required this.savedAt,
    this.retryCounts = const {},
    this.unresolvedWordIds = const {},
  });

  factory SessionCheckpoint.fromSessionData(
    SessionData data, {
    int revision = 0,
  }) {
    final question = data.currentQuestion;
    return SessionCheckpoint(
      sessionId: data.sessionId,
      revision: revision,
      status: data.state.name,
      mainQueueWordIds: data.mainQueue.map((word) => word.id).toList(),
      delayedQueue: data.delayedQueue
          .map(
            (item) => {
              'wordId': item.wordId,
              'afterN': item.afterN,
              'eligibleAfterQuestion': item.eligibleAfterQuestion,
              'retryCount': item.retryCount,
            },
          )
          .toList(),
      currentWordId: question?.word.id,
      currentOptions: question?.options,
      currentCorrectIndex: question?.correctIndex,
      selectedOption: data.selectedOption,
      millisLeft: data.millisLeft,
      currentProgress: data.currentProgress,
      attempts: data.attempts.map((attempt) => attempt.toJson()).toList(),
      config: _configToJson(data.config),
      savedAt: DateTime.now(),
      retryCounts: data.retryCounts,
      unresolvedWordIds: data.unresolvedWordIds,
    );
  }

  /// 该快照是否代表一份「可以继续」的未完成进度。
  ///
  /// 恢复判据必须以快照本身为准，而不是设置里的 `hasActiveSession`：
  /// 后者依赖 `currentSessionId`，而该字段只由 `stageCustomSession` 写入，
  /// 首页「开始学习」发起的会话从不写它，会让崩溃恢复永远不可达。
  ///
  /// 会话正常结束时状态为 `finished`（并在 `_finishSession` 中清理快照），
  /// 这里再做一次防御，避免把已结束或空的快照当成待恢复会话。
  bool get isResumable {
    if (status == SessionState.finished.name ||
        status == SessionState.idle.name) {
      return false;
    }
    return currentWordId != null ||
        mainQueueWordIds.isNotEmpty ||
        delayedQueue.isNotEmpty;
  }

  /// 尚未作答的题数（主队列 + 延迟队列 + 当前题）。
  int get remainingQuestionCount =>
      mainQueueWordIds.length +
      delayedQueue.length +
      (currentWordId != null ? 1 : 0);

  /// 本轮预计总题数，与 `SessionData.totalQuestions` 口径一致。
  ///
  /// `currentProgress` 是「已作答数 + 历史偏移」，因此总数 = 进度 + 剩余。
  int get totalQuestionCount => currentProgress + remainingQuestionCount;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'sessionId': sessionId,
    'revision': revision,
    'status': status,
    'mainQueueWordIds': mainQueueWordIds,
    'delayedQueue': delayedQueue,
    'currentWordId': currentWordId,
    'currentOptions': currentOptions,
    'currentCorrectIndex': currentCorrectIndex,
    'selectedOption': selectedOption,
    'millisLeft': millisLeft,
    'currentProgress': currentProgress,
    'attempts': attempts,
    'config': config,
    'savedAt': savedAt.toIso8601String(),
    'retryCounts': retryCounts.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'unresolvedWordIds': unresolvedWordIds.toList(),
  };

  String encode() => jsonEncode(toJson());

  factory SessionCheckpoint.fromJson(Map<String, dynamic> json) {
    return SessionCheckpoint(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      sessionId: json['sessionId'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'paused',
      mainQueueWordIds: (json['mainQueueWordIds'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      delayedQueue: (json['delayedQueue'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(),
      currentWordId: (json['currentWordId'] as num?)?.toInt(),
      currentOptions: (json['currentOptions'] as List?)
          ?.whereType<String>()
          .toList(),
      currentCorrectIndex: (json['currentCorrectIndex'] as num?)?.toInt(),
      selectedOption: (json['selectedOption'] as num?)?.toInt(),
      millisLeft: (json['millisLeft'] as num?)?.toInt() ?? 0,
      currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      retryCounts: (json['retryCounts'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          int.tryParse(key.toString()) ?? -1,
          (value as num?)?.toInt() ?? 0,
        ),
      )..removeWhere((key, _) => key <= 0),
      unresolvedWordIds: (json['unresolvedWordIds'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where((value) => value > 0)
          .toSet(),
    );
  }

  static SessionCheckpoint? tryDecode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return SessionCheckpoint.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _configToJson(SessionConfig config) => {
    'levels': config.levels.toList(),
    'wordsPerSession': config.wordsPerSession,
    'timeLimitMs': config.timeLimitMs,
    'orderPolicy': config.orderPolicy,
    'onlyLeeches': config.onlyLeeches,
    'wrongDelay': config.wrongDelay,
    'slowDelay': config.slowDelay,
    'slowThreshold': config.slowThreshold,
    'newCardRatio': config.newCardRatio,
    'dailyNewLimit': config.dailyNewLimit,
    'ttsAutoPlay': config.ttsAutoPlay,
    'ttsOnWrong': config.ttsOnWrong,
    'leechLapsesThreshold': config.leechLapsesThreshold,
    'leechIncludeMarked': config.leechIncludeMarked,
    'maxRetriesPerWord': config.maxRetriesPerWord,
    'maxTotalAttempts': config.maxTotalAttempts,
    'cooldownWindow': config.cooldownWindow,
    'studyNewWords': config.studyNewWords,
    'plannedWordIds': config.plannedWordIds,
    'srsConfig': {
      'alphaStability': config.srsConfig.alphaStability,
      'betaFailure': config.srsConfig.betaFailure,
      'gammaInterval': config.srsConfig.gammaInterval,
      'maxIntervalDays': config.srsConfig.maxIntervalDays,
    },
  };

  List<Attempt> decodeAttempts() =>
      attempts.map(Attempt.fromJson).toList(growable: false);
}
