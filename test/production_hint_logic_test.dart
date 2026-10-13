import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/lexicon/domain/production_hint_helper.dart';

void main() {
  group('ProductionHintHelper', () {
    test('apple: consonants p, l; vowels a, e', () {
      const word = 'apple';
      // Indices: 0:a, 1:p, 2:p, 3:l, 4:e
      // Level 0: empty
      expect(ProductionHintHelper.getRevealedIndices(word, 0), isEmpty);

      // Level 1: consonants -> 1, 2, 3 ('p', 'p', 'l')
      final l1 = ProductionHintHelper.getRevealedIndices(word, 1);
      expect(l1, containsAll([1, 2, 3]));
      expect(l1, isNot(contains(0)));
      expect(l1, isNot(contains(4)));

      // Level 2: consonants + vowels, but preserving at least 1 blank for the learner
      final l2 = ProductionHintHelper.getRevealedIndices(word, 2);
      expect(l2.length, greaterThanOrEqualTo(l1.length));
      expect(l2.length, lessThan(5)); // At least 1 slot left!
      expect(l2, containsAll([1, 2, 3])); // Keeps L1 cues

      // Level 3: Full reveal
      final l3 = ProductionHintHelper.getRevealedIndices(word, 3);
      expect(l3, equals({0, 1, 2, 3, 4}));
    });

    test('multi-word phrase with space and punctuation', () {
      const word = 'take-off';
      // Indices: 0:t, 1:a, 2:k, 3:e, 4:-, 5:o, 6:f, 7:f
      final l1 = ProductionHintHelper.getRevealedIndices(word, 1);
      expect(l1, containsAll([0, 2, 6, 7])); // t, k, f, f
      expect(l1, isNot(contains(4))); // punctuation is not in alpha indices

      final l3 = ProductionHintHelper.getRevealedIndices(word, 3);
      expect(l3, equals({0, 1, 2, 3, 5, 6, 7}));
    });

    test('single vowel word "I" or short word "an"', () {
      expect(ProductionHintHelper.getRevealedIndices('I', 1), contains(0));
      expect(ProductionHintHelper.getRevealedIndices('I', 3), contains(0));

      final anL1 = ProductionHintHelper.getRevealedIndices('an', 1);
      expect(anL1, contains(1)); // n is consonant

      final anL2 = ProductionHintHelper.getRevealedIndices('an', 2);
      expect(anL2.length, 1); // exactly 1 letter left for 2-letter word

      final anL3 = ProductionHintHelper.getRevealedIndices('an', 3);
      expect(anL3, equals({0, 1}));
    });
  });
}
