import '../models/models.dart';

/// 会话状态枚举
enum SessionState {
  idle,       // 空闲
  presenting, // 展示题目
  waiting,    // 等待用户选择
  resolved,   // 已解决（显示反馈）
  finished,   // 会话结束
}

/// 延迟队列项
class DelayedItem {
  final int wordId;
  int afterN; // 还需要几题后再现

  DelayedItem({
    required this.wordId,
    required this.afterN,
  });

  DelayedItem copyWith({int? afterN}) => DelayedItem(
        wordId: wordId,
        afterN: afterN ?? this.afterN,
      );

  @override
  String toString() => 'DelayedItem(wordId: $wordId, afterN: $afterN)';
}

/// 会话配置
class SessionConfig {
  final Set<String> levels;
  final int wordsPerSession;
  final int timeLimitMs;
  final String orderPolicy;
  final bool onlyLeeches;
  final int wrongDelay;     // 错题延迟
  final int slowDelay;      // 勉强正确延迟
  final double slowThreshold; // 勉强正确阈值（倍数）

  const SessionConfig({
    required this.levels,
    required this.wordsPerSession,
    required this.timeLimitMs,
    required this.orderPolicy,
    required this.onlyLeeches,
    required this.wrongDelay,
    required this.slowDelay,
    required this.slowThreshold,
  });

  factory SessionConfig.fromAppSettings(AppSettings settings) {
    final delayConfig = settings.delayConfig;
    return SessionConfig(
      levels: settings.selectedLevelsSet,
      wordsPerSession: settings.wordsPerSession,
      timeLimitMs: settings.timeLimitMs,
      orderPolicy: settings.orderPolicy,
      onlyLeeches: settings.onlyLeeches,
      wrongDelay: delayConfig.wrongDelay,
      slowDelay: delayConfig.slowDelay,
      slowThreshold: settings.slowThreshold,
    );
  }

  @override
  String toString() => 'SessionConfig(levels: $levels, words: $wordsPerSession, timeLimit: ${timeLimitMs}ms, onlyLeeches: $onlyLeeches)';
}

/// 会话数据（包含当前状态的所有信息）
class SessionData {
  final SessionState state;
  final List<Word> mainQueue;        // 主队列
  final List<DelayedItem> delayedQueue; // 延迟队列
  final List<Attempt> attempts;      // 答题记录
  final Question? currentQuestion;   // 当前题目
  final int? selectedOption;         // 用户选择的选项
  final int millisLeft;              // 剩余时间（毫秒）
  final DateTime? questionStartTime; // 题目开始时间
  final bool lastCorrect;            // 上一题是否正确
  final Set<int> recentWordIds;      // 最近出现的单词ID（用于冷却）
  final String sessionId;            // 会话ID
  final SessionConfig config;        // 会话配置
  final bool isPaused;               // 是否暂停中

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
  });

  /// 创建初始会话数据
  factory SessionData.initial({
    required List<Word> initialQueue,
    required SessionConfig config,
    required String sessionId,
  }) =>
      SessionData(
        state: SessionState.idle,
        mainQueue: initialQueue,
        delayedQueue: [],
        attempts: [],
        currentQuestion: null,
        selectedOption: null,
        millisLeft: config.timeLimitMs,
        questionStartTime: null,
        lastCorrect: false,
        recentWordIds: {},
        sessionId: sessionId,
        config: config,
        isPaused: false,
      );

  /// 当前进度
  int get currentProgress => attempts.length;

  /// 总题数（估算）
  int get totalQuestions => mainQueue.length + delayedQueue.length + currentProgress;

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

  /// 平均反应时间
  int get avgReactionTime {
    if (attempts.isEmpty) return 0;
    final validAttempts = attempts.where((a) => !a.isTimeout);
    if (validAttempts.isEmpty) return 0;
    final totalRt = validAttempts.map((a) => a.rtMs).reduce((a, b) => a + b);
    return (totalRt / validAttempts.length).round();
  }

  /// 错题列表
  List<Attempt> get wrongAttempts => attempts.where((a) => a.isWrong || a.isTimeout).toList();

  /// 勉强正确的题目
  List<Attempt> get slowCorrectAttempts => attempts
      .where((a) => a.isCorrect && a.rtMs > config.timeLimitMs * config.slowThreshold)
      .toList();

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
  }) =>
      SessionData(
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
      );

  @override
  String toString() => 'SessionData(state: $state, paused: $isPaused, progress: $currentProgress, accuracy: ${accuracy.toStringAsFixed(2)})';
}
