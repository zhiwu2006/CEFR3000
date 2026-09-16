import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:vocab_flash_test/data/sqlite/sqlite_progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/features/memory/application/recall_commit_service.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/models/attempt.dart';
import 'package:vocab_flash_test/models/word.dart';

class _FakeWordRepository implements WordRepository {
  final words = const [
    Word(
      id: 1,
      headword: 'abandon',
      lemma: 'abandon',
      level: 'A1',
      pos: 'verb',
      cnDefs: ['放弃'],
    ),
  ];

  @override
  Future<List<Word>> loadAll() async => words;

  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async =>
      words.where((word) => levels.contains(word.level)).toList();

  @override
  Future<Word?> getById(int id) async => words.where((word) => word.id == id).firstOrNull;

  @override
  Future<List<Word>> getByIds(List<int> ids) async =>
      words.where((word) => ids.contains(word.id)).toList();

  @override
  Future<List<Word>> getByLevelAndPos(String level, String pos) async =>
      words.where((word) => word.level == level && word.pos == pos).toList();

  @override
  Future<List<Word>> getSameLevelSamePos(
    String level,
    String pos, {
    int? excludeId,
  }) async => words
      .where(
        (word) =>
            word.level == level && word.pos == pos && word.id != excludeId,
      )
      .toList();

  @override
  Future<List<Word>> search(String query) async => words
      .where((word) => word.headword.contains(query))
      .toList();

  @override
  Future<Map<String, int>> getStatistics() async => {'A1': words.length};

  @override
  Future<void> forceReload() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLite commit is atomic, idempotent, and skill isolated', (
    tester,
  ) async {
    final root = await getDatabasesPath();
    final path = '$root/vocab_learning_core_integration.sqlite';
    await deleteDatabase(path);

    final repository = SqliteProgressRepository(
      _FakeWordRepository(),
      databasePath: path,
    );
    await repository.init();
    await repository.indexLegacyLexicon((_FakeWordRepository()).words);
    final service = RecallCommitService(progressRepository: repository);

    final firstAttempt = Attempt(
      wordId: 1,
      result: AttemptResult.correct,
      rtMs: 700,
      chosenIndex: 0,
      correctIndex: 0,
      timestamp: DateTime(2026, 9, 11, 9),
    );
    final first = await service.commitAttempt(
      sessionId: 'sqlite-session',
      attempt: firstAttempt,
      timeLimitMs: 5000,
      slowThreshold: 1.5,
      isDueReview: true,
    );
    expect(first.alreadyCommitted, isFalse);
    expect((await repository.getReviewEvents()).length, 1);
    expect((await repository.getExposureEvents()).length, 1);
    final recognition = await repository.getCardState(1);
    expect(recognition, isNotNull);

    final duplicate = await service.commitAttempt(
      sessionId: 'sqlite-session',
      attempt: firstAttempt,
      timeLimitMs: 5000,
      slowThreshold: 1.5,
      isDueReview: true,
    );
    expect(duplicate.alreadyCommitted, isTrue);
    expect((await repository.getReviewEvents()).length, 1);
    expect((await repository.getExposureEvents()).length, 1);

    final productionAttempt = Attempt(
      wordId: 1,
      result: AttemptResult.correct,
      rtMs: 900,
      chosenIndex: 0,
      correctIndex: 0,
      timestamp: DateTime(2026, 9, 12, 9),
    );
    await service.commitAttempt(
      sessionId: 'production-session',
      attempt: productionAttempt,
      timeLimitMs: 5000,
      slowThreshold: 1.5,
      isDueReview: true,
      taskType: ReviewTaskType.production,
      skill: LearningSkill.englishProduction,
      source: EvaluationSource.objective,
      contentVersion: 'legacy-fallback-v1',
    );
    expect(await repository.getLearningItemState(
      'legacy:1:sense:primary:english-production',
    ), isNotNull);
    expect((await repository.getCardState(1))!.revision, recognition!.revision);
    expect((await repository.getReviewEvents()).length, 2);

    await repository.close();
    final reopened = SqliteProgressRepository(
      _FakeWordRepository(),
      databasePath: path,
    );
    await reopened.init();
    expect(await reopened.getCardState(1), isNotNull);
    expect(await reopened.getLearningItemState(
      'legacy:1:sense:primary:english-production',
    ), isNotNull);

    // A malformed import must roll back the deletes and leave the existing
    // database readable.
    await expectLater(
      reopened.importProgress({'cardStates': [{}]}),
      throwsA(anything),
    );
    expect(await reopened.getCardState(1), isNotNull);
    expect((await reopened.getReviewEvents()).length, 2);

    // Clearing progress must not erase the completed migration marker; the
    // next app launch must not silently re-import the old Hive snapshot.
    await reopened.recordMigrationRun(
      id: 'migration-marker',
      sourceSchema: 3,
      sourceChecksum: 'checksum',
      startedAt: DateTime(2026, 9, 11),
      finishedAt: DateTime(2026, 9, 11),
      status: 'completed',
      report: const {'sourceChecksum': 'checksum', 'status': 'completed'},
    );
    await reopened.clearAllProgress();
    expect(await reopened.hasCoreData(), isFalse);
    expect(await reopened.latestMigrationReport(), isNotNull);

    await reopened.close();
    await deleteDatabase(path);
  });
}
