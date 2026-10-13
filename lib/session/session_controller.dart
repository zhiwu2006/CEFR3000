import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../domain/domain.dart';
import '../data/repositories.dart';
import 'session_models.dart';
import 'delayed_replay_manager.dart';
import 'word_selection_service.dart';
import '../features/memory/application/recall_commit_service.dart';
import '../features/study/domain/session_checkpoint.dart';
import '../features/study/data/session_checkpoint_store.dart';
import '../core/clock.dart';

/// 会话控制器
class SessionController extends StateNotifier<SessionData> {
  final WordRepository _wordRepository;
  final ProgressRepository _progressRepository;
  final TtsService _ttsService;
  final DistractorService _distractorService;
  final WordSelectionService _wordSelectionService;
  final DelayedReplayManager _delayedReplayManager;
  final SessionCheckpointStore? _checkpointStore;
  final SessionCheckpointStore? Function()? _checkpointStoreGetter;

  SessionCheckpointStore? get checkpointStore =>
      _checkpointStore ?? _checkpointStoreGetter?.call();

  late RecallCommitService _recallCommitService;
  final Set<String> _committedEventIds = <String>{};
  final Set<int> _consumedNewWordIds = <int>{};
  final bool _consumeNewOnSelection;
  final Clock _clock;
  final Future<void> Function(int) _consumeDailyNew;
  static const feedbackDuration = Duration(milliseconds: 800);
  Timer? _feedbackTimer;
  Duration _feedbackRemaining = Duration.zero;
  DateTime? _feedbackStartedAt;
  DateTime? _countdownStartedAt;
  int _countdownInitialMs = 0;

  Timer? _countdownTimer;
  List<Word>? _candidatePool; // 干扰项候选池
  bool _isPaused = false;
  bool _pendingNextQuestion = false;

  /// 每答完多少题落一次检查点。
  ///
  /// 检查点原先只在 `pauseSession()`（退到后台）时写入，答题过程中不留任何
  /// 持久化痕迹：前台崩溃或被系统杀死会丢掉整轮进度，而「resolved 状态恢复
  /// 分支」只有在 800ms 反馈窗口内恰好暂停时才会走到。这里改为按题数节流落盘，
  /// 既覆盖了崩溃场景，又避免每题都写一次 SharedPreferences。
  static const int checkpointSaveEveryQuestions = 5;

  /// 自上次落盘以来已作答的题数，配合 [checkpointSaveEveryQuestions] 做节流。
  int _questionsSinceCheckpoint = 0;

  /// 检查点写入的串行链。
  ///
  /// 节流写入与 `pauseSession()` 的写入必须依次执行：两者都整体覆盖同一份快照，
  /// 并发执行会让后完成的旧快照盖掉新快照。
  Future<void> _checkpointWrite = Future<void>.value();

  SessionController({
    required WordRepository wordRepository,
    required ProgressRepository progressRepository,
    required TtsService ttsService,
    required DistractorService distractorService,
    required int Function() getDailyNewRemaining,
    required Future<void> Function(int) consumeDailyNew,
    bool consumeNewOnSelection = false,
    Clock clock = const SystemClock(),
    SessionCheckpointStore? checkpointStore,
    SessionCheckpointStore? Function()? checkpointStoreGetter,
  }) : _wordRepository = wordRepository,
       _progressRepository = progressRepository,
       _ttsService = ttsService,
       _distractorService = distractorService,
       _wordSelectionService = WordSelectionService(
         progressRepository: progressRepository,
         getDailyNewRemaining: getDailyNewRemaining,
         consumeDailyNew: consumeDailyNew,
         consumeNewOnSelection: consumeNewOnSelection,
       ),
       _delayedReplayManager = const DelayedReplayManager(),
       _consumeNewOnSelection = consumeNewOnSelection,
       _clock = clock,
       _consumeDailyNew = consumeDailyNew,
       _checkpointStore = checkpointStore,
       _checkpointStoreGetter = checkpointStoreGetter,
       super(
         SessionData.initial(
           initialQueue: [],
           config: const SessionConfig(
             levels: {'A1'},
             wordsPerSession: 0, // 使用0作为空状态标识，实际配置将在startSession时设置
             timeLimitMs: 2000,
             orderPolicy: 'by_level',
             onlyLeeches: false,
             wrongDelay: 3,
             slowDelay: 5,
             slowThreshold: 1.5,
             newCardRatio: 0.25,
             dailyNewLimit: 30,
             ttsAutoPlay: true,
             ttsOnWrong: false,
             leechLapsesThreshold: 2,
             leechIncludeMarked: true,
           ),
           sessionId: '',
         ),
       ) {
    _initializeCommitService();
  }

  void _initializeCommitService() {
    _recallCommitService = RecallCommitService(
      progressRepository: _progressRepository,
      config: state.config.srsConfig,
    );
  }

  /// 开始新会话或恢复会话
  Future<void> startSession(
    SessionConfig config, {
    String? resumeSessionId,
    List<int>? remainingWordIds,
    int? currentProgress,
    SessionCheckpoint? checkpoint,
  }) async {
    try {
      _stopCountdown();
      _cancelFeedback();
      _committedEventIds.clear();
      _consumedNewWordIds.clear();
      debugPrint('=== Starting session with config: $config');
      _recallCommitService = RecallCommitService(
        progressRepository: _progressRepository,
        config: config.srsConfig,
      );
      _isPaused = false;
      _pendingNextQuestion = false;
      _questionsSinceCheckpoint = 0;

      // 记录上一轮出现过的单词，优先避开
      Set<int> recentWordIds = {};
      Set<int> hardWordIds = {};
      var pendingConsolidation = <int>{};
      try {
        pendingConsolidation = TestRun.pendingConsolidation(
          await _progressRepository.getTestRunHistory(
            limit: TestRun.pendingConsolidationLookbackRuns,
          ),
        );
      } catch (error) {
        debugPrint('Unable to load consolidation history: $error');
      }
      try {
        final lastRun = await _progressRepository.getLatestTestRun();
        if (lastRun != null) {
          recentWordIds = lastRun.attempts.map((a) => a.wordId).toSet();
          for (final a in lastRun.attempts) {
            if (a.isWrong ||
                a.isTimeout ||
                SrsAlgorithm.calculateQuality(
                      result: a.result,
                      reactionTime: a.rtMs,
                      timeLimit: config.timeLimitMs,
                      slowThresholdMultiplier: config.slowThreshold,
                    ) ==
                    3) {
              hardWordIds.add(a.wordId);
            }
          }
          debugPrint(
            'Found ${recentWordIds.length} recent words; ${hardWordIds.length} marked as hard (keep in rotation)',
          );
        }
      } catch (e) {
        debugPrint('Unable to load recent test run: $e');
      }

      // 准备候选池（用于干扰项生成）
      _candidatePool = await _wordRepository.loadByLevels(config.levels);
      debugPrint('Candidate pool size: ${_candidatePool?.length}');

      if (_candidatePool == null || _candidatePool!.isEmpty) {
        throw Exception('No words available for levels: ${config.levels}');
      }

      List<Word> availableWords = [];
      List<Attempt> resumedAttempts = const [];
      String sessionId;
      int progress = 0;

      var resumeRequested =
          resumeSessionId != null &&
          remainingWordIds != null &&
          remainingWordIds.isNotEmpty;

      if (checkpoint != null && checkpoint.sessionId == resumeSessionId) {
        final checkpointIds = <int>{
          ...checkpoint.mainQueueWordIds,
          ...checkpoint.delayedQueue
              .map((item) => (item['wordId'] as num?)?.toInt())
              .whereType<int>(),
          if (checkpoint.currentWordId != null) checkpoint.currentWordId!,
        };
        remainingWordIds = checkpointIds.toList();
        resumeRequested = remainingWordIds.isNotEmpty;
      }

      // 检查是否是恢复会话
      if (resumeRequested) {
        final resumeIds = remainingWordIds!;
        final resumeId = resumeSessionId!;
        debugPrint('=== Resuming existing session ===');
        debugPrint('Session ID: $resumeId');
        debugPrint('Remaining word IDs: ${resumeIds.length}');
        debugPrint('Current progress: ${currentProgress ?? 0}');

        sessionId = resumeId;
        progress = currentProgress ?? 0;

        final savedRun = await _findTestRunById(sessionId);
        if (savedRun != null) {
          resumedAttempts = savedRun.attempts
              .where((attempt) => attempt.wordId > 0)
              .toList();
          // The persisted answer list is the stronger source of truth. Keep
          // an offset only for legacy checkpoints whose preference progress
          // is ahead of the saved TestRun.
          progress = max(progress - resumedAttempts.length, 0);
        }
        if (resumedAttempts.isEmpty && checkpoint != null) {
          resumedAttempts = checkpoint.decodeAttempts();
          progress = max(
            checkpoint.currentProgress - resumedAttempts.length,
            0,
          );
        }

        // 根据剩余的单词ID恢复单词列表
        for (final wordId in resumeIds) {
          final word = _candidatePool!.where((w) => w.id == wordId).firstOrNull;
          if (word != null) {
            availableWords.add(word);
          }
        }

        debugPrint(
          'Restored ${availableWords.length} words from saved session',
        );
        if (availableWords.isEmpty) {
          debugPrint(
            'No remaining words matched current levels, starting a new session instead',
          );
        }
      } else {
        debugPrint('=== Starting new session ===');

        // 生成新会话ID
        const uuid = Uuid();
        sessionId = uuid.v4();

        final plannedIds = config.plannedWordIds;
        // A non-null list is an explicit plan snapshot. An empty snapshot
        // means the planner found no eligible work; falling back to the
        // legacy selector here would bypass suspension and daily budgets.
        if (plannedIds != null) {
          final byId = {for (final word in _candidatePool!) word.id: word};
          availableWords = plannedIds
              .map((id) => byId[id])
              .whereType<Word>()
              .toList();
          if (config.orderPolicy == 'random') {
            availableWords.shuffle(Random());
          }
        } else {
          // 没有今日计划时使用兼容的到期/错题/新词选词器。
          availableWords = await _wordSelectionService
              .buildWordListForNewSession(
                config: config,
                candidatePool: _candidatePool!,
                recentWordIds: recentWordIds,
                hardWordIds: hardWordIds,
              );
        }
      }

      if (resumeRequested && availableWords.isEmpty) {
        debugPrint('Fallback: building a new session word list');
        const uuid = Uuid();
        sessionId = uuid.v4();
        progress = 0;
        resumedAttempts = const [];
        availableWords = await _wordSelectionService.buildWordListForNewSession(
          config: config,
          candidatePool: _candidatePool!,
          recentWordIds: recentWordIds,
          hardWordIds: hardWordIds,
        );
      }

      // 旧会话中尚未提交的答案也延迟到整轮结束后统一提交。

      // 尝试避开上一轮测试过的单词，若数量不足再补回
      if (recentWordIds.isNotEmpty &&
          (config.plannedWordIds == null || config.plannedWordIds!.isEmpty)) {
        final avoidIds = recentWordIds.difference(hardWordIds);

        final hardWords = availableWords
            .where((w) => hardWordIds.contains(w.id))
            .toList();
        final freshWords = availableWords
            .where((w) => !recentWordIds.contains(w.id))
            .toList();
        final reusableWords = availableWords
            .where((w) => avoidIds.contains(w.id))
            .toList();

        final combined = <Word>[];
        combined.addAll(hardWords);
        combined.addAll(
          freshWords.where((w) => !combined.any((c) => c.id == w.id)),
        );

        if (combined.length < config.wordsPerSession) {
          for (final w in reusableWords) {
            if (combined.length >= config.wordsPerSession) break;
            if (!combined.any((c) => c.id == w.id)) {
              combined.add(w);
            }
          }
        }

        if (combined.length >= config.wordsPerSession) {
          availableWords = combined.take(config.wordsPerSession).toList();
        } else {
          availableWords = combined;
        }

        if (config.orderPolicy == 'random') {
          availableWords.shuffle(Random());
        }
      }

      // 若当前挑选的词汇量不足以满足用户设定的单轮词数（config.wordsPerSession），
      // 且不是仅疑难词模式（onlyLeeches），在候选池仍有充裕单词的前提下，
      // 兜底补齐至 config.wordsPerSession，防止因单日限额等历史消耗导致单轮题量缩水。
      if (config.plannedWordIds == null &&
          !config.onlyLeeches &&
          availableWords.length < config.wordsPerSession &&
          _candidatePool != null &&
          _candidatePool!.isNotEmpty) {
        final existingIds = availableWords.map((w) => w.id).toSet();
        final fillers = _candidatePool!
            .where((w) => !existingIds.contains(w.id))
            .toList();
        if (config.orderPolicy == 'random') {
          fillers.shuffle(Random());
        }
        for (final w in fillers) {
          if (availableWords.length >= config.wordsPerSession) break;
          availableWords.add(w);
        }
      }

      availableWords = {
        for (final word in availableWords) word.id: word,
      }.values.toList();
      availableWords = [
        ...availableWords.where(
          (word) => pendingConsolidation.contains(word.id),
        ),
        ...availableWords.where(
          (word) => !pendingConsolidation.contains(word.id),
        ),
      ];
      debugPrint('Using ${availableWords.length} words for test');

      if (availableWords.isEmpty) {
        throw Exception('No words available for the selected configuration.');
      }

      // 初始化会话数据（带入历史进度偏移量，避免向 attempts 注入 wordId: 0 虚拟脏数据）
      state =
          SessionData.initial(
            initialQueue: availableWords,
            config: config,
            sessionId: sessionId,
            initialProgressOffset: progress,
            initialAttempts: resumedAttempts,
          ).copyWith(
            consolidationWordIds: pendingConsolidation.intersection(
              availableWords.map((word) => word.id).toSet(),
            ),
          );

      final restoredQuestion = _restoreQuestionFromCheckpoint(
        checkpoint,
        availableWords,
      );
      if (restoredQuestion != null && checkpoint != null) {
        final delayedWordIds = checkpoint.delayedQueue
            .map((item) => (item['wordId'] as num?)?.toInt())
            .whereType<int>()
            .toSet();
        final restoredMainQueue = availableWords
            .where(
              (word) =>
                  word.id != checkpoint.currentWordId &&
                  !delayedWordIds.contains(word.id),
            )
            .toList();
        final restoredDelayed = checkpoint.delayedQueue
            .map(
              (item) => DelayedItem(
                wordId: (item['wordId'] as num?)?.toInt() ?? -1,
                // 新快照保存绝对题号；旧快照的 afterN 会在当前进度上
                // 转换，避免恢复后再次从零开始计数。
                eligibleAfterQuestion:
                    (item['eligibleAfterQuestion'] as num?)?.toInt() ??
                    state.attempts.length +
                        ((item['afterN'] as num?)?.toInt() ?? 0),
                retryCount: (item['retryCount'] as num?)?.toInt() ?? 0,
              ),
            )
            .where((item) => item.wordId > 0)
            .toList();
        // 按检查点保存时的状态分流，而不是一律恢复为 waiting：
        // - resolved：上一题已判分、正处于 800ms 反馈窗口时进程被杀。
        //   若恢复成 waiting，会把已经答过的题重新开放作答，同一题被
        //   二次计入 attempts 并重复推进队列。正确做法是回到反馈态，
        //   让待推进的计时器继续走完再进入下一题。
        // - waiting / 其他：题目尚未作答，恢复到作答态并重启倒计时。
        final restoredAsResolved =
            checkpoint.status == SessionState.resolved.name;
        final lastAttempt = restoredAsResolved && state.attempts.isNotEmpty
            ? state.attempts.last
            : null;
        state = state.copyWith(
          state: restoredAsResolved
              ? SessionState.resolved
              : SessionState.waiting,
          lastCorrect: lastAttempt?.isCorrect ?? false,
          mainQueue: restoredMainQueue,
          delayedQueue: restoredDelayed,
          retryCounts: checkpoint.retryCounts.isNotEmpty
              ? checkpoint.retryCounts
              : {
                  for (final item in restoredDelayed)
                    item.wordId: item.retryCount,
                },
          unresolvedWordIds: checkpoint.unresolvedWordIds,
          currentQuestion: restoredQuestion,
          selectedOption: checkpoint.selectedOption,
          millisLeft: checkpoint.millisLeft.clamp(0, config.timeLimitMs),
        );
        if (restoredAsResolved) {
          // 反馈窗口内崩溃：恢复反馈态并继续推进，不重启倒计时。
          _feedbackRemaining = feedbackDuration;
          _pendingNextQuestion = true;
          _scheduleNextQuestion();
        } else {
          _startCountdown();
        }
        return;
      }

      debugPrint('Session initialized, presenting first question...');

      // 开始第一题
      await _presentNextQuestion();
    } catch (e, stackTrace) {
      debugPrint('Error starting session: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Question? _restoreQuestionFromCheckpoint(
    SessionCheckpoint? checkpoint,
    List<Word> words,
  ) {
    if (checkpoint == null ||
        checkpoint.currentWordId == null ||
        checkpoint.currentOptions == null ||
        checkpoint.currentCorrectIndex == null) {
      return null;
    }
    final word = words
        .where((candidate) => candidate.id == checkpoint.currentWordId)
        .firstOrNull;
    if (word == null) return null;
    return Question(
      word: word,
      options: checkpoint.currentOptions!,
      correctIndex: checkpoint.currentCorrectIndex!,
    );
  }

  /// 答题路径只更新内存；所有存储操作都在整轮结束后执行。
  Future<void> selectOption(int optionIndex) async {
    if (_isPaused ||
        state.state != SessionState.waiting ||
        state.currentQuestion == null ||
        optionIndex < 0 ||
        optionIndex >= state.currentQuestion!.options.length) {
      return;
    }
    _stopCountdown();
    _resolveAttempt(_createAttempt(optionIndex, state.activeReactionTimeMs));
  }

  Future<void> _onTimeout() async {
    if (_isPaused ||
        state.state != SessionState.waiting ||
        state.currentQuestion == null) {
      return;
    }
    _stopCountdown();
    _resolveAttempt(_createAttempt(-1, state.config.timeLimitMs));
  }

  void _resolveAttempt(Attempt attempt) {
    state = state.copyWith(
      state: SessionState.resolved,
      selectedOption: attempt.chosenIndex,
      lastCorrect: attempt.isCorrect,
    );
    _handleAttemptResult(attempt);
    _maybeSaveCheckpoint();
    _feedbackRemaining = feedbackDuration;
    _pendingNextQuestion = true;
    _scheduleNextQuestion();
  }

  void _scheduleNextQuestion() {
    if (_isPaused || !_pendingNextQuestion || _feedbackTimer != null) return;
    _feedbackStartedAt = _clock.now;
    _feedbackTimer = Timer(_feedbackRemaining, () {
      _feedbackTimer = null;
      _feedbackStartedAt = null;
      _feedbackRemaining = Duration.zero;
      if (!mounted || !_pendingNextQuestion) return;
      _presentNextQuestion();
    });
  }

  void _pauseFeedback() {
    final startedAt = _feedbackStartedAt;
    if (startedAt != null) {
      final remaining = _feedbackRemaining - _clock.now.difference(startedAt);
      _feedbackRemaining = remaining.isNegative ? Duration.zero : remaining;
    }
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    _feedbackStartedAt = null;
  }

  void _cancelFeedback() {
    _pauseFeedback();
    _pendingNextQuestion = false;
    _feedbackRemaining = Duration.zero;
  }

  /// 展示下一题
  Future<void> _presentNextQuestion() async {
    if (_isPaused) {
      _pendingNextQuestion = true;
      return;
    }
    _pendingNextQuestion = false;

    try {
      // 检查是否还有题目
      final nextWord = _getNextWord();
      if (nextWord == null) {
        await _finishSession();
        return;
      }

      // 确保候选池存在
      if (_candidatePool == null || _candidatePool!.isEmpty) {
        debugPrint('Error: Candidate pool is empty or null');
        await _finishSession();
        return;
      }

      // 生成题目
      final questionData = _distractorService.buildQuestion(
        nextWord,
        _candidatePool!,
      );

      final question = Question(
        word: nextWord,
        options: questionData.options,
        correctIndex: questionData.correctIndex,
      );

      // 更新状态到presenting，确保重置选中状态
      state = state.copyWith(
        state: SessionState.presenting,
        currentQuestion: question,
        selectedOption: -1, // 明确设置为-1表示未选中
        millisLeft: state.config.timeLimitMs,
        questionStartTime: DateTime.now(),
      );

      // 发音（不阻塞）
      if (state.config.ttsAutoPlay) {
        _speakWord(question.word.headword);
      }

      // 立即进入waiting状态并开始计时，再次确保未选中状态
      state = state.copyWith(
        state: SessionState.waiting,
        selectedOption: -1, // 确保在waiting状态下也是未选中
      );
      _startCountdown();
    } catch (e, stackTrace) {
      debugPrint('Error presenting next question: $e');
      debugPrint('Stack trace: $stackTrace');
      // 尝试恢复或结束会话
      await _finishSession();
    }
  }

  /// 获取下一个单词
  Word? _getNextWord() {
    if (state.attempts.length >= state.config.effectiveMaxTotalAttempts) {
      state = state.copyWith(
        unresolvedWordIds: {
          ...state.unresolvedWordIds,
          ...state.mainQueue.map((word) => word.id),
        },
      );
      _markRemainingDelayedAsUnresolved();
      return null;
    }

    final completedQuestionCount = state.attempts.length;
    final delayed = List<DelayedItem>.from(state.delayedQueue);
    final recentIds = state.recentWordIds;

    // 已到时且不在冷却窗口中的重测拥有最高优先级。
    final eligible =
        delayed
            .where(
              (item) =>
                  item.isEligibleAt(completedQuestionCount) &&
                  !recentIds.contains(item.wordId),
            )
            .toList()
          ..sort(
            (a, b) => a.eligibleAfterQuestion != b.eligibleAfterQuestion
                ? a.eligibleAfterQuestion.compareTo(b.eligibleAfterQuestion)
                : b.retryCount.compareTo(a.retryCount),
          );

    // 不用立即重复来伪造间隔回忆；尾部缺少间隔题时转入待巩固。
    final delayedItem = eligible.isNotEmpty ? eligible.first : null;

    if (delayedItem != null) {
      final word = _candidatePool
          ?.where((candidate) => candidate.id == delayedItem.wordId)
          .firstOrNull;
      final remaining = List<DelayedItem>.from(state.delayedQueue)
        ..removeWhere((item) => item.wordId == delayedItem.wordId);
      state = state.copyWith(delayedQueue: remaining);
      if (word != null) return word;
      debugPrint('Skipping missing delayed word ${delayedItem.wordId}');
      return _getNextWord();
    }

    if (state.mainQueue.isNotEmpty) {
      final word = state.mainQueue.first;
      state = state.copyWith(mainQueue: state.mainQueue.skip(1).toList());
      return word;
    }

    _markRemainingDelayedAsUnresolved();
    return null;
  }

  /// 收集当前会话中选定的全部单词（去重）
  List<Word> _collectCurrentSessionWords() {
    final ids = <int>{};
    final words = <Word>[];

    Word? findWord(int id) {
      if (_candidatePool == null) return null;
      try {
        return _candidatePool!.firstWhere((w) => w.id == id);
      } catch (_) {
        return null;
      }
    }

    void addWord(Word? word) {
      if (word == null) return;
      if (ids.add(word.id)) {
        words.add(word);
      }
    }

    // 当前题目
    addWord(state.currentQuestion?.word);
    // 主队列
    for (final w in state.mainQueue) {
      addWord(w);
    }
    // 延迟队列
    for (final item in state.delayedQueue) {
      addWord(findWord(item.wordId));
    }
    // 已出题的单词（attempts）
    for (final att in state.attempts) {
      addWord(findWord(att.wordId));
    }

    return words;
  }

  /// 使用当前会话的同一批单词重新开始（可重排顺序）
  Future<void> restartWithSameWords({bool shuffle = true}) async {
    _stopCountdown();
    _cancelFeedback();
    _committedEventIds.clear();
    _consumedNewWordIds.clear();
    _isPaused = false;

    // 确保候选池存在
    if (_candidatePool == null || _candidatePool!.isEmpty) {
      _candidatePool = await _wordRepository.loadByLevels(state.config.levels);
    }

    final words = _collectCurrentSessionWords();
    if (words.isEmpty) {
      // 若收集不到，则按配置重新生成
      await startSession(state.config);
      return;
    }

    final consolidation = <int>{
      ...state.consolidationWordIds,
      ...state.unresolvedWordIds,
      ...state.firstWrongWordIds.difference(state.correctedWordIds),
    };
    final newQueue = List<Word>.from(words);
    if (shuffle) {
      newQueue.shuffle(Random());
    }

    const uuid = Uuid();
    final sessionId = uuid.v4();

    state = SessionData.initial(
      initialQueue: newQueue,
      config: state.config,
      sessionId: sessionId,
      totalWords: newQueue.length,
    ).copyWith(consolidationWordIds: consolidation);

    await _presentNextQuestion();
  }

  /// 只处理内存中的记录、重放队列和反馈，不读写仓储。
  void _handleAttemptResult(Attempt attempt) {
    state = state.copyWith(attempts: [...state.attempts, attempt]);
    final needsConsolidation =
        state.consolidationWordIds.contains(attempt.wordId) ||
        state.attempts.any(
          (a) => a.wordId == attempt.wordId && (a.isWrong || a.isTimeout),
        );
    if (_shouldDelayWord(attempt) ||
        (needsConsolidation && state.correctionStreak(attempt.wordId) < 2)) {
      _scheduleDelayedReplay(attempt);
    } else {
      state = state.copyWith(
        unresolvedWordIds: Set<int>.from(state.unresolvedWordIds)
          ..remove(attempt.wordId),
      );
    }
    if (state.config.ttsOnWrong && !attempt.isCorrect) {
      final word = state.currentQuestion?.word;
      if (word != null) _speakWord(word.headword);
    }
    final recentIds = Set<int>.from(state.recentWordIds)..add(attempt.wordId);
    final cooldownWindow = state.config.cooldownWindow;
    if (cooldownWindow <= 0) {
      recentIds.clear();
    } else {
      while (recentIds.length > cooldownWindow) {
        recentIds.remove(recentIds.first);
      }
    }
    state = state.copyWith(recentWordIds: recentIds);
  }

  /// 仅在整轮结束后调用；事件 ID 保证保存重试不重复应用 SRS。
  Future<void> _commitCompletedAttempt(Attempt attempt) async {
    final eventId = ReviewEvent.idFor(
      sessionId: state.sessionId,
      attempt: attempt,
    );
    if (_committedEventIds.contains(eventId)) return;
    final receipt = await _recallCommitService.commitAttempt(
      sessionId: state.sessionId,
      attempt: attempt,
      timeLimitMs: state.config.timeLimitMs,
      slowThreshold: state.config.slowThreshold,
      answerRevealed: attempt.highestHintLevel >= 3,
      hintUsed: attempt.usedHint,
    );
    _committedEventIds.add(receipt.eventId);
    if (!_consumeNewOnSelection && receipt.firstExposureToday) {
      _consumedNewWordIds.add(attempt.wordId);
    }
  }

  /// 判断是否需要延迟回放
  bool _shouldDelayWord(Attempt attempt) {
    return _delayedReplayManager.shouldDelayWord(attempt, state.config);
  }

  /// 安排延迟回放
  void _scheduleDelayedReplay(Attempt attempt) {
    final retryCount = state.retryCounts[attempt.wordId] ?? 0;

    final updatedDelayed = _delayedReplayManager.scheduleDelayedReplay(
      delayedQueue: state.delayedQueue,
      attempt: attempt,
      config: state.config,
      sessionRetryCount: retryCount,
      completedQuestionCount: state.attempts.length,
    );

    final scheduled = updatedDelayed.where(
      (item) => item.wordId == attempt.wordId,
    );
    final nextRetryCounts = Map<int, int>.from(state.retryCounts);
    final unresolved = Set<int>.from(state.unresolvedWordIds);
    if (scheduled.isEmpty) {
      unresolved.add(attempt.wordId);
    } else {
      nextRetryCounts[attempt.wordId] = scheduled.first.retryCount;
    }
    state = state.copyWith(
      delayedQueue: updatedDelayed,
      retryCounts: nextRetryCounts,
      unresolvedWordIds: unresolved,
    );
  }

  /// 创建答题记录
  Attempt _createAttempt(int chosenIndex, int reactionTime) {
    final question = state.currentQuestion!;

    // 根据选择结果确定答题结果
    final actualResult = chosenIndex == -1
        ? AttemptResult.timeout
        : (chosenIndex == question.correctIndex
              ? AttemptResult.correct
              : AttemptResult.wrong);

    return Attempt(
      wordId: question.word.id,
      result: actualResult,
      rtMs: reactionTime,
      chosenIndex: chosenIndex,
      correctIndex: question.correctIndex,
      timestamp: _clock.now,
      kind: state.attempts.any((attempt) => attempt.wordId == question.word.id)
          ? AttemptKind.inSessionRetry
          : AttemptKind.initial,
    );
  }

  void _markRemainingDelayedAsUnresolved() {
    if (state.delayedQueue.isEmpty) return;
    final unresolved = Set<int>.from(state.unresolvedWordIds)
      ..addAll(state.delayedQueue.map((item) => item.wordId));
    state = state.copyWith(
      delayedQueue: const [],
      unresolvedWordIds: unresolved,
    );
  }

  /// 按实际经过时间计时，避免主线程偶发延迟使每题时长漂移。
  void _startCountdown() {
    if (_isPaused || state.state != SessionState.waiting) return;
    _stopCountdown();
    _countdownStartedAt = _clock.now;
    _countdownInitialMs = state.millisLeft;
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isPaused || state.state != SessionState.waiting) return;
      _refreshCountdown();
      if (state.millisLeft <= 0) _onTimeout();
    });
  }

  void _refreshCountdown() {
    final startedAt = _countdownStartedAt;
    if (startedAt == null || state.state != SessionState.waiting) return;
    final elapsedMs = _clock.now.difference(startedAt).inMilliseconds;
    state = state.copyWith(
      millisLeft: (_countdownInitialMs - elapsedMs).clamp(
        0,
        state.config.timeLimitMs,
      ),
    );
  }

  void _stopCountdown() {
    _refreshCountdown();
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownStartedAt = null;
  }

  /// 发音
  void _speakWord(String word) {
    // 异步发音，不阻塞UI
    _ttsService.speak(word).catchError((error) {
      debugPrint('TTS error: $error');
      // 发音失败不影响功能
    });
  }

  String _attemptKey(Attempt attempt) =>
      '${attempt.wordId}:${attempt.timestamp.microsecondsSinceEpoch}:'
      '${attempt.result.name}:${attempt.chosenIndex}:${attempt.correctIndex}';

  Future<TestRun?> _existingSessionRun() async {
    return _findTestRunById(state.sessionId);
  }

  Future<TestRun?> _findTestRunById(String sessionId) async {
    try {
      final runs = await _progressRepository.getTestRunHistory(limit: 100);
      return runs.where((run) => run.id == sessionId).firstOrNull;
    } catch (e) {
      debugPrint('Unable to load persisted session $e');
      return null;
    }
  }

  Future<List<Attempt>> _mergePersistedAttempts(
    List<Attempt> currentAttempts,
  ) async {
    final merged = <Attempt>[];
    final seen = <String>{};

    void add(Attempt attempt) {
      if (attempt.wordId <= 0) return;
      if (seen.add(_attemptKey(attempt))) merged.add(attempt);
    }

    for (final attempt in currentAttempts) {
      add(attempt);
    }
    final existing = await _existingSessionRun();
    if (existing != null) {
      for (final attempt in existing.attempts) {
        add(attempt);
      }
    }
    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return merged;
  }

  /// 所有题目（含延迟重放）完成后，才统一写入学习数据。
  Future<void> _finishSession() async {
    if (state.state == SessionState.finished ||
        state.state == SessionState.saving) {
      return;
    }
    _isPaused = false;
    _stopCountdown();
    _cancelFeedback();
    state = state.copyWith(state: SessionState.saving, isPaused: false);
    try {
      final allAttempts = await _mergePersistedAttempts(
        state.attempts.where((a) => a.wordId > 0).toList(),
      );
      // 唯一的调度路径：逐条提交给 RecallCommitService（MemoryScheduler）。
      // 事件 ID 保证保存失败后重试不会重复应用同一次作答。
      for (final attempt in allAttempts) {
        await _commitCompletedAttempt(attempt);
      }

      if (_consumedNewWordIds.isNotEmpty) {
        await _consumeDailyNew(_consumedNewWordIds.length);
        _consumedNewWordIds.clear();
      }

      if (allAttempts.isNotEmpty) {
        var run = TestRun.create(
          id: state.sessionId,
          size: state.config.wordsPerSession,
          levels: state.config.levels,
          timeLimitMs: state.config.timeLimitMs,
          orderPolicy: state.config.orderPolicy,
          onlyLeeches: state.config.onlyLeeches,
        );
        for (final attempt in allAttempts) {
          run = run.addAttempt(attempt);
        }
        run = run.finish().copyWith(
          startedAt: allAttempts.first.timestamp,
          unresolvedWordIds: state.unresolvedWordIds.toList(),
        );
        await _progressRepository.batchSaveAttempts(allAttempts);
        await _progressRepository.saveTestRun(run);
      }
      debugPrint(
        'Session saved after completion: attempts=${allAttempts.length}',
      );
      if (mounted) {
        state = state.copyWith(state: SessionState.finished, isPaused: false);
      }
      await checkpointStore?.clear();
    } catch (e, stackTrace) {
      debugPrint('Error saving completed session: $e\n$stackTrace');
      if (mounted) {
        state = state.copyWith(state: SessionState.saveFailed, isPaused: false);
      }
    }
  }

  Future<void> retrySave() async {
    if (state.state == SessionState.saveFailed) await _finishSession();
  }

  /// 按题数节流地安排一次检查点写入（见 [checkpointSaveEveryQuestions]）。
  void _maybeSaveCheckpoint() {
    _questionsSinceCheckpoint++;
    if (_questionsSinceCheckpoint < checkpointSaveEveryQuestions) return;
    _questionsSinceCheckpoint = 0;
    _scheduleCheckpointSave();
  }

  /// 把一次检查点写入排到串行链尾部，保证与 `pauseSession()` 的写入不并发。
  void _scheduleCheckpointSave() {
    _checkpointWrite = _checkpointWrite.then((_) => _saveCheckpoint());
  }

  /// 落盘当前会话快照。
  ///
  /// 本方法保证不抛异常：它既被节流路径调用，也被暂停路径调用，任何逃逸的异常
  /// 都会打断 [_checkpointWrite] 串行链，让后续所有检查点写入永久静默失败。
  Future<void> _saveCheckpoint() async {
    try {
      final store = checkpointStore;
      if (store == null || state.sessionId.isEmpty) return;
      if (state.state == SessionState.finished ||
          state.state == SessionState.idle) {
        await store.clear();
        return;
      }
      final checkpoint = SessionCheckpoint.fromSessionData(state);
      await store.save(checkpoint);
    } catch (e) {
      debugPrint('Error saving session checkpoint: $e');
    }
  }

  /// 暂停会话
  void pauseSession() {
    if (_isPaused ||
        (state.state != SessionState.waiting &&
            state.state != SessionState.resolved)) {
      return;
    }
    debugPrint('Pausing session - current state: ${state.state}');
    _isPaused = true;
    _pauseFeedback();
    // 无论什么状态都停止计时器
    _stopCountdown();
    // 停止TTS播放
    _ttsService.stop().catchError((error) {
      debugPrint('Error stopping TTS during pause: $error');
    });
    state = state.copyWith(isPaused: true);
    // Persist the in-memory queue and attempts when the app/page is paused so
    // an OS process kill can resume the exact question instead of losing the
    // whole unfinished round. This does not commit SRS/progress records.
    // 暂停是「立即落盘」路径，不等节流窗口，因此把计数一并归零。
    _questionsSinceCheckpoint = 0;
    _scheduleCheckpointSave();
  }

  /// 恢复会话
  void resumeSession() {
    if (!_isPaused) return;
    debugPrint('Resuming session - current state: ${state.state}');
    _isPaused = false;
    state = state.copyWith(isPaused: false);

    if (_pendingNextQuestion) {
      _scheduleNextQuestion();
      return;
    }

    // 只在 waiting 状态下恢复计时器
    if (state.state == SessionState.waiting) {
      _startCountdown();
    }
  }

  /// 停止会话
  void stopSession() {
    if (!mounted || state.state == SessionState.saving) return;
    debugPrint('Stopping session - current state: ${state.state}');
    _isPaused = false;
    _cancelFeedback();
    _stopCountdown();

    // 停止TTS播放
    _ttsService.stop().catchError((error) {
      debugPrint('Error stopping TTS during session stop: $error');
    });

    checkpointStore?.clear();

    state = state.copyWith(
      state: SessionState.idle,
      currentQuestion: null,
      isPaused: false,
    );
    debugPrint('Session stopped');
  }

  @override
  void dispose() {
    _cancelFeedback();
    _stopCountdown();
    super.dispose();
  }
}
