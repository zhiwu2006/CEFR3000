import '../../../data/progress_repository.dart';
import '../../../data/review_commit_repository.dart';
import '../../../data/exposure_repository.dart';
import '../../../data/learning_item_state_repository.dart';
import '../../../domain/srs.dart';
import '../../../models/attempt.dart';
import '../../../models/card_state.dart';
import '../../../models/exposure_event.dart';
import '../../../models/review_event.dart';
import '../domain/memory_scheduler.dart';
import '../domain/fsrs_scheduler.dart';
import '../domain/learning_item_state.dart';
import '../domain/recall_models.dart';

class RecallCommitReceipt {
  final String eventId;
  final CardState state;
  final bool alreadyCommitted;
  final bool firstExposureToday;

  const RecallCommitReceipt({
    required this.eventId,
    required this.state,
    required this.alreadyCommitted,
    required this.firstExposureToday,
  });
}

/// 把一次回答变成不可重复、可恢复的学习事实。
class RecallCommitService {
  final ProgressRepository progressRepository;
  final ReviewCommitRepository? reliableRepository;
  final TransactionalRecallRepository? transactionalRepository;
  final ExposureRepository? exposureRepository;
  final LearningItemStateRepository? itemStateRepository;
  final MemoryScheduler scheduler;
  final FsrsScheduler shadowScheduler;

  RecallCommitService({
    required this.progressRepository,
    SrsConfig config = const SrsConfig(),
  }) : reliableRepository = progressRepository is ReviewCommitRepository
           ? progressRepository as ReviewCommitRepository
           : null,
       transactionalRepository =
           progressRepository is TransactionalRecallRepository
           ? progressRepository as TransactionalRecallRepository
           : null,
       exposureRepository = progressRepository is ExposureRepository
           ? progressRepository as ExposureRepository
           : null,
       itemStateRepository = progressRepository is LearningItemStateRepository
           ? progressRepository as LearningItemStateRepository
           : null,
       scheduler = MemoryScheduler(config: config),
       shadowScheduler = const FsrsScheduler();

  bool get supportsReliableCommit => reliableRepository != null;

  Future<RecallCommitReceipt> commitAttempt({
    required String sessionId,
    required Attempt attempt,
    required int timeLimitMs,
    required double slowThreshold,
    bool? isDueReview,
    bool answerRevealed = false,
    bool hintUsed = false,
    ReviewTaskType taskType = ReviewTaskType.recognition,
    LearningSkill skill = LearningSkill.meaningRecognition,
    EvaluationSource source = EvaluationSource.objective,
    RecallRating? ratingOverride,
    String contentVersion = 'legacy-v1',
  }) async {
    final eventId = ReviewEvent.idFor(sessionId: sessionId, attempt: attempt);
    final existing = await reliableRepository?.getReviewEvent(eventId);
    if (existing != null && existing.isCommitted) {
      final committedState =
          existing.resultingItemState?.toCardState(attempt.wordId) ??
          existing.resultingState;
      return RecallCommitReceipt(
        eventId: eventId,
        state: committedState,
        alreadyCommitted: true,
        firstExposureToday: false,
      );
    }

    final existingState = await progressRepository.getCardState(attempt.wordId);
    final itemId = _learningItemId(attempt.wordId, skill);
    final lexemeId = 'legacy:${attempt.wordId}';
    final isSkillSpecific =
        skill != LearningSkill.meaningRecognition &&
        itemStateRepository != null;
    final existingItemState = isSkillSpecific
        ? await itemStateRepository!.getLearningItemState(itemId)
        : null;
    final current = isSkillSpecific
        ? (existingItemState?.toCardState(attempt.wordId) ??
              CardState.newCard(attempt.wordId, now: attempt.timestamp))
        : (existingState ??
              CardState.newCard(attempt.wordId, now: attempt.timestamp));
    final recognitionState =
        existingState ??
        CardState.newCard(attempt.wordId, now: attempt.timestamp);
    final evidence = evidenceFromAttempt(
      sessionId: sessionId,
      eventId: eventId,
      attempt: attempt,
      timeLimitMs: timeLimitMs,
      slowThreshold: slowThreshold,
      baselineRtMs: current.rtP50 > 0 ? current.rtP50 : null,
      // 到期按自然日判断，与首页「今日到期」和计划器口径一致：
      // 昨天 21:00 学的词今天 07:00 复习也算到期复习。
      isDueReview: isDueReview ?? isDueOn(current.due, attempt.timestamp),
      answerRevealed: answerRevealed,
      hintUsed: hintUsed,
      taskType: taskType,
      skill: skill,
      source: source,
      ratingOverride: ratingOverride,
    );
    final next = scheduler.schedule(
      current,
      evidence,
      reviewedAt: attempt.timestamp,
    );
    final shadow = shadowScheduler.schedule(
      current,
      evidence,
      reviewedAt: attempt.timestamp,
    );
    final resultingItemState = isSkillSpecific
        ? LearningItemState.fromCardState(
            state: next,
            itemId: itemId,
            lexemeId: lexemeId,
            skill: skill,
            evidenceOrigin: source.name,
          )
        : null;

    if (reliableRepository == null) {
      if (resultingItemState != null) {
        await itemStateRepository!.saveLearningItemState(resultingItemState);
      } else {
        await progressRepository.saveCardState(next);
      }
      final firstExposureToday = existingState == null
          ? await _recordExposure(
              sessionId: sessionId,
              wordId: attempt.wordId,
              occurredAt: attempt.timestamp,
            )
          : false;
      return RecallCommitReceipt(
        eventId: eventId,
        state: isSkillSpecific ? next : next,
        alreadyCommitted: false,
        firstExposureToday: firstExposureToday,
      );
    }

    final event = ReviewEvent(
      id: eventId,
      sessionId: sessionId,
      attempt: attempt,
      // 能力项使用自己的 revision；识别项沿用兼容 CardState revision。
      beforeRevision: current.revision,
      resultingState: isSkillSpecific ? recognitionState : next,
      status: 'pending',
      evaluationSource: evidence.source.name,
      taskType: evidence.taskType.name,
      createdAt: attempt.timestamp,
      isDueReview: evidence.isDueReview,
      independentRecall:
          evidence.isIndependentRecall && !evidence.isInSessionRetry,
      rating: evidence.rating.name,
      answerRevealed: evidence.answerRevealed,
      hintUsed: evidence.hintUsed,
      activeDurationMs: evidence.activeDurationMs,
      skill: evidence.skill.name,
      schedulerVersion: MemoryScheduler.version,
      contentVersion: contentVersion,
      timeLimitMs: timeLimitMs,
      localDate: _localDate(attempt.timestamp),
      shadowSchedulerVersion: shadow.schedulerVersion,
      shadowDueAt: shadow.state.due,
      shadowStability: shadow.state.stability,
      shadowDifficulty: shadow.state.difficulty,
      shadowRetrievability: shadow.retrievability,
      learningItemId: isSkillSpecific ? itemId : null,
      resultingItemState: resultingItemState,
    );
    final transactional = transactionalRepository;
    if (transactional != null) {
      final transactionalResult = await transactional.commitRecall(
        event: event,
        firstExposure: existingState == null
            ? ExposureEvent(
                id: ExposureEvent.idFor(
                  sessionId: sessionId,
                  wordId: attempt.wordId,
                  localDate: _localDate(attempt.timestamp),
                ),
                sessionId: sessionId,
                wordId: attempt.wordId,
                occurredAt: attempt.timestamp,
                localDate: _localDate(attempt.timestamp),
              )
            : null,
      );
      return RecallCommitReceipt(
        eventId: eventId,
        state: isSkillSpecific ? next : transactionalResult.state,
        alreadyCommitted: transactionalResult.alreadyCommitted,
        firstExposureToday: transactionalResult.firstExposureToday,
      );
    }

    final result = await reliableRepository!.commitReview(event);
    final firstExposureToday = existingState == null
        ? await _recordExposure(
            sessionId: sessionId,
            wordId: attempt.wordId,
            occurredAt: attempt.timestamp,
          )
        : false;
    return RecallCommitReceipt(
      eventId: eventId,
      state: isSkillSpecific ? next : result.state,
      alreadyCommitted: result.alreadyCommitted,
      firstExposureToday: firstExposureToday,
    );
  }

  /// [due] 所在自然日不晚于 [at] 所在自然日即视为到期。
  static bool isDueOn(DateTime due, DateTime at) => !DateTime(
    due.year,
    due.month,
    due.day,
  ).isAfter(DateTime(at.year, at.month, at.day));

  String _learningItemId(int wordId, LearningSkill skill) =>
      'legacy:$wordId:sense:primary:${_skillSlug(skill)}';

  String _skillSlug(LearningSkill skill) => switch (skill) {
    LearningSkill.meaningRecognition => 'meaning-recognition',
    LearningSkill.meaningRecall => 'meaning-recall',
    LearningSkill.englishProduction => 'english-production',
    LearningSkill.listening => 'listening',
    LearningSkill.spelling => 'spelling',
  };

  Future<bool> _recordExposure({
    required String sessionId,
    required int wordId,
    required DateTime occurredAt,
  }) async {
    final repository = exposureRepository;
    if (repository == null) return true;
    try {
      final localDate = _localDate(occurredAt);
      final alreadyOnDate = await repository.hasExposureForDate(
        wordId: wordId,
        localDate: localDate,
      );
      if (alreadyOnDate) return false;
      final inserted = await repository.recordExposure(
        ExposureEvent(
          id: ExposureEvent.idFor(
            sessionId: sessionId,
            wordId: wordId,
            localDate: localDate,
          ),
          sessionId: sessionId,
          wordId: wordId,
          occurredAt: occurredAt,
          localDate: localDate,
        ),
      );
      return !alreadyOnDate && inserted;
    } catch (_) {
      // 回忆事实已经成功提交时，接触日志失败不能让用户重复答题；
      // 下一次进入学习时仍可根据卡片状态继续，不伪造额度扣减。
      return false;
    }
  }

  String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// 把一次作答转换成调度证据（纯函数，测试与离线重放复用同一套规则）。
  static RecallEvidence evidenceFromAttempt({
    required String sessionId,
    required String eventId,
    required Attempt attempt,
    required int timeLimitMs,
    required double slowThreshold,
    required int? baselineRtMs,
    required bool isDueReview,
    required bool answerRevealed,
    required bool hintUsed,
    required ReviewTaskType taskType,
    required LearningSkill skill,
    required EvaluationSource source,
    required RecallRating? ratingOverride,
  }) {
    final quality = SrsAlgorithm.calculateQuality(
      result: attempt.result,
      reactionTime: attempt.rtMs,
      timeLimit: timeLimitMs,
      baselineRtMs: baselineRtMs,
      slowThresholdMultiplier: slowThreshold,
    );
    final rating =
        ratingOverride ??
        (attempt.isInSessionRetry || attempt.usedHint
            ? (attempt.result == AttemptResult.correct
                  ? RecallRating.difficult
                  : RecallRating.forgot)
            : switch (quality) {
                1 => RecallRating.forgot,
                3 => RecallRating.difficult,
                4 => RecallRating.recalled,
                // 四选一有 25% 蒙对概率，快速选对不足以证明“轻松回忆”；
                // easy 留给需要自己写出/说出答案的题型。
                _ =>
                  taskType == ReviewTaskType.recognition
                      ? RecallRating.recalled
                      : RecallRating.easy,
              });
    return RecallEvidence(
      eventId: eventId,
      sessionId: sessionId,
      itemId: attempt.wordId,
      lexemeId: attempt.wordId,
      skill: skill,
      taskType: taskType,
      rating: rating,
      source: source,
      answerRevealed: answerRevealed,
      hintUsed: hintUsed,
      isDueReview: isDueReview,
      activeDurationMs: attempt.rtMs,
      occurredAt: attempt.timestamp,
      attemptKind: attempt.kind,
    );
  }
}
