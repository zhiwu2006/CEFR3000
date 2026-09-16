import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/data/hive_progress_repository.dart';
import 'package:vocab_flash_test/data/migration/legacy_progress_migrator.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/features/assistance/data/ai_explanation_cache.dart';
import 'package:vocab_flash_test/features/lexicon/domain/content_eligibility.dart';
import 'package:vocab_flash_test/features/lexicon/domain/lexicon_models.dart';
import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/features/memory/domain/fsrs_scheduler.dart';
import 'package:vocab_flash_test/features/memory/domain/leech_intervention.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/features/progress/domain/memory_analytics.dart';
import 'package:vocab_flash_test/features/study/domain/study_plan.dart';
import 'package:vocab_flash_test/data/word_preference_repository.dart';
import 'package:vocab_flash_test/models/models.dart';

class _Words implements WordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MigrationSource implements LegacyProgressSource {
  final Map<String, dynamic> snapshot;

  _MigrationSource(this.snapshot);

  @override
  Future<Map<String, dynamic>> exportProgress() async => snapshot;
}

class _MigrationTarget implements MigrationTarget {
  bool failImport;
  final reports = <Map<String, dynamic>>[];
  Map<String, dynamic>? imported;

  _MigrationTarget({this.failImport = false});

  @override
  Future<bool> hasCoreData() async => false;

  @override
  Future<Map<String, dynamic>?> latestMigrationReport() async =>
      reports.isEmpty ? null : reports.last;

  @override
  Future<void> recordMigrationRun({
    required String id,
    required int sourceSchema,
    required String sourceChecksum,
    required DateTime startedAt,
    DateTime? finishedAt,
    required String status,
    required Map<String, dynamic> report,
  }) async {
    reports.add(report);
  }

  @override
  Future<void> importProgress(Map<String, dynamic> data) async {
    if (failImport) throw StateError('injected import failure');
    imported = data;
  }
}

Attempt _attempt(int wordId, DateTime timestamp, {bool correct = true}) =>
    Attempt(
      wordId: wordId,
      result: correct ? AttemptResult.correct : AttemptResult.wrong,
      rtMs: 700,
      chosenIndex: correct ? 0 : -1,
      correctIndex: 0,
      timestamp: timestamp,
    );

ReviewEvent _event(
  String id,
  int wordId,
  DateTime timestamp, {
  bool correct = true,
  bool due = true,
}) {
  final attempt = _attempt(wordId, timestamp, correct: correct);
  return ReviewEvent(
    id: id,
    sessionId: 'session',
    attempt: attempt,
    beforeRevision: 0,
    resultingState: CardState.newCard(wordId, now: timestamp),
    status: 'committed',
    evaluationSource: 'objective',
    taskType: 'recognition',
    createdAt: timestamp,
    isDueReview: due,
    independentRecall: true,
    rating: correct ? 'recalled' : 'forgot',
  );
}

void main() {
  test('content eligibility gates reviewed production and marks fallback', () {
    final sense = Sense(
      id: 's1',
      lexemeId: 'l1',
      partOfSpeech: 'v',
      definition: '建立',
      examples: const ['They build a bridge.'],
      qualityStatus: 'reviewed',
    );
    final verified = ContentEligibility.productionForSense(
      sense,
      headword: 'build',
      lemma: 'build',
    );
    expect(verified.enabled, isTrue);
    expect(verified.confidence, ContentConfidence.verified);
    expect(
      ContentEligibility.matches(' BUILD! ', verified.acceptedAnswers),
      isTrue,
    );

    final legacy = ContentEligibility.productionForSense(
      sense.copyWithForTest(qualityStatus: 'legacy-unreviewed'),
      headword: 'build',
      allowLegacyFallback: true,
    );
    expect(legacy.enabled, isTrue);
    expect(legacy.requiresSelfCheck, isTrue);
    expect(
      ContentEligibility.productionForSense(
        sense.copyWithForTest(qualityStatus: 'legacy-unreviewed'),
        headword: 'build',
      ).enabled,
      isFalse,
    );
  });

  test('FSRS shadow schedule is deterministic and retains metadata', () {
    final timestamp = DateTime(2026, 9, 11, 12);
    final state = CardState.newCard(1, now: timestamp);
    final evidence = RecallEvidence(
      eventId: 'e',
      sessionId: 's',
      itemId: 1,
      lexemeId: 1,
      skill: LearningSkill.meaningRecognition,
      taskType: ReviewTaskType.recognition,
      rating: RecallRating.recalled,
      source: EvaluationSource.objective,
      answerRevealed: false,
      hintUsed: false,
      isDueReview: true,
      activeDurationMs: 700,
      occurredAt: timestamp,
    );
    final result = const FsrsScheduler().schedule(
      state,
      evidence,
      reviewedAt: timestamp,
    );
    expect(result.schedulerVersion, FsrsScheduler.version);
    expect(result.grade, 3);
    expect(result.retrievability, 1.0);
    expect(result.state.due.isAfter(timestamp), isTrue);
  });

  test('FSRS v4 initial grades match the reference parameter vector', () {
    final timestamp = DateTime(2026, 9, 11, 12);
    const ratings = [
      RecallRating.forgot,
      RecallRating.difficult,
      RecallRating.recalled,
      RecallRating.easy,
    ];
    const expectedStability = [0.4, 0.6, 2.4, 5.8];
    const expectedIntervals = [1, 1, 2, 6];
    for (var index = 0; index < ratings.length; index++) {
      final evidence = RecallEvidence(
        eventId: 'e$index',
        sessionId: 's',
        itemId: 1,
        lexemeId: 1,
        skill: LearningSkill.meaningRecognition,
        taskType: ReviewTaskType.recognition,
        rating: ratings[index],
        source: EvaluationSource.objective,
        answerRevealed: false,
        hintUsed: false,
        isDueReview: true,
        activeDurationMs: 700,
        occurredAt: timestamp,
      );
      final result = const FsrsScheduler().schedule(
        CardState.newCard(1, now: timestamp),
        evidence,
        reviewedAt: timestamp,
      );
      expect(result.state.stability, closeTo(expectedStability[index], 1e-9));
      expect(
        result.state.due.difference(timestamp).inDays,
        expectedIntervals[index],
      );
    }
  });

  test('study planner keeps skills independent for one lexeme', () {
    final plan = const StudyPlanner().build(
      [
        StudyCandidate(
          wordId: 1,
          learningItemId: 'legacy:1:sense:primary:meaning-recognition',
          skill: LearningSkill.meaningRecognition,
          taskType: ReviewTaskType.recognition,
          dueAt: null,
          isNew: true,
          isLeech: false,
          isRelearning: false,
        ),
        StudyCandidate(
          wordId: 1,
          learningItemId: 'legacy:1:sense:primary:english-production',
          skill: LearningSkill.englishProduction,
          taskType: ReviewTaskType.production,
          dueAt: null,
          isNew: true,
          isLeech: false,
          isRelearning: false,
        ),
      ],
      const StudyPolicy(
        maxItems: 2,
        maxMinutes: 10,
        dailyNewLimit: 2,
        dailyNewUsed: 0,
      ),
      now: DateTime(2026, 9, 11),
    );
    expect(plan.items, hasLength(2));
    expect(plan.learningItemIds, hasLength(2));
    expect(plan.itemsForSkill(LearningSkill.englishProduction), hasLength(1));
    expect(plan.newItemCount, 1);
  });

  test('word preference JSON preserves explicit suspension', () {
    final original = UserWordPreference(
      lexemeId: 'legacy:7',
      suspended: true,
      manualDifficult: true,
      updatedAt: DateTime(2026, 9, 11),
    );
    final restored = UserWordPreference.decode(original.encode());
    expect(restored.lexemeId, 'legacy:7');
    expect(restored.suspended, isTrue);
    expect(restored.manualDifficult, isTrue);
  });

  test('legacy migration checksum is stable across export timestamps and order', () {
    final first = <String, dynamic>{
      'version': 3,
      'exportTime': '2026-09-11T01:00:00Z',
      'attempts': [
        {'wordId': 2, 'result': 'wrong'},
        {'wordId': 1, 'result': 'correct'},
      ],
      'metadata': {'b': 2, 'a': 1},
    };
    final second = <String, dynamic>{
      'metadata': {'a': 1, 'b': 2},
      'attempts': [
        {'result': 'correct', 'wordId': 1},
        {'result': 'wrong', 'wordId': 2},
      ],
      'version': 3,
      'exportTime': '2026-09-12T01:00:00Z',
    };
    expect(
      LegacyProgressMigrator.checksumForSnapshot(first),
      LegacyProgressMigrator.checksumForSnapshot(second),
    );
  });

  test('legacy migration records failure and retries without changing source', () async {
    final sourceSnapshot = <String, dynamic>{
      'version': 3,
      'cardStates': const [],
      'testRuns': const [],
      'attempts': const [],
      'reviewEvents': const [],
      'exposureEvents': const [],
    };
    final source = _MigrationSource(sourceSnapshot);
    final target = _MigrationTarget(failImport: true);
    final directory = await Directory.systemTemp.createTemp('vocab-migration-');
    final migrator = LegacyProgressMigrator(backupDirectory: directory);
    await expectLater(
      migrator.migrate(source: source, target: target),
      throwsStateError,
    );
    expect(target.reports.any((report) => report['status'] == 'failed'), isTrue);
    expect(sourceSnapshot['version'], 3);

    target.failImport = false;
    final retry = await migrator.migrate(source: source, target: target);
    expect(retry.status, 'completed');
    expect(target.imported, same(sourceSnapshot));
    expect(
      LegacyProgressMigrator.checksumForSnapshot(sourceSnapshot),
      retry.sourceChecksum,
    );
    await directory.delete(recursive: true);
  });

  test(
    'skill-specific recall does not mutate recognition card state',
    () async {
      final directory = await Directory.systemTemp.createTemp('vocab-skill-');
      Hive.init(directory.path);
      final repository = HiveProgressRepository(_Words());
      await repository.init();
      final timestamp = DateTime(2026, 9, 11, 12);
      final service = RecallCommitService(progressRepository: repository);

      final receipt = await service.commitAttempt(
        sessionId: 'skill-session',
        attempt: _attempt(11, timestamp),
        timeLimitMs: 2000,
        slowThreshold: 1.5,
        taskType: ReviewTaskType.production,
        skill: LearningSkill.englishProduction,
        contentVersion: 'legacy-fallback-v1',
      );

      expect(receipt.state.revision, 1);
      expect(await repository.getCardState(11), isNull);
      final item = await repository.getLearningItemState(
        'legacy:11:sense:primary:english-production',
      );
      expect(item, isNotNull);
      expect(item!.skill, LearningSkill.englishProduction);
      expect(
        (await repository.getReviewEvents()).single.contentVersion,
        'legacy-fallback-v1',
      );

      await repository.dispose();
      final reopened = HiveProgressRepository(_Words());
      await reopened.init();
      final persisted = (await reopened.getReviewEvents()).single;
      expect(
        persisted.resultingItemState?.skill,
        LearningSkill.englishProduction,
      );
      expect(await reopened.getCardState(11), isNull);
      await reopened.dispose();
      await directory.delete(recursive: true);
    },
  );

  test('analytics leaves missing 7/30 day observations unknown', () {
    final start = DateTime(2026, 9, 1, 9);
    final events = [
      _event('e1', 1, start),
      _event('e2', 1, start.add(const Duration(days: 7))),
      _event('e3', 2, start.add(const Duration(days: 30)), correct: false),
    ];
    final summary = MemoryAnalytics.summarize(events);
    final seven = summary['observation7d'] as Map<String, dynamic>;
    final thirty = summary['observation30d'] as Map<String, dynamic>;
    expect(seven['eligibleCount'], 1);
    expect(seven['successCount'], 1);
    expect(thirty['eligibleCount'], 0);
    expect(thirty['successRate'], isNull);
  });

  test(
    'AI cache evicts least recently used entries within the bound',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = AiExplanationCache(
        preferences,
        maxEntries: 1,
        maxBytes: 100000,
      );
      await cache.put(
        key: 'first',
        payload: 'one',
        contentVersion: 'v1',
        templateVersion: 't1',
        provider: 'test',
        model: 'model',
      );
      expect(cache.get('first'), 'one');
      await cache.put(
        key: 'second',
        payload: 'two',
        contentVersion: 'v1',
        templateVersion: 't1',
        provider: 'test',
        model: 'model',
      );
      expect(cache.get('first'), isNull);
      expect(cache.get('second'), 'two');
    },
  );

  test('leech intervention escalates after repeated lapses', () {
    final state = CardState.newCard(5).copyWith(lapses: 8);
    final plan = const LeechInterventionPolicy().plan(state);
    expect(plan.shouldPauseCard, isTrue);
    expect(plan.availableActions, contains(LeechInterventionAction.suspend));
  });
}

extension on Sense {
  Sense copyWithForTest({String? qualityStatus}) => Sense(
    id: id,
    lexemeId: lexemeId,
    partOfSpeech: partOfSpeech,
    definition: definition,
    examples: examples,
    source: source,
    qualityStatus: qualityStatus ?? this.qualityStatus,
  );
}
