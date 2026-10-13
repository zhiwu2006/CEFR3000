import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vocab_flash_test/data/hive_progress_repository.dart';
import 'package:vocab_flash_test/models/exposure_event.dart';
import 'package:vocab_flash_test/data/word_preference_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/features/study/application/study_plan_service.dart';
import 'package:vocab_flash_test/features/memory/domain/recall_models.dart';
import 'package:vocab_flash_test/models/word.dart';
import 'package:vocab_flash_test/models/test_run.dart';
import 'package:vocab_flash_test/models/card_state.dart';

class _Words implements WordRepository {
  final values = const [
    Word(
      id: 7,
      headword: 'abandon',
      lemma: 'abandon',
      level: 'A1',
      pos: 'verb',
      cnDefs: ['放弃'],
    ),
    Word(
      id: 8,
      headword: 'accept',
      lemma: 'accept',
      level: 'A1',
      pos: 'verb',
      cnDefs: ['接受'],
    ),
  ];

  @override
  Future<List<Word>> loadAll() async => values;

  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async =>
      values.where((word) => levels.contains(word.level)).toList();

  @override
  Future<Word?> getById(int id) async =>
      values.where((word) => word.id == id).firstOrNull;

  @override
  Future<List<Word>> getByIds(List<int> ids) async =>
      values.where((word) => ids.contains(word.id)).toList();

  @override
  Future<List<Word>> getByLevelAndPos(String level, String pos) async =>
      values.where((word) => word.level == level && word.pos == pos).toList();

  @override
  Future<List<Word>> getSameLevelSamePos(
    String level,
    String pos, {
    int? excludeId,
  }) async => [];

  @override
  Future<List<Word>> search(String query) async => [];

  @override
  Future<Map<String, int>> getStatistics() async => {'A1': values.length};

  @override
  Future<void> forceReload() async {}
}

void main() {
  test('study plan excludes and restores suspended lexemes', () async {
    final directory = await Directory.systemTemp.createTemp('vocab-plan-');
    Hive.init(directory.path);
    final words = _Words();
    final repository = HiveProgressRepository(words);
    await repository.init();
    final service = StudyPlanService(
      wordRepository: words,
      progressRepository: repository,
    );

    await repository.saveWordPreference(
      UserWordPreference(
        lexemeId: 'legacy:7',
        suspended: true,
        updatedAt: DateTime(2026, 9, 11),
      ),
    );
    await repository.saveWordPreference(
      UserWordPreference(
        lexemeId: 'legacy:8',
        suspended: true,
        updatedAt: DateTime(2026, 9, 11),
      ),
    );
    final suspendedPlan = await service.buildTodayPlan(
      levels: {'A1'},
      maxItems: 10,
      maxMinutes: 10,
      dailyNewLimit: 10,
      dailyNewUsed: 0,
    );
    expect(suspendedPlan.items, isEmpty);

    await repository.clearWordPreference('legacy:7');
    await repository.clearWordPreference('legacy:8');
    final activePlan = await service.buildTodayPlan(
      levels: {'A1'},
      maxItems: 10,
      maxMinutes: 10,
      dailyNewLimit: 10,
      dailyNewUsed: 0,
    );
    expect(activePlan.wordIds, contains(7));

    // The durable exposure log remains authoritative if the preference
    // counter was not flushed after a crash. With a one-word daily budget,
    // the second lexeme must not be selected as another new word.
    final todayStr =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    await repository.recordExposure(
      ExposureEvent(
        id: 'exposure:7:$todayStr',
        sessionId: 'quota-test',
        wordId: 7,
        occurredAt: DateTime.now(),
        localDate: todayStr,
      ),
    );
    final quotaPlan = await service.buildTodayPlan(
      levels: {'A1'},
      maxItems: 10,
      maxMinutes: 10,
      dailyNewLimit: 1,
      dailyNewUsed: 0,
      skill: LearningSkill.meaningRecognition,
    );
    expect(quotaPlan.newItemCount, 0);
    expect(quotaPlan.wordIds, contains(7));
    expect(quotaPlan.wordIds, isNot(contains(8)));
    await repository.saveCardState(CardState.newCard(8));
    await repository.saveTestRun(TestRun.create(
      id: 'pending', size: 1, levels: {'A1'}, timeLimitMs: 2000,
      orderPolicy: 'by_level', onlyLeeches: false,
    ).finish().copyWith(unresolvedWordIds: [8]));
    // Hive close/reopen verifies the new persisted field, not just an in-memory map.
    await repository.dispose();
    await repository.init();
    final nextPlan = await service.buildTodayPlan(
      levels: {'A1'}, maxItems: 1, maxMinutes: 10,
      dailyNewLimit: 1, dailyNewUsed: 1,
    );
    expect(nextPlan.wordIds, {8});
    await repository.saveWordPreference(UserWordPreference(
      lexemeId: 'legacy:8', suspended: true, updatedAt: DateTime.now(),
    ));
    final filteredPlan = await service.buildTodayPlan(
      levels: {'A1'}, maxItems: 1, maxMinutes: 10,
      dailyNewLimit: 1, dailyNewUsed: 1,
    );
    expect(filteredPlan.wordIds, isNot(contains(8)));
    await repository.dispose();
    await directory.delete(recursive: true);
  });
}
