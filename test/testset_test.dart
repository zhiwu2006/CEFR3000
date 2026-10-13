import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/testset.dart';
import 'package:vocab_flash_test/models/models.dart';

void main() {
  group('TestSetGenerator', () {
    late TestSetGenerator generator;
    late List<Word> allWords;

    setUp(() {
      generator = TestSetGenerator(seed: 42);
      allWords = [
        const Word(
          id: 1,
          headword: 'apple',
          lemma: 'apple',
          level: 'A1',
          pos: 'n.',
          cnDefs: ['苹果'],
        ),
        const Word(
          id: 2,
          headword: 'banana',
          lemma: 'banana',
          level: 'A1',
          pos: 'n.',
          cnDefs: ['香蕉'],
        ),
        const Word(
          id: 3,
          headword: 'cat',
          lemma: 'cat',
          level: 'A1',
          pos: 'n.',
          cnDefs: ['猫'],
        ),
        const Word(
          id: 4,
          headword: 'run',
          lemma: 'run',
          level: 'A1',
          pos: 'v.',
          cnDefs: ['跑'],
        ),
        const Word(
          id: 5,
          headword: 'jump',
          lemma: 'jump',
          level: 'A1',
          pos: 'v.',
          cnDefs: ['跳'],
        ),
        const Word(
          id: 6,
          headword: 'beautiful',
          lemma: 'beautiful',
          level: 'A2',
          pos: 'adj.',
          cnDefs: ['美丽的'],
        ),
        const Word(
          id: 7,
          headword: 'car',
          lemma: 'car',
          level: 'A2',
          pos: 'n.',
          cnDefs: ['汽车'],
        ),
        const Word(
          id: 8,
          headword: 'house',
          lemma: 'house',
          level: 'A2',
          pos: 'n.',
          cnDefs: ['房子'],
        ),
        const Word(
          id: 9,
          headword: 'important',
          lemma: 'important',
          level: 'B1',
          pos: 'adj.',
          cnDefs: ['重要的'],
        ),
        const Word(
          id: 10,
          headword: 'develop',
          lemma: 'develop',
          level: 'B1',
          pos: 'v.',
          cnDefs: ['发展'],
        ),
      ];
    });

    test('generates test set with correct size', () {
      final testSet = generator.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2'},
        size: 5,
        orderPolicy: 'random',
      );

      expect(testSet.length, equals(5));
    });

    test('filters by selected levels', () {
      final testSet = generator.generateTestSet(
        allWords: allWords,
        levels: {'A1'},
        size: 10,
        orderPolicy: 'random',
      );

      // 所有词都应该是A1级别
      for (final word in testSet) {
        expect(word.level, equals('A1'));
      }
    });

    test('orders by level correctly', () {
      final testSet = generator.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2', 'B1'},
        size: 8,
        orderPolicy: 'by_level',
      );

      // 验证级别顺序：A1 -> A2 -> B1
      String? lastLevel;
      final levelOrder = ['A1', 'A2', 'B1'];

      for (final word in testSet) {
        if (lastLevel != null) {
          final lastIndex = levelOrder.indexOf(lastLevel);
          final currentIndex = levelOrder.indexOf(word.level);
          expect(currentIndex, greaterThanOrEqualTo(lastIndex));
        }
        lastLevel = word.level;
      }
    });

    test('handles only leeches mode', () {
      final leechWords = allWords.take(3).toList();

      final testSet = generator.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2'},
        size: 5,
        orderPolicy: 'random',
        onlyLeeches: true,
        leechWords: leechWords,
      );

      // 在只练不熟模式下，应该只包含不熟词
      for (final word in testSet) {
        expect(leechWords.any((w) => w.id == word.id), isTrue);
      }
    });

    test('prioritizes due words in normal mode', () {
      final dueWords = [allWords[0], allWords[1]];

      final testSet = generator.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2'},
        size: 5,
        orderPolicy: 'random',
        dueWords: dueWords,
      );

      // 应该包含所有到期词
      for (final dueWord in dueWords) {
        expect(testSet.any((w) => w.id == dueWord.id), isTrue);
      }
    });

    test('validates test set quality', () {
      final testSet = allWords.take(5).toList();

      final validation = generator.validateTestSetQuality(testSet, allWords);

      expect(validation['isValid'], isA<bool>());
      expect(validation['levelDistribution'], isA<Map<String, int>>());
      expect(validation['posDistribution'], isA<Map<String, int>>());
      expect(validation['avgDistractorPoolSize'], isA<double>());
      expect(validation['totalWords'], equals(5));
      expect(validation['uniqueWords'], equals(5));
    });

    test('generates daily deck with proper mix', () {
      final mockStates = {
        1: CardState.newCard(
          1,
        ).copyWith(due: DateTime.now().subtract(const Duration(days: 1))), // 到期
        2: CardState.newCard(
          2,
        ).copyWith(lapses: 2, longTermReviews: 1), // 学会后又遗忘的不熟词
        3: CardState.newCard(3).markDifficult(), // 标记疑难
      };

      final dailyDeck = generator.generateDailyDeck(
        allStates: mockStates,
        allWords: allWords,
        levels: {'A1', 'A2'},
        maxNewWords: 3,
      );

      // 应该包含到期词、不熟词和新词
      expect(dailyDeck.isNotEmpty, isTrue);

      // 应该包含到期词
      expect(dailyDeck.any((w) => w.id == 1), isTrue);

      // 应该包含不熟词
      expect(dailyDeck.any((w) => w.id == 2), isTrue);
      expect(dailyDeck.any((w) => w.id == 3), isTrue);
    });

    test('reorders existing test set', () {
      final originalTestSet = [allWords[2], allWords[0], allWords[1]]; // 随机顺序

      final reorderedByLevel = generator.reorderTestSet(
        originalTestSet,
        'by_level',
      );
      final reorderedRandom = generator.reorderTestSet(
        originalTestSet,
        'random',
      );

      expect(reorderedByLevel.length, equals(originalTestSet.length));
      expect(reorderedRandom.length, equals(originalTestSet.length));

      // 验证所有词都在重排序后的集合中
      for (final word in originalTestSet) {
        expect(reorderedByLevel.any((w) => w.id == word.id), isTrue);
        expect(reorderedRandom.any((w) => w.id == word.id), isTrue);
      }
    });

    test('provides test set statistics', () {
      final testSet = allWords.take(5).toList();

      final stats = generator.getTestSetStatistics(testSet);

      expect(stats['totalWords'], equals(5));
      expect(stats['levelCounts'], isA<Map<String, int>>());
      expect(stats['posCounts'], isA<Map<String, int>>());
      expect(stats['avgDefinitionsPerWord'], isA<double>());
      expect(stats['avgDefinitionsPerWord'], equals(1.0)); // 每个词只有1个定义
    });

    test('handles empty input gracefully', () {
      final emptyStats = generator.getTestSetStatistics([]);
      expect(emptyStats['totalWords'], equals(0));
      expect(emptyStats['avgDefinitionsPerWord'], equals(0.0));

      final emptyValidation = generator.validateTestSetQuality([], allWords);
      expect(emptyValidation['isValid'], isFalse);
      expect(emptyValidation['reason'], contains('Empty'));
    });

    test('ensures consistent results with same seed', () {
      final generator1 = TestSetGenerator(seed: 123);
      final generator2 = TestSetGenerator(seed: 123);

      final testSet1 = generator1.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2'},
        size: 5,
        orderPolicy: 'random',
      );

      final testSet2 = generator2.generateTestSet(
        allWords: allWords,
        levels: {'A1', 'A2'},
        size: 5,
        orderPolicy: 'random',
      );

      // 相同的种子应该产生相同的结果
      expect(
        testSet1.map((w) => w.id).toList(),
        equals(testSet2.map((w) => w.id).toList()),
      );
    });

    test(
      'orders by level correctly including C1, C2 and custom levels without dropping words',
      () {
        final extendedWords = [
          ...allWords,
          const Word(
            id: 11,
            headword: 'complex',
            lemma: 'complex',
            level: 'B2',
            pos: 'adj.',
            cnDefs: ['复杂的'],
          ),
          const Word(
            id: 12,
            headword: 'abstract',
            lemma: 'abstract',
            level: 'C1',
            pos: 'adj.',
            cnDefs: ['抽象的'],
          ),
          const Word(
            id: 13,
            headword: 'subtle',
            lemma: 'subtle',
            level: 'C2',
            pos: 'adj.',
            cnDefs: ['微妙的'],
          ),
          const Word(
            id: 14,
            headword: 'custom',
            lemma: 'custom',
            level: 'EXT',
            pos: 'n.',
            cnDefs: ['自定义'],
          ),
        ];

        final testSet = generator.generateTestSet(
          allWords: extendedWords,
          levels: {'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'EXT'},
          size: extendedWords.length,
          orderPolicy: 'by_level',
        );

        expect(testSet.length, equals(extendedWords.length));
        final levelsInOrder = testSet.map((w) => w.level).toList();

        // 确认 C1, C2, EXT 均未被遗漏
        expect(levelsInOrder.contains('C1'), isTrue);
        expect(levelsInOrder.contains('C2'), isTrue);
        expect(levelsInOrder.contains('EXT'), isTrue);

        final levelHierarchy = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
        int lastStandardIndex = -1;
        for (final word in testSet) {
          final idx = levelHierarchy.indexOf(word.level);
          if (idx != -1) {
            expect(idx, greaterThanOrEqualTo(lastStandardIndex));
            lastStandardIndex = idx;
          }
        }
      },
    );
  });
}
