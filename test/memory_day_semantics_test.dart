import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/features/study/domain/study_plan.dart';
import 'package:vocab_flash_test/models/card_state.dart';

void main() {
  test('a card due tonight counts as a due review this morning', () {
    final due = DateTime(2026, 10, 13, 21);
    expect(RecallCommitService.isDueOn(due, DateTime(2026, 10, 13, 7)), isTrue);
    expect(
      RecallCommitService.isDueOn(due, DateTime(2026, 10, 12, 23, 59)),
      isFalse,
    );
  });

  test(
    'planner treats later-today due cards as overdue, not extra practice',
    () {
      final plan = const StudyPlanner().build(
        [
          StudyCandidate(
            wordId: 1,
            dueAt: DateTime(2026, 10, 13, 21),
            isNew: false,
            isLeech: false,
            isRelearning: false,
          ),
        ],
        const StudyPolicy(
          maxItems: 10,
          maxMinutes: 10,
          dailyNewLimit: 10,
          dailyNewUsed: 0,
        ),
        now: DateTime(2026, 10, 13, 7),
      );
      expect(plan.items.single.reason, PlanReason.overdue);
    },
  );

  test('failures on a never-learned word are not lapses or leeches', () {
    var state = CardState.newCard(1);
    for (var i = 0; i < 3; i++) {
      state = SrsAlgorithm.updateCardState(state, 1);
    }
    expect(state.lapses, 0);
    expect(const LeechPolicy().isLeech(state), isFalse);

    final learned = state.copyWith(longTermReviews: 1, lapses: 2);
    expect(const LeechPolicy().isLeech(learned), isTrue);
  });
}
