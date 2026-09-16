import '../features/memory/domain/learning_item_state.dart';

/// Optional capability for skill-specific memory states.
abstract interface class LearningItemStateRepository {
  Future<LearningItemState?> getLearningItemState(String itemId);

  Future<void> saveLearningItemState(LearningItemState state);

  Future<List<LearningItemState>> getLearningItemStates({String? lexemeId});
}
