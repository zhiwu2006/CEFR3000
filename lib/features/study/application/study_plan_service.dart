import '../../../data/progress_repository.dart';
import '../../../data/exposure_repository.dart';
import '../../../data/learning_item_state_repository.dart';
import '../../../data/word_preference_repository.dart';
import '../../../core/clock.dart';
import '../../../data/word_repository.dart';
import '../../../domain/srs.dart';
import '../../../models/test_run.dart';
import '../../lexicon/domain/content_eligibility.dart';
import '../../memory/domain/learning_item_state.dart';
import '../../memory/domain/recall_models.dart';
import '../domain/study_plan.dart';

class StudyPlanService {
  final WordRepository wordRepository;
  final ProgressRepository progressRepository;
  final StudyPlanner planner;
  final Clock clock;
  final WordPreferenceRepository? preferenceRepository;

  const StudyPlanService({
    required this.wordRepository,
    required this.progressRepository,
    this.planner = const StudyPlanner(),
    this.clock = const SystemClock(),
    this.preferenceRepository,
  });

  Future<StudyPlan> buildTodayPlan({
    required Set<String> levels,
    required int maxItems,
    required int maxMinutes,
    required int dailyNewLimit,
    required int dailyNewUsed,
    LeechPolicy leechPolicy = LeechPolicy.defaultPolicy,
    bool onlyLeeches = false,
    LearningSkill skill = LearningSkill.meaningRecognition,
    bool allowLegacyFallback = false,
    Map<int, double> recallEstimates = const {},
  }) async {
    final words = await wordRepository.loadByLevels(levels);
    final suspendedLexemes = <String>{};
    final preferenceStore =
        preferenceRepository ??
        (progressRepository is WordPreferenceRepository
            ? progressRepository as WordPreferenceRepository
            : null);
    if (preferenceStore != null) {
      final preferences = await preferenceStore.getWordPreferences();
      suspendedLexemes.addAll(
        preferences
            .where((preference) => preference.suspended)
            .map((preference) => preference.lexemeId),
      );
    }
    final states = await progressRepository.getCardStates(
      words.map((word) => word.id).toList(),
    );
    final stateMap = {for (final state in states) state.wordId: state};
    // A migrated legacy CardState is also durable evidence that the lexeme
    // has already been introduced, even when the old store had no exposure
    // log to import. This keeps a newly enabled ability from consuming the
    // daily *new lexeme* budget for an already learned word.
    final recognizedWordIds = stateMap.keys.toSet();
    final itemRepository = progressRepository is LearningItemStateRepository
        ? progressRepository as LearningItemStateRepository
        : null;
    final itemStates = <String, LearningItemState>{};
    if (itemRepository != null && skill != LearningSkill.meaningRecognition) {
      // 一次性取回全部条目状态再按 itemId 过滤，避免 N+1：loadByLevels 可能
      // 返回数千个词，逐词 await 一次查询会把计划构建拖到秒级，在低端
      // Android 设备上尤其明显。
      final wantedItemIds = <String>{
        for (final word in words) _learningItemId(word.id, skill),
      };
      final loaded = await itemRepository.getLearningItemStates();
      for (final state in loaded) {
        if (wantedItemIds.contains(state.itemId)) {
          itemStates[state.itemId] = state;
        }
      }
    }
    final now = clock.now;
    final exposureRepository = progressRepository is ExposureRepository
        ? progressRepository as ExposureRepository
        : null;
    final exposureEvents = exposureRepository == null
        ? const []
        : await exposureRepository.getExposureEvents();
    final exposedWordIds = exposureEvents.map((event) => event.wordId).toSet();
    // Exposure is the durable source of truth for the new-word quota. The
    // legacy settings counter is kept for compatibility, but a crash between
    // the recall transaction and its UI preference write must not reopen the
    // same day's budget.
    final today = _localDate(now);
    final durableDailyNewUsed = exposureEvents
        .where((event) => event.localDate == today)
        .map((event) => event.wordId)
        .toSet()
        .length;
    final effectiveDailyNewUsed = dailyNewUsed > durableDailyNewUsed
        ? dailyNewUsed
        : durableDailyNewUsed;
    final pendingConsolidation = skill == LearningSkill.meaningRecognition
        ? TestRun.pendingConsolidation(
            await progressRepository.getTestRunHistory(
              limit: TestRun.pendingConsolidationLookbackRuns,
            ),
          )
        : <int>{};
    final candidates = <StudyCandidate>[];
    for (final word in words) {
      if (suspendedLexemes.contains(word.stableId)) continue;
      if (skill == LearningSkill.meaningRecognition) {
        final state = stateMap[word.id];
        final hasPriorExposure =
            exposedWordIds.contains(word.id) ||
            recognizedWordIds.contains(word.id);
        final isLeech = state != null && leechPolicy.isLeech(state);
        candidates.add(
          StudyCandidate(
            wordId: word.id,
            lexemeId: word.stableId,
            skill: skill,
            taskType: ReviewTaskType.recognition,
            needsConsolidation: pendingConsolidation.contains(word.id),
            recallProbability: recallEstimates[word.id],
            dueAt: state?.due,
            // 接触过但尚未提交卡片状态的词仍属于学习中，避免计划重复
            // 把它当成全新词并再次占用今日新词额度。
            isNew: state == null && !hasPriorExposure,
            isLeech: isLeech,
            isRelearning:
                state != null && state.lapses > 0 && state.stability < 2,
            // 闪测限时 2 秒 + 反馈 800ms，单题预估耗时按 3~4 秒计算，避免误触发时间预算截断
            estimatedSeconds: state == null ? 4 : 3,
          ),
        );
        continue;
      }

      // A skill-specific plan is independently due and independently new.
      // Content qualification happens before the item can consume plan budget.
      final eligibility = switch (skill) {
        LearningSkill.englishProduction => ContentEligibility.productionForWord(
          word,
          allowLegacyFallback: allowLegacyFallback,
        ),
        LearningSkill.listening => const ContentTaskEligibility(
          skill: LearningSkill.listening,
          enabled: false,
          confidence: null,
          reason: ContentEligibilityReason.missingContext,
          prompt: '',
        ),
        LearningSkill.spelling => const ContentTaskEligibility(
          skill: LearningSkill.spelling,
          enabled: false,
          confidence: null,
          reason: ContentEligibilityReason.missingContext,
          prompt: '',
        ),
        _ => null,
      };
      if (eligibility != null && !eligibility.enabled) continue;
      final itemId = _learningItemId(word.id, skill);
      final state = itemStates[itemId];
      final hasPriorExposure =
          exposedWordIds.contains(word.id) ||
          recognizedWordIds.contains(word.id);
      final compatibilityState = state?.toCardState(word.id);
      final isLeech =
          compatibilityState != null && leechPolicy.isLeech(compatibilityState);
      candidates.add(
        StudyCandidate(
          wordId: word.id,
          learningItemId: itemId,
          lexemeId: word.stableId,
          skill: skill,
          taskType: _taskTypeFor(skill),
          contentVersion: eligibility?.requiresSelfCheck == true
              ? 'legacy-fallback-v1'
              : 'reviewed-v1',
          dueAt: state?.dueAt,
          isNew: state == null && !hasPriorExposure,
          isLeech: isLeech,
          isRelearning:
              state != null && state.lapses > 0 && state.stability < 2,
          estimatedSeconds: state == null ? 40 : 25,
        ),
      );
    }

    // 没有 card state 的词是新词；未来可从 ExposureEvent 替换这一判断。
    // 此处只负责计划，不写状态、不消耗额度。
    return planner.build(
      candidates,
      StudyPolicy(
        maxItems: maxItems,
        maxMinutes: maxMinutes,
        dailyNewLimit: dailyNewLimit,
        dailyNewUsed: effectiveDailyNewUsed,
        onlyLeeches: onlyLeeches,
      ),
      now: now,
    );
  }

  String _learningItemId(int wordId, LearningSkill skill) =>
      'legacy:$wordId:sense:primary:${_skillSlug(skill)}';

  String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _skillSlug(LearningSkill skill) => switch (skill) {
    LearningSkill.meaningRecognition => 'meaning-recognition',
    LearningSkill.meaningRecall => 'meaning-recall',
    LearningSkill.englishProduction => 'english-production',
    LearningSkill.listening => 'listening',
    LearningSkill.spelling => 'spelling',
  };

  ReviewTaskType _taskTypeFor(LearningSkill skill) => switch (skill) {
    LearningSkill.meaningRecognition => ReviewTaskType.recognition,
    LearningSkill.meaningRecall => ReviewTaskType.recall,
    LearningSkill.englishProduction => ReviewTaskType.production,
    LearningSkill.listening => ReviewTaskType.listening,
    LearningSkill.spelling => ReviewTaskType.spelling,
  };
}
