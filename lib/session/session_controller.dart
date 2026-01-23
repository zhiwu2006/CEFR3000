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

/// 会话控制器
class SessionController extends StateNotifier<SessionData> {
  final WordRepository _wordRepository;
  final ProgressRepository _progressRepository;
  final TtsService _ttsService;
  final DistractorService _distractorService;
  final WordSelectionService _wordSelectionService;
  final DelayedReplayManager _delayedReplayManager;

  Timer? _countdownTimer;
  List<Word>? _candidatePool; // 干扰项候选池
  bool _isPaused = false;
  bool _pendingNextQuestion = false;

  SessionController({
    required WordRepository wordRepository,
    required ProgressRepository progressRepository,
    required TtsService ttsService,
    required DistractorService distractorService,
    required int Function() getDailyNewRemaining,
    required Future<void> Function(int) consumeDailyNew,
  }) : _wordRepository = wordRepository,
       _progressRepository = progressRepository,
       _ttsService = ttsService,
       _distractorService = distractorService,
       _wordSelectionService = WordSelectionService(
         progressRepository: progressRepository,
         getDailyNewRemaining: getDailyNewRemaining,
         consumeDailyNew: consumeDailyNew,
       ),
       _delayedReplayManager = const DelayedReplayManager(),
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
       );

  /// 开始新会话或恢复会话
  Future<void> startSession(
    SessionConfig config, {
    String? resumeSessionId,
    List<int>? remainingWordIds,
    int? currentProgress,
  }) async {
    try {
      debugPrint('=== Starting session with config: $config');
      _isPaused = false;
      _pendingNextQuestion = false;

      // 记录上一轮出现过的单词，优先避开
      Set<int> recentWordIds = {};
      Set<int> hardWordIds = {};
      try {
        final lastRun = await _progressRepository.getLatestTestRun();
        if (lastRun != null) {
          recentWordIds = lastRun.attempts.map((a) => a.wordId).toSet();
          final slowThreshold = config.timeLimitMs * config.slowThreshold;
          for (final a in lastRun.attempts) {
            if (a.isWrong || a.isTimeout || a.rtMs > slowThreshold) {
              hardWordIds.add(a.wordId);
            }
          }
          debugPrint('Found ${recentWordIds.length} recent words; ${hardWordIds.length} marked as hard (keep in rotation)');
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
      String sessionId;
      int progress = 0;

      final resumeRequested = resumeSessionId != null &&
          remainingWordIds != null &&
          remainingWordIds.isNotEmpty;

      // 检查是否是恢复会话
      if (resumeRequested) {
        debugPrint('=== Resuming existing session ===');
        debugPrint('Session ID: $resumeSessionId');
        debugPrint('Remaining word IDs: ${remainingWordIds.length}');
        debugPrint('Current progress: ${currentProgress ?? 0}');

        sessionId = resumeSessionId;
        progress = currentProgress ?? 0;

        // 根据剩余的单词ID恢复单词列表
        for (final wordId in remainingWordIds) {
          final word = _candidatePool!.where((w) => w.id == wordId).firstOrNull;
          if (word != null) {
            availableWords.add(word);
          }
        }

        debugPrint('Restored ${availableWords.length} words from saved session');
        if (availableWords.isEmpty) {
          debugPrint('No remaining words matched current levels, starting a new session instead');
        }
      } else {
        debugPrint('=== Starting new session ===');

        // 生成新会话ID
        const uuid = Uuid();
        sessionId = uuid.v4();

        // 基于“到期/错题/新词/填充”策略选词
        availableWords = await _wordSelectionService.buildWordListForNewSession(
          config: config,
          candidatePool: _candidatePool!,
          recentWordIds: recentWordIds,
          hardWordIds: hardWordIds,
        );
      }

      if (resumeRequested && availableWords.isEmpty) {
        debugPrint('Fallback: building a new session word list');
        const uuid = Uuid();
        sessionId = uuid.v4();
        progress = 0;
        availableWords = await _wordSelectionService.buildWordListForNewSession(
          config: config,
          candidatePool: _candidatePool!,
          recentWordIds: recentWordIds,
          hardWordIds: hardWordIds,
        );
      }

      // 尝试避开上一轮测试过的单词，若数量不足再补回
      if (recentWordIds.isNotEmpty) {
        final avoidIds = recentWordIds.difference(hardWordIds);

        final hardWords = availableWords.where((w) => hardWordIds.contains(w.id)).toList();
        final freshWords = availableWords.where((w) => !recentWordIds.contains(w.id)).toList();
        final reusableWords = availableWords.where((w) => avoidIds.contains(w.id)).toList();

        final combined = <Word>[];
        combined.addAll(hardWords);
        combined.addAll(freshWords.where((w) => !combined.any((c) => c.id == w.id)));

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

      debugPrint('Using ${availableWords.length} words for test');

      if (availableWords.isEmpty) {
        throw Exception('No words available for the selected configuration.');
      }

      // 初始化会话数据
      state = SessionData.initial(
        initialQueue: availableWords,
        config: config,
        sessionId: sessionId,
      );

      // 如果是恢复会话，需要创建已完成的attempts来反映进度
      if (progress > 0) {
        // 创建虚拟的attempts来反映已完成的进度
        final dummyAttempts = List.generate(
          progress,
          (index) => Attempt(
            wordId: 0, // 虚拟ID
            chosenIndex: 0,
            correctIndex: 0,
            rtMs: 0,
            result: AttemptResult.correct,
            timestamp: DateTime.now().subtract(
              Duration(minutes: progress - index),
            ),
          ),
        );
        state = state.copyWith(attempts: dummyAttempts);
        debugPrint('Restored session with $progress completed attempts');
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

  /// 用户选择选项
  Future<void> selectOption(int optionIndex) async {
    if (state.state != SessionState.waiting || state.currentQuestion == null) {
      debugPrint('selectOption ignored: state=${state.state}, hasQuestion=${state.currentQuestion != null}');
      return; // 无效状态，忽略
    }

    try {
      // 停止计时器
      _stopCountdown();

      // 计算反应时间
      final reactionTime = state.questionStartTime != null
          ? DateTime.now().difference(state.questionStartTime!).inMilliseconds
          : 0;

      // 创建答题记录
      final attempt = _createAttempt(
        optionIndex,
        reactionTime,
      );

      // 进入resolved状态
      state = state.copyWith(
        state: SessionState.resolved,
        selectedOption: optionIndex,
        lastCorrect: attempt.isCorrect,
      );

      // 处理答题结果
      await _handleAttemptResult(attempt);

      // 根据答案正误设置不同的延迟时间
      final delayDuration = attempt.isCorrect
          ? const Duration(milliseconds: 250) // 正确答案保持原来的时间
          : const Duration(milliseconds: 800); // 错误答案停留0.8秒（原1秒，优化节奏）

      await Future.delayed(delayDuration);
      await _presentNextQuestion();
    } catch (e, stackTrace) {
      debugPrint('Error in selectOption: $e');
      debugPrint('Stack trace: $stackTrace');
      // 尝试恢复
      await _presentNextQuestion();
    }
  }

  /// 超时处理
  Future<void> _onTimeout() async {
    if (state.state != SessionState.waiting || state.currentQuestion == null) {
      debugPrint('_onTimeout ignored: state=${state.state}, hasQuestion=${state.currentQuestion != null}');
      return;
    }

    try {
      // 创建超时答题记录
      final attempt = _createAttempt(
        -1,
        state.config.timeLimitMs,
      );

      // 进入resolved状态
      state = state.copyWith(
        state: SessionState.resolved,
        selectedOption: -1,
        lastCorrect: false,
      );

      // 处理答题结果
      await _handleAttemptResult(attempt);

      // 超时情况停留1秒让用户熟悉单词
      await Future.delayed(const Duration(milliseconds: 1000));
      await _presentNextQuestion();
    } catch (e, stackTrace) {
      debugPrint('Error in _onTimeout: $e');
      debugPrint('Stack trace: $stackTrace');
      // 尝试恢复
      await _presentNextQuestion();
    }
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
    // 1. 处理延迟队列成熟的项目
    _processDelayedQueue();

    // 2. 从主队列取词
    if (state.mainQueue.isNotEmpty) {
      final word = state.mainQueue.first;
      state = state.copyWith(mainQueue: state.mainQueue.skip(1).toList());
      return word;
    }

    // 3. 检查是否还有延迟项目
    if (state.delayedQueue.isNotEmpty) {
      // 强制取出最近的延迟项目
      final delayedItem = state.delayedQueue.first;
      final word = _candidatePool?.firstWhere(
        (w) => w.id == delayedItem.wordId,
        orElse: () => throw StateError('Word not found in candidate pool: ${delayedItem.wordId}'),
      );

      if (word == null) {
        // 如果找不到单词，跳过这个延迟项目
        debugPrint('Warning: Could not find word ${delayedItem.wordId} in candidate pool, skipping');
        state = state.copyWith(delayedQueue: state.delayedQueue.skip(1).toList());
        return _getNextWord(); // 递归获取下一个
      }

      state = state.copyWith(delayedQueue: state.delayedQueue.skip(1).toList());

      return word;
    }

    return null; // 没有更多题目
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
    _isPaused = false;
    _pendingNextQuestion = false;

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
    );

    await _presentNextQuestion();
  }

  /// 处理延迟队列
  void _processDelayedQueue() {
    if (state.delayedQueue.isEmpty) return;

    final candidatePool = _candidatePool;
    if (candidatePool == null || candidatePool.isEmpty) {
      debugPrint('Warning: Candidate pool is empty during delayed queue processing');
      return;
    }

    final result = _delayedReplayManager.processDelayedQueue(
      mainQueue: state.mainQueue,
      delayedQueue: state.delayedQueue,
      candidatePool: candidatePool,
    );

    state = state.copyWith(
      mainQueue: result.mainQueue,
      delayedQueue: result.delayedQueue,
    );
  }


  /// 处理答题结果
  Future<void> _handleAttemptResult(Attempt attempt) async {
    // 添加到答题记录
    final newAttempts = [...state.attempts, attempt];
    state = state.copyWith(attempts: newAttempts);
    // 【已移除】自动标记功能过于激进（一次错误即标记）。
    // 现在移交给 CardState 的 lapses 机制处理：累计错误才会变成 Leech。
    // 原代码位置: await _progressRepository.markWordDifficult(attempt.wordId);

    // 检查是否需要延迟回放
    final shouldDelay = _shouldDelayWord(attempt);
    if (shouldDelay) {
      _scheduleDelayedReplay(attempt);
    }

    if (state.config.ttsOnWrong && !attempt.isCorrect) {
      final word = _candidatePool?.firstWhere(
        (w) => w.id == attempt.wordId,
        orElse: () => Word(
          id: attempt.wordId,
          headword: '',
          lemma: '',
          level: '',
          pos: '',
          cnDefs: const [''],
        ),
      );
      if (word != null && word.headword.isNotEmpty) {
        _speakWord(word.headword);
      }
    }

    // 更新最近出现的单词ID（用于冷却）
    final newRecentIds = Set<int>.from(state.recentWordIds)
      ..add(attempt.wordId);
    if (newRecentIds.length > 5) {
      // 只保留最近5个
      newRecentIds.remove(newRecentIds.first);
    }
    state = state.copyWith(recentWordIds: newRecentIds);
  }

  /// 判断是否需要延迟回放
  bool _shouldDelayWord(Attempt attempt) {
    return _delayedReplayManager.shouldDelayWord(attempt, state.config);
  }

  /// 安排延迟回放
  void _scheduleDelayedReplay(Attempt attempt) {
    final updatedDelayed = _delayedReplayManager.scheduleDelayedReplay(
      delayedQueue: state.delayedQueue,
      attempt: attempt,
      config: state.config,
    );

    state = state.copyWith(delayedQueue: updatedDelayed);
  }

  /// 创建答题记录
  Attempt _createAttempt(
    int chosenIndex,
    int reactionTime,
  ) {
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
      timestamp: DateTime.now(),
    );
  }

  /// 开始倒计时
  void _startCountdown() {
    if (_isPaused) return;
    _stopCountdown(); // 确保没有重复计时器

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isPaused) return;
      if (state.millisLeft <= 0) {
        timer.cancel();
        _onTimeout();
      } else {
        state = state.copyWith(millisLeft: state.millisLeft - 50);
      }
    });
  }

  /// 停止倒计时
  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// 发音
  void _speakWord(String word) {
    // 异步发音，不阻塞UI
    _ttsService.speak(word).catchError((error) {
      debugPrint('TTS error: $error');
      // 发音失败不影响功能
    });
  }

  /// 完成会话
  Future<void> _finishSession() async {
    _isPaused = false;
    _pendingNextQuestion = false;
    _stopCountdown();

    state = state.copyWith(
      state: SessionState.finished,
      isPaused: false,
    );

    if (state.attempts.isEmpty) {
      debugPrint('No attempts recorded, finishing session without saving run data');
      return;
    }

    // 保存测试会话记录
    var testRun = TestRun.create(
      id: state.sessionId,
      size: state.config.wordsPerSession,
      levels: state.config.levels,
      timeLimitMs: state.config.timeLimitMs,
      orderPolicy: state.config.orderPolicy,
      onlyLeeches: state.config.onlyLeeches,
    );

    for (final attempt in state.attempts) {
      testRun = testRun.addAttempt(attempt);
    }
    testRun = testRun.finish();

    try {
      await _progressRepository.saveTestRun(testRun);

      await _progressRepository.batchSaveAttempts(state.attempts);
      await _updateSrsStates();
    } catch (e) {
      debugPrint('Error saving session data: $e');
    }
  }

  /// 更新SRS状态
  Future<void> _updateSrsStates() async {
    if (state.attempts.isEmpty) return;

    try {
      // 获取涉及的单词ID，并按出现顺序保持稳定
      final wordIds = state.attempts
          .map((a) => a.wordId)
          .toSet()
          .toList();

      // 获取当前状态，并回填缺失卡片
      final currentStates = await _progressRepository.getCardStates(wordIds);
      final stateMap = {for (var s in currentStates) s.wordId: s};
      for (final id in wordIds) {
        stateMap.putIfAbsent(id, () => CardState.newCard(id));
      }

      // 批量更新状态
      final updatedStates = SrsAlgorithm.batchUpdateCardStates(
        stateMap,
        state.attempts,
        state.config.timeLimitMs,
      );

      await _progressRepository.batchUpdateCardStates(updatedStates);
    } catch (e) {
      debugPrint('Error updating SRS states: $e');
    }
  }

  /// 暂停会话
  void pauseSession() {
    debugPrint('Pausing session - current state: ${state.state}');
    _isPaused = true;
    _pendingNextQuestion = false;
    // 无论什么状态都停止计时器
    _stopCountdown();
    // 停止TTS播放
    _ttsService.stop().catchError((error) {
      debugPrint('Error stopping TTS during pause: $error');
    });
    state = state.copyWith(isPaused: true);
  }

  /// 恢复会话
  void resumeSession() {
    debugPrint('Resuming session - current state: ${state.state}');
    _isPaused = false;
    state = state.copyWith(isPaused: false);

    if (_pendingNextQuestion) {
      _pendingNextQuestion = false;
      _presentNextQuestion();
      return;
    }

    // 只在 waiting 状态下恢复计时器
    if (state.state == SessionState.waiting) {
      _startCountdown();
    }
  }

  /// 停止会话
  /// 停止会话
  void stopSession() {
    debugPrint('Stopping session - current state: ${state.state}');
    _isPaused = false;
    _pendingNextQuestion = false;
    _stopCountdown();

    // 停止TTS播放
    _ttsService.stop().catchError((error) {
      debugPrint('Error stopping TTS during session stop: $error');
    });

    state = state.copyWith(
      state: SessionState.idle,
      currentQuestion: null,
      isPaused: false,
    );
    debugPrint('Session stopped');
  }

  /// 跳过当前题目
  Future<void> skipCurrentQuestion() async {
    if (state.currentQuestion != null) {
      await _onTimeout(); // 当作超时处理
    }
  }

  /// 标记当前单词为疑难
  Future<void> markCurrentWordDifficult() async {
    final currentWord = state.currentQuestion?.word;
    if (currentWord != null) {
      try {
        final currentState =
            await _progressRepository.getCardState(currentWord.id) ??
            CardState.newCard(currentWord.id);
        final markedState = currentState.markDifficult();
        await _progressRepository.saveCardState(markedState);
      } catch (e) {
        debugPrint('Error marking word as difficult: $e');
      }
    }
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }
}
