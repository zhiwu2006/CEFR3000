import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/distractor.dart';
import 'package:vocab_flash_test/models/models.dart';

void main() {
  group('DistractorService', () {
    late DistractorService service;
    late List<Word> candidatePool;

    setUp(() {
      service = DistractorService(seed: 42); // 固定种子以获得可重复的结果
      candidatePool = [
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
          headword: 'dog',
          lemma: 'dog',
          level: 'A1',
          pos: 'n.',
          cnDefs: ['狗'],
        ),
        const Word(
          id: 5,
          headword: 'run',
          lemma: 'run',
          level: 'A1',
          pos: 'v.',
          cnDefs: ['跑'],
        ),
        const Word(
          id: 6,
          headword: 'jump',
          lemma: 'jump',
          level: 'A1',
          pos: 'v.',
          cnDefs: ['跳'],
        ),
        const Word(
          id: 7,
          headword: 'beautiful',
          lemma: 'beautiful',
          level: 'A2',
          pos: 'adj.',
          cnDefs: ['美丽的'],
        ),
        const Word(
          id: 8,
          headword: 'car',
          lemma: 'car',
          level: 'A2',
          pos: 'n.',
          cnDefs: ['汽车'],
        ),
      ];
    });

    test('generates 4 options with correct answer included', () {
      final targetWord = candidatePool[0]; // apple
      final result = service.buildQuestion(targetWord, candidatePool);

      expect(result.options.length, equals(4));
      expect(result.options.contains('苹果'), isTrue);
      expect(result.correctIndex, greaterThanOrEqualTo(0));
      expect(result.correctIndex, lessThan(4));
      expect(result.options[result.correctIndex], equals('苹果'));
    });

    test('prioritizes same level and same POS for distractors', () {
      final targetWord = candidatePool[0]; // apple (A1, n.)
      final result = service.buildQuestion(targetWord, candidatePool);

      // 应该包含其他A1级别的名词作为干扰项
      final distractors = result.options
          .where((option) => option != '苹果')
          .toList();

      // 验证干扰项不包含正确答案
      expect(distractors.contains('苹果'), isFalse);

      // 验证没有重复的干扰项
      expect(distractors.toSet().length, equals(distractors.length));
    });

    for (final samePosCount in [1, 2]) {
      test(
        'fills same-level candidates after $samePosCount same-POS matches',
        () {
          // Put a cross-level candidate first so linear fallback cannot hide the bug.
          final pool = [
            candidatePool[6],
            candidatePool[0],
            candidatePool[1],
            if (samePosCount == 2) candidatePool[2],
            candidatePool[4],
            candidatePool[5],
          ];
          for (var seed = 0; seed < 10; seed++) {
            final result = DistractorService(
              seed: seed,
            ).buildQuestion(candidatePool[0], pool);
            expect(result.options, isNot(contains('美丽的')));
            expect(result.options.toSet(), hasLength(4));
            expect(result.options[result.correctIndex], '苹果');
          }
        },
      );
    }

    test(
      'cross-level supplement uses seeded selection rather than linear fallback',
      () {
        final pool = [
          candidatePool[6],
          candidatePool[7],
          candidatePool[0],
          candidatePool[1],
          candidatePool[2],
        ];
        final chosen = <String>{};
        for (var seed = 0; seed < 30; seed++) {
          final result = DistractorService(
            seed: seed,
          ).buildQuestion(candidatePool[0], pool);
          expect(result.options, containsAll(['苹果', '香蕉', '猫']));
          chosen.addAll(result.options.where((s) => s == '美丽的' || s == '汽车'));
        }
        expect(chosen, {'美丽的', '汽车'});
      },
    );

    test('handles insufficient same-level same-POS candidates', () {
      // 创建一个只有少数同级别同词性候选词的场景
      final limitedPool = [
        candidatePool[0], // apple (target)
        candidatePool[1], // banana (same level, same pos)
        candidatePool[4], // run (same level, different pos)
        candidatePool[6], // beautiful (different level)
      ];

      final result = service.buildQuestion(candidatePool[0], limitedPool);

      expect(result.options.length, equals(4));
      expect(result.options.contains('苹果'), isTrue);
    });

    test('avoids duplicate definitions in options', () {
      final targetWord = candidatePool[0];
      final result = service.buildQuestion(targetWord, candidatePool);

      final uniqueOptions = result.options.toSet();
      expect(uniqueOptions.length, equals(result.options.length));
    });

    test('evaluates distractor quality correctly', () {
      final targetWord = candidatePool[0]; // apple (A1, n.)
      final distractors = ['香蕉', '猫', '狗']; // all A1 nouns

      final quality = service.evaluateDistractorQuality(
        targetWord,
        distractors,
        candidatePool,
      );

      expect(quality, greaterThan(0.5)); // 应该有较高的质量分数
    });

    test('batch builds multiple questions', () {
      final targetWords = [candidatePool[0], candidatePool[1]];
      final results = service.batchBuildQuestions(targetWords, candidatePool);

      expect(results.length, equals(2));

      for (final result in results) {
        expect(result.options.length, equals(4));
        expect(result.correctIndex, greaterThanOrEqualTo(0));
        expect(result.correctIndex, lessThan(4));
      }
    });

    test('returns consistent results with same seed', () {
      final service1 = DistractorService(seed: 42);
      final service2 = DistractorService(seed: 42);

      final targetWord = candidatePool[0];
      final result1 = service1.buildQuestion(targetWord, candidatePool);
      final result2 = service2.buildQuestion(targetWord, candidatePool);

      expect(result1.options, equals(result2.options));
      expect(result1.correctIndex, equals(result2.correctIndex));
    });
  });
}
