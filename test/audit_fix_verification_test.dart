import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/domain/distractor.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/features/progress/domain/memory_analytics.dart';
import 'package:vocab_flash_test/features/study/data/session_checkpoint_store.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/session_controller.dart';
import 'package:vocab_flash_test/session/session_models.dart';
import 'package:vocab_flash_test/data/tts_service.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/data/progress_repository.dart';

// ─── Stubs ───

class _Words implements WordRepository {
  final List<Word> words;
  _Words([this.words = const []]);

  @override
  Future<List<Word>> loadAll() async => words;
  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async =>
      words.where((w) => levels.contains(w.level)).toList();
  @override
  Future<List<Word>> getByIds(List<int> ids) async =>
      words.where((w) => ids.contains(w.id)).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Progress implements ProgressRepository {
  @override
  Future<CardState?> getCardState(int wordId) async => null;
  @override
  Future<List<CardState>> getCardStates(List<int> wordIds) async => [];
  @override
  Future<TestRun?> getLatestTestRun() async => null;
  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async => const [];
  @override
  Future<List<Word>> getNewWords(Set<String> levels, int limit) async => [];
  @override
  Future<List<Word>> getDueWords(Set<String> levels) async => [];
  @override
  Future<List<Word>> getLeechWords(Set<String> levels) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tts implements TtsService {
  @override
  Future<void> stop() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Attempt _attempt(int wordId, DateTime ts, {bool correct = true}) => Attempt(
  wordId: wordId,
  result: correct ? AttemptResult.correct : AttemptResult.wrong,
  rtMs: 700,
  chosenIndex: correct ? 0 : -1,
  correctIndex: 0,
  timestamp: ts,
);

ReviewEvent _event(
  String id,
  int wordId,
  DateTime ts, {
  bool correct = true,
  bool due = true,
  bool independent = true,
  String skill = 'meaningRecognition',
}) {
  final attempt = _attempt(wordId, ts, correct: correct);
  return ReviewEvent(
    id: id,
    sessionId: 'session',
    attempt: attempt,
    beforeRevision: 0,
    resultingState: CardState.newCard(wordId, now: ts),
    status: 'committed',
    evaluationSource: 'objective',
    taskType: 'recognition',
    createdAt: ts,
    isDueReview: due,
    independentRecall: independent,
    rating: correct ? 'recalled' : 'forgot',
    skill: skill,
  );
}

// ─── Tests ───

void main() {
  // ═══════════════════════════════════════════════════════════════
  // P1-B: RecallEvaluator 独立回忆 vs 辅助回忆
  // ═══════════════════════════════════════════════════════════════

  group('P1-B 修复验证: RecallEvaluator 独立回忆路径', () {
    test('answerRevealed=false 且到期复习成功时 countsAsLongTermReview 为 true', () {
      final evidence = RecallEvidence(
        eventId: 'e1',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecall,
        taskType: ReviewTaskType.recall,
        rating: RecallRating.recalled,
        source: EvaluationSource.selfReport,
        answerRevealed: false, // 独立回忆
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: DateTime(2026, 9, 16),
      );

      expect(evidence.isIndependentRecall, isTrue);

      final evaluation = RecallEvaluator.evaluate(evidence);
      expect(evaluation.countsAsLongTermReview, isTrue);
      expect(evaluation.reason, 'independent_recall');
      expect(evaluation.quality, 4);
    });

    test('answerRevealed=true 时 countsAsLongTermReview 为 false (辅助回忆)', () {
      final evidence = RecallEvidence(
        eventId: 'e2',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecall,
        taskType: ReviewTaskType.recall,
        rating: RecallRating.recalled,
        source: EvaluationSource.selfReport,
        answerRevealed: true, // 辅助回忆
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: DateTime(2026, 9, 16),
      );

      expect(evidence.isIndependentRecall, isFalse);

      final evaluation = RecallEvaluator.evaluate(evidence);
      expect(evaluation.countsAsLongTermReview, isFalse);
      expect(evaluation.reason, 'assisted_recall');
    });

    test('独立回忆但 forgot 时 countsAsLongTermReview 为 false', () {
      final evidence = RecallEvidence(
        eventId: 'e3',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecall,
        taskType: ReviewTaskType.recall,
        rating: RecallRating.forgot,
        source: EvaluationSource.selfReport,
        answerRevealed: false,
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: DateTime(2026, 9, 16),
      );

      final evaluation = RecallEvaluator.evaluate(evidence);
      expect(evaluation.countsAsLongTermReview, isFalse);
      expect(evaluation.quality, 1);
    });

    test('SRS shortTermReview 正确反映 countsAsLongTermReview', () {
      // 独立回忆 → countsAsLongTerm=true → shortTermReview=false
      final independent = RecallEvidence(
        eventId: 'e4',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecall,
        taskType: ReviewTaskType.recall,
        rating: RecallRating.easy,
        source: EvaluationSource.selfReport,
        answerRevealed: false,
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: DateTime(2026, 9, 16),
      );
      final evalIndependent = RecallEvaluator.evaluate(independent);
      expect(evalIndependent.countsAsLongTermReview, isTrue);
      final shortTermIndependent = !evalIndependent.countsAsLongTermReview;
      expect(shortTermIndependent, isFalse); // 不是短期复习

      // 辅助回忆 → countsAsLongTerm=false → shortTermReview=true
      final assisted = RecallEvidence(
        eventId: 'e5',
        sessionId: 's1',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecall,
        taskType: ReviewTaskType.recall,
        rating: RecallRating.easy,
        source: EvaluationSource.selfReport,
        answerRevealed: true,
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: DateTime(2026, 9, 16),
      );
      final evalAssisted = RecallEvaluator.evaluate(assisted);
      expect(evalAssisted.countsAsLongTermReview, isFalse);
      final shortTermAssisted = !evalAssisted.countsAsLongTermReview;
      expect(shortTermAssisted, isTrue); // 是短期复习
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // P1-A: 带 checkpoint store 的 SessionController 集成测试
  // ═══════════════════════════════════════════════════════════════

  group('P1-A / 2026-10-12 修复验证: 检查点节流落盘，暂停立即落盘', () {
    testWidgets('未答满节流窗口不落盘，pauseSession 立即写入检查点', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SessionCheckpointStore(prefs);
      const checkpointKey = 'study_session_checkpoint_v1';

      final controller = SessionController(
        wordRepository: _Words([
          Word(
            id: 1,
            headword: 'test',
            lemma: 'test',
            level: 'A1',
            pos: 'n',
            cnDefs: ['测试'],
          ),
          Word(
            id: 2,
            headword: 'run',
            lemma: 'run',
            level: 'A1',
            pos: 'v',
            cnDefs: ['跑'],
          ),
          Word(
            id: 3,
            headword: 'eat',
            lemma: 'eat',
            level: 'A1',
            pos: 'v',
            cnDefs: ['吃'],
          ),
          Word(
            id: 4,
            headword: 'sleep',
            lemma: 'sleep',
            level: 'A1',
            pos: 'v',
            cnDefs: ['睡'],
          ),
        ]),
        progressRepository: _Progress(),
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 42),
        getDailyNewRemaining: () => 30,
        consumeDailyNew: (_) async {},
        checkpointStore: store,
      );

      await controller.startSession(
        SessionConfig.defaultConfig.copyWith(
          plannedWordIds: [1, 2, 3, 4],
          wordsPerSession: 4,
          timeLimitMs: 5000,
          ttsAutoPlay: false,
          ttsOnWrong: false,
        ),
      );

      // 会话已开始，应有当前题目
      expect(controller.state.currentQuestion, isNotNull);

      // 选择答案
      controller.selectOption(controller.state.currentQuestion!.correctIndex);

      // 等待异步保存完成
      await tester.pump(const Duration(milliseconds: 100));

      // 2026-10-12 修复后：答题按题数节流落盘，单题作答尚未达到
      // SessionController.checkpointSaveEveryQuestions，因此不应产生写入。
      expect(
        prefs.containsKey(checkpointKey),
        isFalse,
        reason: '未答满节流窗口时不应写入检查点',
      );

      // 暂停会保存恢复用检查点，但不提交 SRS/学习记录。
      controller.pauseSession();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        prefs.containsKey(checkpointKey),
        isTrue,
        reason: 'pauseSession 应写入可跨进程恢复的检查点',
      );

      controller.stopSession();
    });

    // ── 2026-10-12 审查「崩溃恢复只在退到后台时才有效」──
    // 前台崩溃/被杀不会再走 pauseSession，因此必须有答题过程中的自动落盘。
    // 这里断言：答满节流窗口后无需暂停即可恢复整轮进度。
    testWidgets('答满节流窗口后自动落盘，无需退到后台', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SessionCheckpointStore(prefs);
      const checkpointKey = 'study_session_checkpoint_v1';

      // 需要至少 checkpointSaveEveryQuestions 个词才能答满窗口。
      final total = SessionController.checkpointSaveEveryQuestions;
      final words = List.generate(
        total + 1,
        (i) => Word(
          id: i + 1,
          headword: 'w${i + 1}',
          lemma: 'w${i + 1}',
          level: 'A1',
          pos: 'n',
          cnDefs: ['释义${i + 1}'],
        ),
      );

      final controller = SessionController(
        wordRepository: _Words(words),
        progressRepository: _Progress(),
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 42),
        getDailyNewRemaining: () => 30,
        consumeDailyNew: (_) async {},
        checkpointStore: store,
      );

      await controller.startSession(
        SessionConfig.defaultConfig.copyWith(
          plannedWordIds: words.map((w) => w.id).toList(),
          wordsPerSession: words.length,
          timeLimitMs: 5000,
          ttsAutoPlay: false,
          ttsOnWrong: false,
        ),
      );

      for (var answered = 1; answered <= total; answered++) {
        final question = controller.state.currentQuestion;
        expect(question, isNotNull, reason: '第 $answered 题应已就绪');
        // 全部答对，避免进入延迟回放队列打乱题序。
        controller.selectOption(question!.correctIndex);
        await tester.pump(const Duration(milliseconds: 100));

        if (answered < total) {
          expect(
            prefs.containsKey(checkpointKey),
            isFalse,
            reason: '第 $answered 题未答满节流窗口，不应落盘',
          );
        }

        // 走完 800ms 反馈窗口，进入下一题。
        await tester.pump(SessionController.feedbackDuration);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        prefs.containsKey(checkpointKey),
        isTrue,
        reason: '答满 $total 题后应自动落盘，不需要退到后台',
      );
      final saved = store.load();
      expect(saved, isNotNull);
      expect(saved!.status, SessionState.resolved.name);
      expect(saved.isResumable, isTrue, reason: '前台被杀后可据此恢复整轮进度');

      controller.stopSession();
      controller.dispose();
    });

    // ── 2026-09-23 审查 4.1 / 4.2：端到端恢复闭环 ──
    // 旧判据用 settings.hasActiveSession，而首页式会话从不写 currentSessionId，
    // 导致检查点被读出后丢弃。这里从「首页式启动」一路走到「重启后恢复」，
    // 断言已答记录、会话 ID、当前题与反馈态都被保住。
    testWidgets('首页式会话在反馈窗口内被杀死后，重启可恢复到同一题与同一进度', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SessionCheckpointStore(prefs);

      final words = [
        Word(
          id: 1,
          headword: 'test',
          lemma: 'test',
          level: 'A1',
          pos: 'n',
          cnDefs: ['测试'],
        ),
        Word(
          id: 2,
          headword: 'run',
          lemma: 'run',
          level: 'A1',
          pos: 'v',
          cnDefs: ['跑'],
        ),
        Word(
          id: 3,
          headword: 'eat',
          lemma: 'eat',
          level: 'A1',
          pos: 'v',
          cnDefs: ['吃'],
        ),
        Word(
          id: 4,
          headword: 'sleep',
          lemma: 'sleep',
          level: 'A1',
          pos: 'v',
          cnDefs: ['睡'],
        ),
      ];
      final sessionConfig = SessionConfig.defaultConfig.copyWith(
        plannedWordIds: [1, 2, 3, 4],
        wordsPerSession: 4,
        timeLimitMs: 5000,
        ttsAutoPlay: false,
        ttsOnWrong: false,
      );

      SessionController build() => SessionController(
        wordRepository: _Words(words),
        progressRepository: _Progress(),
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 42),
        getDailyNewRemaining: () => 30,
        consumeDailyNew: (_) async {},
        checkpointStore: store,
      );

      // 1) 首页式会话：作答一题后在 800ms 反馈窗口内被杀死。
      final first = build();
      await first.startSession(sessionConfig);
      final sessionId = first.state.sessionId;
      final answeredWordId = first.state.currentQuestion!.word.id;
      first.selectOption(first.state.currentQuestion!.correctIndex);
      first.pauseSession();
      await tester.pump(const Duration(milliseconds: 100));

      final saved = store.load();
      expect(saved, isNotNull, reason: '暂停应写入检查点');
      expect(saved!.sessionId, sessionId);
      expect(saved.status, SessionState.resolved.name);
      expect(saved.isResumable, isTrue, reason: '4.1：判据取自检查点自身');
      expect(
        saved.totalQuestionCount,
        greaterThanOrEqualTo(4),
        reason: '统计页「当前会话」卡片依赖该口径',
      );
      first.dispose();

      // 2) 重启：走 test_screen 的恢复路径（只看检查点，不看 settings）。
      final second = build();
      await second.startSession(
        SessionConfig.fromCheckpointMap(saved.config) ?? sessionConfig,
        resumeSessionId: saved.sessionId,
        remainingWordIds: saved.mainQueueWordIds,
        currentProgress: saved.currentProgress,
        checkpoint: saved,
      );

      expect(second.state.sessionId, sessionId, reason: '应续用原会话 ID');
      expect(second.state.attempts.length, 1, reason: '已答记录不应丢失');
      expect(second.state.attempts.single.wordId, answeredWordId);
      expect(second.state.currentQuestion!.word.id, answeredWordId);
      expect(
        second.state.state,
        SessionState.resolved,
        reason: '4.2：resolved 快照应恢复到反馈态，不重新开放作答',
      );

      second.stopSession();
      second.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // P2-B: 干扰项兜底路径冲突检测
  // ═══════════════════════════════════════════════════════════════

  group('P2-B 修复验证: 干扰项兜底路径排除包含冲突', () {
    test('兜底路径不会将与正确答案有包含关系的定义作为干扰项', () {
      // 构造一个极端场景：正确答案"跑步"，候选池中有"跑步运动"
      final target = Word(
        id: 1,
        headword: 'run',
        lemma: 'run',
        level: 'C2',
        pos: 'interj', // 罕见词性，确保前三层策略失败进入兜底
        cnDefs: ['跑步'],
      );
      final pool = [
        target,
        // 这个词的定义包含目标词的定义，应被排除
        Word(
          id: 2,
          headword: 'jogging',
          lemma: 'jogging',
          level: 'C2',
          pos: 'n',
          cnDefs: ['跑步运动'],
        ),
        // 这个词的定义被目标词定义包含，应被排除
        Word(
          id: 3,
          headword: 'step',
          lemma: 'step',
          level: 'C2',
          pos: 'n',
          cnDefs: ['跑'],
        ),
        // 安全的干扰项
        Word(
          id: 4,
          headword: 'swim',
          lemma: 'swim',
          level: 'C2',
          pos: 'v',
          cnDefs: ['游泳'],
        ),
        Word(
          id: 5,
          headword: 'fly',
          lemma: 'fly',
          level: 'C2',
          pos: 'v',
          cnDefs: ['飞行'],
        ),
        Word(
          id: 6,
          headword: 'walk',
          lemma: 'walk',
          level: 'C2',
          pos: 'v',
          cnDefs: ['走路'],
        ),
      ];

      final service = DistractorService(seed: 1);
      final question = service.buildQuestion(target, pool);

      // 干扰选项中不应有"跑步运动"或"跑"
      final distractors = question.options
          .where((o) => o != question.options[question.correctIndex])
          .toList();
      for (final d in distractors) {
        expect(
          d.contains('跑步') || '跑步'.contains(d),
          isFalse,
          reason: '干扰项 "$d" 与正确答案 "跑步" 有包含冲突',
        );
      }
    });

    test('兜底路径在无合格候选时使用占位符', () {
      // 所有候选词的定义都与目标有冲突
      final target = Word(
        id: 1,
        headword: 'run',
        lemma: 'run',
        level: 'C2',
        pos: 'interj',
        cnDefs: ['跑步'],
      );
      final pool = [
        target,
        Word(
          id: 2,
          headword: 'a',
          lemma: 'a',
          level: 'C2',
          pos: 'n',
          cnDefs: ['跑步训练'],
        ),
        Word(
          id: 3,
          headword: 'b',
          lemma: 'b',
          level: 'C2',
          pos: 'n',
          cnDefs: ['跑步机'],
        ),
      ];

      final service = DistractorService(seed: 1);
      final question = service.buildQuestion(target, pool);

      // 应有4个选项（1正确 + 3干扰，部分可能是占位符）
      expect(question.options.length, 4);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // P2-C: 观测窗口按 (wordId, skill) 分组
  // ═══════════════════════════════════════════════════════════════

  group('P2-C 修复验证: 观测窗口按技能类型分组', () {
    test('不同技能的复习事件不混入同一观测样本', () {
      final day0 = DateTime(2026, 9, 1);
      final day7 = DateTime(2026, 9, 8);

      // wordId=1, 识别技能: day0 + day7
      // wordId=1, 回忆技能: day0 (仅有一次)
      final events = [
        _event('e1', 1, day0, skill: 'meaningRecognition'),
        _event('e2', 1, day0, skill: 'meaningRecall'),
        _event('e3', 1, day7, skill: 'meaningRecognition'),
      ];

      final metric = MemoryAnalytics.observation(events, 7);

      // 修复前: byWord[1] 会混合两种技能，可能将 day0 recall + day7 recognition
      // 作为一个观测样本。
      // 修复后: 仅 (1, meaningRecognition) 有 day0→day7 的有效窗口。
      // (1, meaningRecall) 只有一条事件，不构成观测。
      expect(metric.eligibleCount, 1, reason: '仅识别技能有 ≥7 天间隔的两次事件');
    });

    test('同一技能同一单词的多次复习正确计入观测', () {
      final day0 = DateTime(2026, 9, 1);
      final day30 = DateTime(2026, 10, 1);

      final events = [
        _event('e1', 42, day0, skill: 'meaningRecognition'),
        _event('e2', 42, day30, skill: 'meaningRecognition'),
      ];

      final metric = MemoryAnalytics.observation(events, 30);
      expect(metric.eligibleCount, 1);
      expect(metric.successCount, 1); // correct=true
    });

    test('不同单词相同技能各自独立计入观测', () {
      final day0 = DateTime(2026, 9, 1);
      final day8 = DateTime(2026, 9, 9);

      final events = [
        _event('e1', 1, day0, skill: 'meaningRecognition'),
        _event('e2', 1, day8, skill: 'meaningRecognition'),
        _event('e3', 2, day0, skill: 'meaningRecognition'),
        _event('e4', 2, day8, skill: 'meaningRecognition'),
      ];

      final metric = MemoryAnalytics.observation(events, 7);
      expect(metric.eligibleCount, 2, reason: '两个不同单词各有一个 ≥7 天窗口');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // P0 专项：100词会话进度显示与进度条溢出修复验证
  // ═══════════════════════════════════════════════════════════════

  group('进度显示与进度条精度修复验证 (100词单轮会话)', () {
    test('发生多次错题重测时，分子恒不超过分母，进度条单调平滑推进', () {
      final testWords = List.generate(
        100,
        (i) => Word(
          id: i + 1,
          headword: 'word$i',
          lemma: 'word$i',
          level: 'A1',
          pos: 'n',
          cnDefs: ['释义$i'],
        ),
      );

      final config = SessionConfig.defaultConfig.copyWith(
        wordsPerSession: 100,
        plannedWordIds: testWords.map((w) => w.id).toList(),
      );

      var data = SessionData.initial(
        initialQueue: testWords,
        config: config,
        sessionId: 'session-100',
        totalWords: 100,
      );

      // 1. 初始状态：总词数100，第1题，完成0题，进度0.0
      expect(data.totalWords, 100);
      expect(data.completedWordCount, 0);
      expect(data.currentWordIndex, 1);
      expect(data.progressRatio, 0.0);

      // 2. 模拟前20个词做完，但其中产生了26次答题记录（因为有6次错题重测）
      // 即 attempts.length = 26，但实际只有20个唯一词被移出主队列，
      // 假设其中5个词进入了 delayedQueue，15个词彻底完成。
      final remainingMain = testWords.skip(20).toList(); // 剩余80个在主队列
      final delayedItems = [
        DelayedItem(wordId: 1, retryCount: 1),
        DelayedItem(wordId: 2, retryCount: 1),
        DelayedItem(wordId: 3, retryCount: 1),
        DelayedItem(wordId: 4, retryCount: 1),
        DelayedItem(wordId: 5, retryCount: 1),
      ];
      final dummyAttempts = List.generate(
        46, // 模拟产生了46次答题历史（如旧版本导致 46 / 20）
        (i) => Attempt(
          wordId: (i % 20) + 1,
          result: AttemptResult.correct,
          rtMs: 500,
          chosenIndex: 0,
          correctIndex: 0,
          timestamp: DateTime.now(),
        ),
      );

      data = data.copyWith(
        mainQueue: remainingMain,
        delayedQueue: delayedItems,
        attempts: dummyAttempts,
        currentQuestion: Question(
          word: testWords[20],
          options: const ['A', 'B', 'C', 'D'],
          correctIndex: 0,
        ),
      );

      // 剩余未解决唯一词：mainQueue(21..100) + delayed(1..5) + current(21) 去重后为 85个
      // 已彻底完成唯一词：100 - 85 = 15个
      expect(data.totalWords, 100);
      expect(data.completedWordCount, 15);
      // 当前进行第16个词，绝不是旧逻辑的 46 + 1 = 47！
      expect(data.currentWordIndex, 16);
      expect(data.progressRatio, closeTo(15 / 100, 0.001));

      // 3. 模拟主队列清空，全部进入最后5个错题重测阶段
      data = data.copyWith(
        mainQueue: const [],
        delayedQueue: delayedItems.sublist(1), // 4个待重测
        currentQuestion: Question(
          word: testWords[0], // 正在重测第1个词
          options: const ['A', 'B', 'C', 'D'],
          correctIndex: 0,
        ),
      );
      // 剩余未解决唯一词：4 + 1 = 5个，已完成 95个
      expect(data.completedWordCount, 95);
      expect(data.currentWordIndex, 96);
      expect(data.progressRatio, 0.95);

      // 4. 会话全部完成
      data = data.copyWith(
        state: SessionState.finished,
        mainQueue: const [],
        delayedQueue: const [],
        currentQuestion: null,
      );
      expect(data.completedWordCount, 100);
      expect(data.currentWordIndex, 100);
      expect(data.progressRatio, 1.0);
    });
  });

  group('100词会话选词与配额兜底对齐验证', () {
    test('纯新词库且单日剩余额度不足时，SessionController兜底补齐候选词至100词', () async {
      // 准备150个A1词
      final pool = List.generate(
        150,
        (i) => Word(
          id: i + 1,
          headword: 'word${i + 1}',
          lemma: 'word${i + 1}',
          level: 'A1',
          pos: 'n',
          cnDefs: ['释义${i + 1}'],
        ),
      );

      final controller = SessionController(
        wordRepository: _Words(pool),
        progressRepository: _Progress(),
        ttsService: _Tts(),
        distractorService: DistractorService(seed: 42),
        getDailyNewRemaining: () => 47,
        consumeDailyNew: (_) async {},
        consumeNewOnSelection: false,
      );

      final config = SessionConfig.defaultConfig.copyWith(
        levels: {'A1'},
        wordsPerSession: 100,
        timeLimitMs: 2000,
        orderPolicy: 'random',
        onlyLeeches: false,
        ttsAutoPlay: false,
        ttsOnWrong: false,
      );

      await controller.startSession(config);

      // 验证最终选出的总词数坚定对齐100词，不再被截断为47词！
      expect(controller.state.totalWords, 100);
      expect(controller.state.currentWordIndex, 1);
      expect(controller.state.progressRatio, 0.0);
      expect(controller.state.mainQueue.length, 99); // 1正在出题，99在主队列
    });

    test('AppSettings.defaultSettings 中的 dailyNewLimit 为 100', () {
      expect(AppSettings.defaultSettings.algorithm.dailyNewLimit, 100);
      expect(AppSettings.defaultSettings.session.wordsPerSession, 100);
    });
  });
}
