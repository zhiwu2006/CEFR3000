import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/domain/distractor.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/domain/testset.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/features/study/domain/session_checkpoint.dart';
import 'package:vocab_flash_test/features/study/data/session_checkpoint_store.dart';
import 'package:vocab_flash_test/session/session_models.dart';

void main() {
  group('专项优化测试：多义词干扰项防污染 (P0-1)', () {
    test('如果候选词的主释义或次要释义与目标词重合，则不得被选为干扰项', () {
      final service = DistractorService();
      final target = Word(
        id: 1,
        headword: 'run',
        lemma: 'run',
        level: 'A1',
        pos: 'v',
        cnDefs: ['跑', '经营', '运转'],
      );

      final pool = [
        target,
        Word(
          id: 2,
          headword: 'manage',
          lemma: 'manage',
          level: 'A1',
          pos: 'v',
          cnDefs: ['经营', '管理'],
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
          cnDefs: ['睡觉'],
        ),
        Word(
          id: 5,
          headword: 'swim',
          lemma: 'swim',
          level: 'A1',
          pos: 'v',
          cnDefs: ['游泳'],
        ),
      ];

      final question = service.buildQuestion(target, pool);

      expect(question.options.length, 4);
      expect(question.options[question.correctIndex], '跑');
      expect(question.options.contains('经营'), isFalse);
    });
  });

  group('专项优化测试：Question 运行时参数校验 (P2-6)', () {
    test('选项数量不等于4时必须抛出 ArgumentError', () {
      final word = Word(
        id: 1,
        headword: 'test',
        lemma: 'test',
        level: 'A1',
        pos: 'n',
        cnDefs: ['测试'],
      );

      expect(
        () => Question(
          word: word,
          options: ['A', 'B', 'C'],
          correctIndex: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Question(
          word: word,
          options: ['A', 'B', 'C', 'D', 'E'],
          correctIndex: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('correctIndex 越界时必须抛出 RangeError', () {
      final word = Word(
        id: 1,
        headword: 'test',
        lemma: 'test',
        level: 'A1',
        pos: 'n',
        cnDefs: ['测试'],
      );

      expect(
        () => Question(
          word: word,
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 4,
        ),
        throwsA(isA<RangeError>()),
      );

      expect(
        () => Question(
          word: word,
          options: ['A', 'B', 'C', 'D'],
          correctIndex: -1,
        ),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('专项优化测试：自然日到期判定 (P2-1)', () {
    test('同一天的卡片（即使具体时分秒未到）在自然日零点判定时算作到期', () {
      final now = DateTime.now();
      final laterToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final card = CardState.newCard(1).copyWith(due: laterToday);

      expect(card.isDue, isTrue);

      final tomorrow = now.add(const Duration(days: 1));
      final futureCard = CardState.newCard(2).copyWith(due: tomorrow);
      expect(futureCard.isDue, isFalse);
    });
  });

  group('专项优化测试：SRS 反应时间 EMA 平滑与错误过滤 (P1-3)', () {
    test('做错或超时的反应时间不混入基线，且 EMA 平滑历史数据', () {
      final initialCard = CardState.newCard(1).copyWith(rtP50: 1000);

      final attempts = [
        Attempt.wrong(
          wordId: 1,
          chosenIndex: 1,
          correctIndex: 0,
          rtMs: 200,
        ),
        Attempt.timeout(
          wordId: 1,
          correctIndex: 0,
        ),
        Attempt.correct(
          wordId: 1,
          chosenIndex: 0,
          correctIndex: 0,
          rtMs: 500,
        ),
      ];

      final result = SrsAlgorithm.batchUpdateCardStates(
        {1: initialCard},
        attempts,
        2000,
      );

      final updated = result[1]!;
      // 历史 rtP50=1000，本次有效正解中位数=500
      // EMA = 1000 * 0.7 + 500 * 0.3 = 700 + 150 = 850
      expect(updated.rtP50, 850);
    });
  });

  group('专项优化测试：SessionCheckpointStore 断点持久化 (P0-2)', () {
    test('SessionCheckpoint 正确持久化与反序列化', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SessionCheckpointStore(prefs);

      expect(store.load(), isNull);

      final checkpoint = SessionCheckpoint(
        sessionId: 'test-session-123',
        revision: 1,
        status: 'waiting',
        mainQueueWordIds: [1, 2, 3],
        delayedQueue: [],
        currentWordId: 1,
        currentOptions: ['A', 'B', 'C', 'D'],
        currentCorrectIndex: 0,
        selectedOption: -1,
        millisLeft: 1800,
        currentProgress: 0,
        attempts: [],
        config: {'wordsPerSession': 20},
        savedAt: DateTime.now(),
      );

      await store.save(checkpoint);

      final loaded = store.load();
      expect(loaded, isNotNull);
      expect(loaded!.sessionId, 'test-session-123');
      expect(loaded.mainQueueWordIds, [1, 2, 3]);
      expect(loaded.currentOptions, ['A', 'B', 'C', 'D']);

      await store.clear();
      expect(store.load(), isNull);
    });
  });

  group('专项优化测试：TestSetGenerator generateDailyDeck 字典优化 (P1-5)', () {
    test('全量词汇正常生成每日牌组且排除不存在的孤立卡片', () {
      final generator = TestSetGenerator();
      final allWords = [
        Word(id: 1, headword: 'a', lemma: 'a', level: 'A1', pos: 'n', cnDefs: ['A']),
        Word(id: 2, headword: 'b', lemma: 'b', level: 'A1', pos: 'n', cnDefs: ['B']),
      ];

      final allStates = {
        1: CardState.newCard(1).copyWith(due: DateTime.now().subtract(const Duration(days: 1))),
        999: CardState.newCard(999).copyWith(due: DateTime.now().subtract(const Duration(days: 1))),
      };

      final deck = generator.generateDailyDeck(
        allStates: allStates,
        allWords: allWords,
        levels: {'A1'},
        maxNewWords: 5,
      );

      expect(deck.any((w) => w.id == 1), isTrue);
      expect(deck.any((w) => w.id == 999), isFalse);
      expect(deck.length, 2);
    });
  });

  group('专项优化测试：单词配对默认数量为 100 个', () {
    test('SessionSettings 与 AppSettings 默认配置为 100 词', () {
      const session = SessionSettings();
      expect(session.wordsPerSession, 100);

      final appSettings = AppSettings.defaultSettings;
      expect(appSettings.wordsPerSession, 100);
      expect(appSettings.session.wordsPerSession, 100);
    });

    test('SessionConfig.fromCheckpointMap 缺省时默认回退为 100', () {
      final config = SessionConfig.fromCheckpointMap({'timeLimitMs': 2000});
      expect(config, isNotNull);
      expect(config!.wordsPerSession, 100);
    });
  });
}
