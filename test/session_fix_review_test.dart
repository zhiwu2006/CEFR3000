import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/session_models.dart';
import 'package:vocab_flash_test/session/delayed_replay_manager.dart';
import 'package:vocab_flash_test/session/word_selection_service.dart';
import 'package:vocab_flash_test/data/repositories.dart';

// 模拟测试用的 Mock Repository
class MockProgressRepository implements ProgressRepository {
  List<Word> dueWords = [];
  List<Word> leechWords = [];
  List<Word> newWords = [];
  Map<int, CardState> cardStates = {};
  List<TestRun> savedTestRuns = [];
  List<Attempt> savedAttempts = [];

  @override
  Future<List<Word>> getDueWords(Set<String> levels) async => dueWords;

  @override
  Future<List<Word>> getLeechWords(Set<String> levels) async => leechWords;

  @override
  Future<List<Word>> getNewWords(Set<String> levels, int limit) async =>
      newWords.take(limit).toList();

  @override
  Future<List<CardState>> getCardStates(List<int> wordIds) async {
    return wordIds
        .where((id) => cardStates.containsKey(id))
        .map((id) => cardStates[id]!)
        .toList();
  }

  @override
  Future<void> saveTestRun(TestRun run) async {
    savedTestRuns.add(run);
  }

  @override
  Future<void> batchSaveAttempts(List<Attempt> attempts) async {
    savedAttempts.addAll(attempts);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Review Bug 1: 默认答题时间 2000ms 兜底与下限 clamp', () {
    test('SessionSettings default timeLimitMs is 2000', () {
      const settings = SessionSettings();
      expect(settings.timeLimitMs, 2000);
    });

    test('SessionConfig.fromAppSettings falls back to 2000 when <= 0', () {
      final appSettings = AppSettings.defaultSettings.copyWith(
        session: const SessionSettings(timeLimitMs: 0),
      );
      final config = SessionConfig.fromAppSettings(appSettings);
      expect(config.timeLimitMs, 2000);
    });

    test(
      'SessionConfig.fromAppSettings clamps timeLimitMs to at least 1000ms',
      () {
        final appSettings = AppSettings.defaultSettings.copyWith(
          session: const SessionSettings(timeLimitMs: 400),
        );
        final config = SessionConfig.fromAppSettings(appSettings);
        expect(config.timeLimitMs, 1000);
      },
    );
  });

  group('Review Bug 2: 错题重试次数熔断，防止无限死循环', () {
    test(
      'DelayedReplayManager rejects scheduling when sessionRetryCount >= maxRetries (3)',
      () {
        const manager = DelayedReplayManager();

        final attempt = Attempt.wrong(
          wordId: 101,
          rtMs: 1200,
          chosenIndex: 1,
          correctIndex: 0,
        );

        final config = SessionConfig.defaultConfig.copyWith(wrongDelay: 3);

        // 第 1 次调度 (sessionRetryCount = 0) -> 入队成功，返回队列长度为 1
        final q1 = manager.scheduleDelayedReplay(
          delayedQueue: [],
          attempt: attempt,
          config: config,
          sessionRetryCount: 0,
        );
        expect(q1.length, 1);
        expect(q1.first.wordId, 101);

        // 第 2 次调度 (sessionRetryCount = 1) -> 入队成功
        final q2 = manager.scheduleDelayedReplay(
          delayedQueue: [],
          attempt: attempt,
          config: config,
          sessionRetryCount: 1,
        );
        expect(q2.length, 1);

        // 第 3 次调度 (sessionRetryCount = 2) -> 入队成功
        final q3 = manager.scheduleDelayedReplay(
          delayedQueue: [],
          attempt: attempt,
          config: config,
          sessionRetryCount: 2,
        );
        expect(q3.length, 1);

        // 第 4 次调度 (sessionRetryCount = 3) -> 达到上限，熔断不再入队，返回空队列！
        final q4 = manager.scheduleDelayedReplay(
          delayedQueue: [],
          attempt: attempt,
          config: config,
          sessionRetryCount: 3,
        );
        expect(q4.isEmpty, isTrue);
      },
    );
  });

  group('Review Bug 4: 每日新词限额保护与 Filler 逻辑', () {
    late MockProgressRepository mockRepo;
    late int dailyRemaining;
    late int consumedDailyNew;

    setUp(() {
      mockRepo = MockProgressRepository();
      dailyRemaining = 0;
      consumedDailyNew = 0;
    });

    Word createWord(int id, String headword, String level) {
      return Word(
        id: id,
        headword: headword,
        lemma: headword,
        level: level,
        pos: 'n',
        cnDefs: ['中文释义'],
      );
    }

    test('当每日新词额度为0时，Filler 不会挑选纯新词，也不会消耗新词额度', () async {
      dailyRemaining = 0;
      final service = WordSelectionService(
        progressRepository: mockRepo,
        getDailyNewRemaining: () => dailyRemaining,
        consumeDailyNew: (n) async => consumedDailyNew += n,
      );

      // 准备候选词：1 和 2 是学过的复习词，3 和 4 是纯新词（无 cardState）
      final w1 = createWord(1, 'apple', 'A1');
      final w2 = createWord(2, 'banana', 'A1');
      final w3 = createWord(3, 'cherry', 'A1');
      final w4 = createWord(4, 'date', 'A1');

      mockRepo.cardStates[1] = CardState(
        wordId: 1,
        stability: 2.0,
        difficulty: 2.0,
        due: DateTime.now().add(const Duration(days: 3)),
        lapses: 0,
        rtP50: 800,
        flags: 0,
        lastReview: DateTime.now().subtract(const Duration(days: 2)),
      );
      mockRepo.cardStates[2] = CardState(
        wordId: 2,
        stability: 2.0,
        difficulty: 2.0,
        due: DateTime.now().add(const Duration(days: 3)),
        lapses: 0,
        rtP50: 800,
        flags: 0,
        lastReview: DateTime.now().subtract(const Duration(days: 1)),
      );

      final config = SessionConfig.defaultConfig.copyWith(
        wordsPerSession: 4,
        levels: {'A1'},
        timeLimitMs: 2000,
        orderPolicy: 'random',
        newCardRatio: 0.5,
        onlyLeeches: false,
      );

      final words = await service.buildWordListForNewSession(
        config: config,
        candidatePool: [w1, w2, w3, w4],
        recentWordIds: {},
        hardWordIds: {},
      );

      // 只有 2 个已学过的复习词能被选入，因为每日新词额度为 0，纯新词 w3, w4 绝不能被填入
      expect(words.map((w) => w.id).toSet(), equals({1, 2}));
      expect(consumedDailyNew, 0);
    });

    test('当有每日新词额度时，补充纯新词受额度限制并正确扣减消耗', () async {
      dailyRemaining = 1; // 仅剩 1 个新词额度
      final service = WordSelectionService(
        progressRepository: mockRepo,
        getDailyNewRemaining: () => dailyRemaining,
        consumeDailyNew: (n) async => consumedDailyNew += n,
      );

      final w1 = createWord(1, 'apple', 'A1');
      final w2 = createWord(2, 'banana', 'A1');
      final w3 = createWord(3, 'cherry', 'A1');

      // 没有任何复习词
      final config = SessionConfig.defaultConfig.copyWith(
        wordsPerSession: 3,
        levels: {'A1'},
        timeLimitMs: 2000,
        orderPolicy: 'random',
        newCardRatio: 0.0, // 初始新词比例为0，需要靠 filler
        onlyLeeches: false,
      );

      final words = await service.buildWordListForNewSession(
        config: config,
        candidatePool: [w1, w2, w3],
        recentWordIds: {},
        hardWordIds: {},
      );

      // 即使需要 3 个词，但每日额度只有 1，最多只能取 1 个纯新词
      expect(words.length, 1);
      expect(consumedDailyNew, 1);
    });
  });

  group('Review Bug 5: 仅疑难词模式 (onlyLeeches) 纯净性', () {
    late MockProgressRepository mockRepo;
    late int consumedDailyNew;

    setUp(() {
      mockRepo = MockProgressRepository();
      consumedDailyNew = 0;
    });

    Word createWord(int id, String headword, String level) {
      return Word(
        id: id,
        headword: headword,
        lemma: headword,
        level: level,
        pos: 'n',
        cnDefs: ['中文释义'],
      );
    }

    test('onlyLeeches 模式下仅返回 leechWords，绝不混入 dueWords 或普通候选词', () async {
      final service = WordSelectionService(
        progressRepository: mockRepo,
        getDailyNewRemaining: () => 10,
        consumeDailyNew: (n) async => consumedDailyNew += n,
      );

      final leech1 = createWord(10, 'leechA', 'A1');
      final leech2 = createWord(11, 'leechB', 'A1');
      final normal1 = createWord(20, 'normalA', 'A1');
      final due1 = createWord(30, 'dueA', 'A1');

      mockRepo.leechWords = [leech1, leech2];
      mockRepo.dueWords = [due1];

      final config = SessionConfig.defaultConfig.copyWith(
        wordsPerSession: 5,
        levels: {'A1'},
        timeLimitMs: 2000,
        orderPolicy: 'random',
        newCardRatio: 0.5,
        onlyLeeches: true,
      );

      final words = await service.buildWordListForNewSession(
        config: config,
        candidatePool: [leech1, leech2, normal1, due1],
        recentWordIds: {},
        hardWordIds: {},
      );

      // 只包含 leech1 和 leech2，普通词和 due 词绝不进入
      expect(words.map((w) => w.id).toSet(), equals({10, 11}));
      // 绝不扣减新词配额
      expect(consumedDailyNew, 0);
    });
  });
}
