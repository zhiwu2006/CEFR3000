import 'word.dart';
import 'card_state.dart';

/// 单词学习状态聚合
class WordStudyStatus {
  final Word word;
  final CardState? state;
  final int attemptCount;

  WordStudyStatus({
    required this.word,
    required this.state,
    required this.attemptCount,
  });

  bool get isLearned => state != null;
  bool get isMastered => state != null && state!.stability > 16;
  DateTime? get lastReview => state?.lastReview;
}
