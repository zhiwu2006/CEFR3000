import '../../../models/card_state.dart';

enum LeechInterventionAction {
  relearnMeaning,
  practiceProduction,
  inspectContent,
  suspend,
}

/// 给疑难词一个有限、可解释的下一步，而不是无止境地重复同一题型。
class LeechInterventionPlan {
  final int wordId;
  final LeechInterventionAction primaryAction;
  final List<LeechInterventionAction> availableActions;
  final String reason;
  final int suggestedAttempts;

  const LeechInterventionPlan({
    required this.wordId,
    required this.primaryAction,
    required this.availableActions,
    required this.reason,
    required this.suggestedAttempts,
  });

  bool get shouldPauseCard => primaryAction == LeechInterventionAction.suspend;
}

class LeechInterventionPolicy {
  final int maxFocusedAttempts;
  final int suspendAfterLapses;

  const LeechInterventionPolicy({
    this.maxFocusedAttempts = 3,
    this.suspendAfterLapses = 8,
  });

  LeechInterventionPlan plan(CardState state) {
    final action = state.lapses >= suspendAfterLapses
        ? LeechInterventionAction.suspend
        : state.stability < 1.5
        ? LeechInterventionAction.relearnMeaning
        : state.isMarkedDifficult
        ? LeechInterventionAction.practiceProduction
        : LeechInterventionAction.inspectContent;
    final actions = <LeechInterventionAction>[
      LeechInterventionAction.relearnMeaning,
      LeechInterventionAction.practiceProduction,
      LeechInterventionAction.inspectContent,
      if (state.lapses >= suspendAfterLapses) LeechInterventionAction.suspend,
    ];
    return LeechInterventionPlan(
      wordId: state.wordId,
      primaryAction: action,
      availableActions: List.unmodifiable(actions),
      reason: switch (action) {
        LeechInterventionAction.relearnMeaning => '近期多次遗忘，先回到词义回忆',
        LeechInterventionAction.practiceProduction => '识别已有基础，增加英文产出验证',
        LeechInterventionAction.inspectContent => '检查义项和例句后再安排下一次回忆',
        LeechInterventionAction.suspend => '遗忘次数过高，暂停自动安排并等待人工处理',
      },
      suggestedAttempts: maxFocusedAttempts,
    );
  }
}
