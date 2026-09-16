import '../../../models/attempt.dart';

/// 单词学习的能力维度。
///
/// 一个词条可以同时拥有多个能力，但能力必须分别验证，不能把识别
/// 选择题的成功自动当成英文产出或拼写成功。
enum LearningSkill {
  meaningRecognition,
  meaningRecall,
  englishProduction,
  listening,
  spelling,
}

enum RecallRating { forgot, difficult, recalled, easy }

enum EvaluationSource { objective, selfReport, legacy, imported }

enum ReviewTaskType { recognition, recall, production, listening, spelling }

enum MemoryPhase { newCard, learning, review, relearning, suspended }

class RecallEvidence {
  final String eventId;
  final String sessionId;
  final int itemId;
  final int lexemeId;
  final LearningSkill skill;
  final ReviewTaskType taskType;
  final RecallRating rating;
  final EvaluationSource source;
  final bool answerRevealed;
  final bool hintUsed;
  final bool isDueReview;
  final int activeDurationMs;
  final DateTime occurredAt;
  final AttemptKind attemptKind;

  const RecallEvidence({
    required this.eventId,
    required this.sessionId,
    required this.itemId,
    required this.lexemeId,
    required this.skill,
    required this.taskType,
    required this.rating,
    required this.source,
    required this.answerRevealed,
    required this.hintUsed,
    required this.isDueReview,
    required this.activeDurationMs,
    required this.occurredAt,
    this.attemptKind = AttemptKind.initial,
  });

  bool get isSuccess =>
      rating == RecallRating.difficult ||
      rating == RecallRating.recalled ||
      rating == RecallRating.easy;

  bool get isIndependentRecall => !answerRevealed && !hintUsed;

  bool get isInSessionRetry => attemptKind == AttemptKind.inSessionRetry;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'sessionId': sessionId,
    'itemId': itemId,
    'lexemeId': lexemeId,
    'skill': skill.name,
    'taskType': taskType.name,
    'rating': rating.name,
    'source': source.name,
    'answerRevealed': answerRevealed,
    'hintUsed': hintUsed,
    'isDueReview': isDueReview,
    'activeDurationMs': activeDurationMs,
    'occurredAt': occurredAt.toIso8601String(),
    'attemptKind': attemptKind.name,
  };
}

class RecallEvaluation {
  final int quality;
  final bool countsAsLongTermReview;
  final bool countsAsExposure;
  final String reason;

  const RecallEvaluation({
    required this.quality,
    required this.countsAsLongTermReview,
    required this.countsAsExposure,
    required this.reason,
  });

  bool get isSuccess => quality >= 3;
}

/// 把用户的回忆证据转换成调度器需要的质量分。
///
/// 质量分保留现有 SRS 的 1/3/4/5 语义；新流程不会把“看答案之后答对”
/// 当成独立长期回忆。
class RecallEvaluator {
  const RecallEvaluator._();

  static RecallEvaluation evaluate(RecallEvidence evidence) {
    final quality = switch (evidence.rating) {
      RecallRating.forgot => 1,
      RecallRating.difficult => 3,
      RecallRating.recalled => 4,
      RecallRating.easy => 5,
    };

    final independent = evidence.isIndependentRecall;
    final countsAsLongTerm =
        independent &&
        !evidence.isInSessionRetry &&
        evidence.isDueReview &&
        quality >= 3;

    return RecallEvaluation(
      quality: quality,
      countsAsLongTermReview: countsAsLongTerm,
      countsAsExposure: true,
      reason: evidence.isInSessionRetry
          ? 'in_session_retry'
          : independent
          ? 'independent_recall'
          : 'assisted_recall',
    );
  }
}
