import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vocab_flash_test/data/hive_progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/models/models.dart';

class _Words implements WordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('review commit is idempotent and recoverable', () async {
    final directory = await Directory.systemTemp.createTemp('vocab-review-');
    Hive.init(directory.path);
    final repository = HiveProgressRepository(_Words());
    await repository.init();

    final at = DateTime(2026, 9, 11, 10);
    final attempt = Attempt(
      wordId: 42,
      result: AttemptResult.correct,
      rtMs: 500,
      chosenIndex: 0,
      correctIndex: 0,
      timestamp: at,
    );
    final before = CardState.newCard(42);
    final after = SrsAlgorithm.updateCardState(
      before,
      4,
      reviewedAt: at,
      shortTermReview: true,
    );
    final event = ReviewEvent(
      id: 'session-42-event-1',
      sessionId: 'session-42',
      attempt: attempt,
      beforeRevision: before.revision,
      resultingState: after,
      status: 'pending',
      evaluationSource: 'objective',
      taskType: 'recognition',
      createdAt: at,
    );

    final first = await repository.commitReview(event);
    final second = await repository.commitReview(event);
    expect(first.alreadyCommitted, isFalse);
    expect(second.alreadyCommitted, isTrue);
    expect((await repository.getCardState(42))!.revision, after.revision);
    expect((await repository.getReviewEvents()).length, 1);

    final exposureInserted = await repository.recordExposure(
      ExposureEvent(
        id: ExposureEvent.idFor(sessionId: 'session-42', wordId: 42),
        sessionId: 'session-42',
        wordId: 42,
        occurredAt: at,
        localDate: '2026-09-11',
      ),
    );
    expect(exposureInserted, isTrue);
    expect(
      await repository.hasExposureForDate(wordId: 42, localDate: '2026-09-11'),
      isTrue,
    );
    expect((await repository.getExposureEvents()).length, 1);

    await repository.dispose();
    await directory.delete(recursive: true);
  });

  test('recall commit records one first exposure per local day', () async {
    final directory = await Directory.systemTemp.createTemp('vocab-exposure-');
    Hive.init(directory.path);
    final repository = HiveProgressRepository(_Words());
    await repository.init();

    final attempt = Attempt(
      wordId: 7,
      result: AttemptResult.correct,
      rtMs: 400,
      chosenIndex: 0,
      correctIndex: 0,
      timestamp: DateTime(2026, 9, 11, 8),
    );
    final service = RecallCommitService(progressRepository: repository);
    final first = await service.commitAttempt(
      sessionId: 's1',
      attempt: attempt,
      timeLimitMs: 2000,
      slowThreshold: 1.5,
    );
    final duplicate = await service.commitAttempt(
      sessionId: 's1',
      attempt: attempt,
      timeLimitMs: 2000,
      slowThreshold: 1.5,
    );

    expect(first.firstExposureToday, isTrue);
    expect(duplicate.firstExposureToday, isFalse);
    expect((await repository.getExposureEvents()).length, 1);

    await repository.dispose();
    final reopened = HiveProgressRepository(_Words());
    await reopened.init();
    final persisted = (await reopened.getReviewEvents()).single;
    // 四选一快速选对封顶为 recalled，easy 留给产出类题型。
    expect(persisted.rating, 'recalled');
    expect(persisted.timeLimitMs, 2000);
    expect(persisted.localDate, '2026-09-11');
    expect((await reopened.getExposureEvents()).length, 1);
    await reopened.dispose();
    await directory.delete(recursive: true);
  });
}
