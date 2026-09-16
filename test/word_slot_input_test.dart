import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/lexicon/domain/production_hint_helper.dart';
import 'package:vocab_flash_test/widgets/word_slot_input.dart';

void main() {
  group('WordSlotInput Widget Tests', () {
    testWidgets('renders correct number of slots for word', (tester) async {
      const word = 'cat';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordSlotInput(
              targetWord: word,
              revealedIndices: {},
            ),
          ),
        ),
      );

      expect(find.byType(WordSlotInput), findsOneWidget);
      // 'cat' has 3 letters
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('displays hinted consonants properly', (tester) async {
      const word = 'cat';
      // Revealed: c (0) and t (2)
      final revealed = ProductionHintHelper.getRevealedIndices(word, 1);
      expect(revealed, containsAll([0, 2]));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordSlotInput(
              targetWord: word,
              revealedIndices: revealed,
            ),
          ),
        ),
      );

      expect(find.text('c'), findsOneWidget);
      expect(find.text('t'), findsOneWidget);
      expect(find.text('a'), findsNothing);
    });

    testWidgets('full reveal shows all letters', (tester) async {
      const word = 'apple';
      final revealed = ProductionHintHelper.getRevealedIndices(word, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordSlotInput(
              targetWord: word,
              revealedIndices: revealed,
            ),
          ),
        ),
      );

      expect(find.text('a'), findsOneWidget);
      expect(find.text('p'), findsNWidgets(2));
      expect(find.text('l'), findsOneWidget);
      expect(find.text('e'), findsOneWidget);
    });
  });
}
