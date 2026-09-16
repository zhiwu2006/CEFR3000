import '../models/models.dart';
import '../domain/srs.dart';

/// 会话状态枚举
enum SessionState {
  idle, // 空闲
  presenting, // 展示题目
  waiting, // 等待用户选择
  resolved, // 已解决（显示反馈）
  saving, // 全轮完成，统一保存
  saveFailed, // 保存失败，可重试
  finished, // 会话结束
}

/// 延迟队列项。
///
/// [eligibleAfterQuestion] 是已经结算的题号下界。保留可选的 [afterN]
/// 参数只是为了读取旧快照和兼容旧测试；新代码不再递减倒计数器。
class DelayedItem {
  final int wordId;
  final int eligibleAfterQuestion;
  final int retryCount; // 已重出次数

  DelayedItem({
    required this.wordId,
    int? eligibleAfterQuestion,
    int? afterN,
    this.retryCount = 0,
  }) : eligibleAfterQuestion = eligibleAfterQuestion ?? afterN ?? 0;

  /// 旧字段名的只读兼容别名。它不再代表“每题自动减一”的可变状态。
  int get afterN => eligibleAfterQuestion;

  bool isEligibleAt(int completedQuestionCount) =>
      completedQuestionCount >= eligibleAfterQuestion;

  DelayedItem copyWith({
    int? eligibleAfterQuestion,
    int? afterN,
    int? retryCount,
  }) => DelayedItem(
    wordId: wordId,
    eligibleAfterQuestion: eligibleAfterQuestion ?? afterN ?? this.eligibleAfterQuestion,
    retryCount: retryCount ?? this.retryCount,
  );

  @override
  String toString() =>
      'DelayedItem(wordId: $wordId, eligibleAfterQuestion: $eligibleAfterQuestion, retryCount: $retryCount)';
}

/// 会话配置
class SessionConfig {
  final Set<String> levels;
  final int wordsPerSession;
  final int timeLimitMs;
  final String orderPolicy;
  final bool onlyLeeches;
  final int wrongDelay; // 错题延迟
  final int slowDelay; // 勉强正确延迟
  final double slowThreshold; // 勉强正确阈值（倍数）
  final double newCardRatio; // 新卡比例
  final int dailyNewLimit; // 每日新卡上限
  final bool ttsAutoPlay; // 自动发音
  final bool ttsOnWrong; // 错题回放发音
  final int leechLapsesThreshold; // 失忆次数阈值
  final bool leechIncludeMarked; // 是否包含疑难标记
  final SrsConfig srsConfig; // SRS 算法配置
  /// 单词在本轮允许进入重测队列的最大次数。
  final int maxRetriesPerWord;
  /// 本轮最多结算多少道题；0 表示按词数和重测上限自动计算。
  final int maxTotalAttempts;
  /// 最近出现窗口的大小，用于避免即时工作记忆作答。
  final int cooldownWindow;
  /// 今日计划已经选出的稳定顺序；为空时才使用兼容选词逻辑。
  final List<int>? plannedWordIds;

  const SessionConfig({
    required this.levels,
    required this.wordsPerSession,
    required this.timeLimitMs,
    required this.orderPolicy,
    required this.onlyLeeches,
    required this.wrongDelay,
    required this.slowDelay,
    required this.slowThreshold,
    required this.newCardRatio,
    required this.dailyNewLimit,
    required this.ttsAutoPlay,
    required this.ttsOnWrong,
    required this.leechLapsesThreshold,
    required this.leechIncludeMarked,
    this.srsConfig = const SrsConfig(),
    this.maxRetriesPerWord = 3,
    this.maxTotalAttempts = 0,
    this.cooldownWindow = 5,
    this.plannedWordIds,
  });

  int get effectiveMaxTotalAttempts {
    if (maxTotalAttempts > 0) return maxTotalAttempts;
    return (wordsPerSession * (maxRetriesPerWord + 1)).clamp(1, 10000);
  }

  static const SessionConfig defaultConfig = SessionConfig(
    levels: {'A1'},
    wordsPerSession: 3,
    timeLimitMs: 5000,
    orderPolicy: 'by_level',
    onlyLeeches: false,
    wrongDelay: 3,
    slowDelay: 3,
    slowThreshold: 1.5,
    newCardRatio: 0.3,
    dailyNewLimit: 20,
    ttsAutoPlay: false,
    ttsOnWrong: true,
    leechLapsesThreshold: 3,
    leechIncludeMarked: true,
  );

  /// 获取 LeechPolicy（从会话配置中的字段构建）
  LeechPolicy get leechPolicy => LeechPolicy(
    lapsesThreshold: leechLapsesThreshold,
    includeMarked: leechIncludeMarked,
  );

  SessionConfig copyWith({
    Set<String>? levels,
    int? wordsPerSession,
    int? timeLimitMs,
    String? orderPolicy,
    bool? onlyLeeches,
    int? wrongDelay,
    int? slowDelay,
    double? slowThreshold,
    double? newCardRatio,
    int? dailyNewLimit,
    bool? ttsAutoPlay,
    bool? ttsOnWrong,
    int? leechLapsesThreshold,
    bool? leechIncludeMarked,
    SrsConfig? srsConfig,
    int? maxRetriesPerWord,
    int? maxTotalAttempts,
    int? cooldownWindow,
    List<int>? plannedWordIds,
  }) {
    return SessionConfig(
      levels: levels ?? this.levels,
      wordsPerSession: wordsPerSession ?? this.wordsPerSession,
      timeLimitMs: timeLimitMs ?? this.timeLimitMs,
      orderPolicy: orderPolicy ?? this.orderPolicy,
      onlyLeeches: onlyLeeches ?? this.onlyLeeches,
      wrongDelay: wrongDelay ?? this.wrongDelay,
      slowDelay: slowDelay ?? this.slowDelay,
      slowThreshold: slowThreshold ?? this.slowThreshold,
      newCardRatio: newCardRatio ?? this.newCardRatio,
      dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
      ttsAutoPlay: ttsAutoPlay ?? this.ttsAutoPlay,
      ttsOnWrong: ttsOnWrong ?? this.ttsOnWrong,
      leechLapsesThreshold: leechLapsesThreshold ?? this.leechLapsesThreshold,
      leechIncludeMarked: leechIncludeMarked ?? this.leechIncludeMarked,
      srsConfig: srsConfig ?? this.srsConfig,
      maxRetriesPerWord: maxRetriesPerWord ?? this.maxRetriesPerWord,
      maxTotalAttempts: maxTotalAttempts ?? this.maxTotalAttempts,
      cooldownWindow: cooldownWindow ?? this.cooldownWindow,
      plannedWordIds: plannedWordIds ?? this.plannedWordIds,
    );
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  factory SessionConfig.fromAppSettings(AppSettings settings) {
    final delayConfig = settings.delayConfig;
    final levels = settings.selectedLevelsSet.isEmpty
        ? {'A1'}
        : settings.selectedLevelsSet;
    final orderPolicy =
        (settings.orderPolicy == 'by_level' || settings.orderPolicy == 'random')
        ? settings.orderPolicy
        : 'by_level';
    return SessionConfig(
      levels: levels,
      wordsPerSession: _clampInt(settings.wordsPerSession, 1, 1000),
      timeLimitMs: _clampInt(
        settings.timeLimitMs <= 0 ? 2000 : settings.timeLimitMs,
        1000,
        30000,
      ),
      orderPolicy: orderPolicy,
      onlyLeeches: settings.onlyLeeches,
      wrongDelay: _clampInt(delayConfig.wrongDelay, 1, 20),
      slowDelay: _clampInt(delayConfig.slowDelay, 1, 20),
      // 5.0 是早期版本的旧默认值，迁移为当前 1.5x 灵敏度。
      slowThreshold: _clampDouble(
        settings.slowThreshold > 2.5 ? 1.5 : settings.slowThreshold,
        1.0,
        2.5,
      ),
      newCardRatio: _clampDouble(settings.newCardRatio, 0.0, 1.0),
      dailyNewLimit: _clampInt(settings.dailyNewLimit, 0, 500),
      ttsAutoPlay: settings.ttsAutoPlay,
      ttsOnWrong: settings.ttsOnWrong,
      leechLapsesThreshold: _clampInt(settings.leechLapsesThreshold, 1, 10),
      leechIncludeMarked: settings.leechIncludeMarked,
      srsConfig: SrsConfig.fromSettings(settings.srs),
      maxRetriesPerWord: 3,
      maxTotalAttempts: 0,
      cooldownWindow: 5,
    );
  }

  /// 从已持久化的会话配置快照恢复；解析失败时由调用方回退到当前设置。
  static SessionConfig? fromCheckpointMap(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    int intValue(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    double doubleValue(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    bool boolValue(String key, bool fallback) => json[key] as bool? ?? fallback;
    final levels = (json['levels'] as List?)?.whereType<String>().toSet();
    final srs = Map<String, dynamic>.from(
      json['srsConfig'] as Map? ?? const {},
    );
    return SessionConfig(
      levels: levels == null || levels.isEmpty ? {'A1'} : levels,
      wordsPerSession: intValue('wordsPerSession', 20).clamp(1, 1000),
      timeLimitMs: intValue('timeLimitMs', 2000).clamp(1000, 30000),
      orderPolicy: json['orderPolicy'] == 'random' ? 'random' : 'by_level',
      onlyLeeches: boolValue('onlyLeeches', false),
      wrongDelay: intValue('wrongDelay', 3).clamp(1, 20),
      slowDelay: intValue('slowDelay', 5).clamp(1, 20),
      slowThreshold: doubleValue('slowThreshold', 1.5).clamp(1.0, 2.5),
      newCardRatio: doubleValue('newCardRatio', 0.2).clamp(0.0, 1.0),
      dailyNewLimit: intValue('dailyNewLimit', 20).clamp(0, 500),
      ttsAutoPlay: boolValue('ttsAutoPlay', true),
      ttsOnWrong: boolValue('ttsOnWrong', false),
      leechLapsesThreshold: intValue('leechLapsesThreshold', 2).clamp(1, 10),
      leechIncludeMarked: boolValue('leechIncludeMarked', true),
      maxRetriesPerWord: intValue('maxRetriesPerWord', 3).clamp(0, 20),
      maxTotalAttempts: intValue('maxTotalAttempts', 0).clamp(0, 10000),
      cooldownWindow: intValue('cooldownWindow', 5).clamp(0, 50),
      plannedWordIds: (json['plannedWordIds'] as List?)
          ?.whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      srsConfig: SrsConfig(
        alphaStability: (srs['alphaStability'] as num?)?.toDouble() ?? 0.18,
        betaFailure: (srs['betaFailure'] as num?)?.toDouble() ?? 1.2,
        gammaInterval: (srs['gammaInterval'] as num?)?.toDouble() ?? 1.0,
        maxIntervalDays: (srs['maxIntervalDays'] as num?)?.toInt() ?? 90,
      ),
    );
  }

  @override
  String toString() =>
      'SessionConfig(levels: $levels, words: $wordsPerSession, timeLimit: ${timeLimitMs}ms, onlyLeeches: $onlyLeeches)';
}

/// 会话数据（包含当前状态的所有信息）
class SessionData {
  final SessionState state;
  final List<Word> mainQueue; // 主队列
  final List<DelayedItem> delayedQueue; // 延迟队列
  final List<Attempt> attempts; // 答题记录
  final Question? currentQuestion; // 当前题目
  final int? selectedOption; // 用户选择的选项
  final int millisLeft; // 剩余时间（毫秒）
  final DateTime? questionStartTime; // 题目开始时间
  final bool lastCorrect; // 上一题是否正确
  final Set<int> recentWordIds; // 最近出现的单词ID（用于冷却）
  final String sessionId; // 会话ID
  final SessionConfig config; // 会话配置
  final bool isPaused; // 是否暂停中
  final int initialProgressOffset; // 初始进度偏移量（用于恢复会话时反映历史进度，免注入虚拟脏数据）
  /// 每个单词已经实际重测的次数；只在本轮内有效。
  final Map<int, int> retryCounts;
  /// 达到重测上限或总题数上限后，本轮未解决的词。
  final Set<int> unresolvedWordIds;

  const SessionData({
    required this.state,
    required this.mainQueue,
    required this.delayedQueue,
    required this.attempts,
    this.currentQuestion,
    this.selectedOption,
    required this.millisLeft,
    this.questionStartTime,
    required this.lastCorrect,
    required this.recentWordIds,
    required this.sessionId,
    required this.config,
    this.isPaused = false,
    this.initialProgressOffset = 0,
    this.retryCounts = const {},
    this.unresolvedWordIds = const {},
  });

  /// 创建初始会话数据
  factory SessionData.initial({
    required List<Word> initialQueue,
    required SessionConfig config,
    required String sessionId,
    int initialProgressOffset = 0,
    List<Attempt> initialAttempts = const [],
  }) => SessionData(
    state: SessionState.idle,
    mainQueue: initialQueue,
    delayedQueue: [],
    attempts: List<Attempt>.unmodifiable(initialAttempts),
    currentQuestion: null,
    selectedOption: null,
    millisLeft: config.timeLimitMs,
    questionStartTime: null,
    lastCorrect: false,
    recentWordIds: {},
    sessionId: sessionId,
    config: config,
    isPaused: false,
    initialProgressOffset: initialProgressOffset,
    retryCounts: const {},
    unresolvedWordIds: const {},
  );

  /// 当前进度
  int get currentProgress => initialProgressOffset + attempts.length;

  /// 总题数（估算）
  int get totalQuestions =>
      mainQueue.length +
      delayedQueue.length +
      (currentQuestion != null ? 1 : 0) +
      currentProgress;

  /// 是否完成
  bool get isFinished => state == SessionState.finished;

  /// 是否有当前题目
  bool get hasCurrentQuestion => currentQuestion != null;

  /// 准确率
  double get accuracy {
    if (attempts.isEmpty) return 0.0;
    final correctCount = attempts.where((a) => a.isCorrect).length;
    return correctCount / attempts.length;
  }

  /// 每个单词在本轮第一次出现的答题记录。
  List<Attempt> get firstAttempts {
    final firstByWord = <int, Attempt>{};
    for (final attempt in attempts) {
      firstByWord.putIfAbsent(attempt.wordId, () => attempt);
    }
    return firstByWord.values.toList(growable: false);
  }

  double get firstAccuracy {
    if (firstAttempts.isEmpty) return 0.0;
    return firstAttempts.where((attempt) => attempt.isCorrect).length /
        firstAttempts.length;
  }

  List<Attempt> get firstWrongAttempts => firstAttempts
      .where((attempt) => attempt.isWrong || attempt.isTimeout)
      .toList(growable: false);

  Set<int> get firstWrongWordIds =>
      firstWrongAttempts.map((attempt) => attempt.wordId).toSet();

  Set<int> get correctedWordIds {
    final failed = firstWrongWordIds;
    final firstByWord = <int, Attempt>{
      for (final attempt in firstAttempts) attempt.wordId: attempt,
    };
    return failed
        .where(
          (wordId) => attempts.any(
            (attempt) =>
                attempt.wordId == wordId &&
                !identical(attempt, firstByWord[wordId]) &&
                attempt.isCorrect &&
                !attempt.usedHint,
          ),
        )
        .toSet();
  }

  double get correctionSuccessRate {
    if (firstWrongWordIds.isEmpty) return 0.0;
    return correctedWordIds.length / firstWrongWordIds.length;
  }

  /// 平均反应时间
  int get avgReactionTime {
    if (attempts.isEmpty) return 0;
    final validAttempts = attempts.where((a) => !a.isTimeout);
    if (validAttempts.isEmpty) return 0;
    final totalRt = validAttempts.map((a) => a.rtMs).reduce((a, b) => a + b);
    return (totalRt / validAttempts.length).round();
  }

  /// 错题列表
  List<Attempt> get wrongAttempts =>
      attempts.where((a) => a.isWrong || a.isTimeout).toList();

  /// 勉强正确的题目
  List<Attempt> get slowCorrectAttempts => attempts
      .where(
        (a) =>
            a.isCorrect &&
            !a.usedHint &&
            SrsAlgorithm.calculateQuality(
              result: a.result,
              reactionTime: a.rtMs,
              timeLimit: config.timeLimitMs,
              slowThresholdMultiplier: config.slowThreshold,
            ) ==
            3,
      )
      .toList();

  List<Attempt> get firstSlowCorrectAttempts => firstAttempts
      .where(
        (a) =>
            a.isCorrect &&
            !a.usedHint &&
            SrsAlgorithm.calculateQuality(
              result: a.result,
              reactionTime: a.rtMs,
              timeLimit: config.timeLimitMs,
              slowThresholdMultiplier: config.slowThreshold,
            ) ==
            3,
      )
      .toList(growable: false);

  /// 只计算倒计时实际消耗的时间，暂停或后台停留不会被计入。
  int get activeReactionTimeMs =>
      (config.timeLimitMs - millisLeft).clamp(0, config.timeLimitMs).toInt();

  /// 复制并修改指定字段
  SessionData copyWith({
    SessionState? state,
    List<Word>? mainQueue,
    List<DelayedItem>? delayedQueue,
    List<Attempt>? attempts,
    Question? currentQuestion,
    int? selectedOption,
    int? millisLeft,
    DateTime? questionStartTime,
    bool? lastCorrect,
    Set<int>? recentWordIds,
    String? sessionId,
    SessionConfig? config,
    bool? isPaused,
    int? initialProgressOffset,
    Map<int, int>? retryCounts,
    Set<int>? unresolvedWordIds,
  }) => SessionData(
    state: state ?? this.state,
    mainQueue: mainQueue ?? this.mainQueue,
    delayedQueue: delayedQueue ?? this.delayedQueue,
    attempts: attempts ?? this.attempts,
    currentQuestion: currentQuestion ?? this.currentQuestion,
    selectedOption: selectedOption ?? this.selectedOption,
    millisLeft: millisLeft ?? this.millisLeft,
    questionStartTime: questionStartTime ?? this.questionStartTime,
    lastCorrect: lastCorrect ?? this.lastCorrect,
    recentWordIds: recentWordIds ?? this.recentWordIds,
    sessionId: sessionId ?? this.sessionId,
    config: config ?? this.config,
    isPaused: isPaused ?? this.isPaused,
    initialProgressOffset: initialProgressOffset ?? this.initialProgressOffset,
    retryCounts: retryCounts ?? this.retryCounts,
    unresolvedWordIds: unresolvedWordIds ?? this.unresolvedWordIds,
  );

  @override
  String toString() =>
      'SessionData(state: $state, paused: $isPaused, progress: $currentProgress, accuracy: ${accuracy.toStringAsFixed(2)})';
}
