import 'dart:math';

import '../models/models.dart';
import '../data/repositories.dart';
import 'session_models.dart';

class WordSelectionService {
  final ProgressRepository _progressRepository;
  final int Function() _getDailyNewRemaining;
  final Future<void> Function(int) _consumeDailyNew;

  WordSelectionService({
    required ProgressRepository progressRepository,
    required int Function() getDailyNewRemaining,
    required Future<void> Function(int) consumeDailyNew,
  })  : _progressRepository = progressRepository,
        _getDailyNewRemaining = getDailyNewRemaining,
        _consumeDailyNew = consumeDailyNew;

  Future<List<Word>> buildWordListForNewSession({
    required SessionConfig config,
    required List<Word> candidatePool,
    required Set<int> recentWordIds,
    required Set<int> hardWordIds,
  }) async {
    final target = config.wordsPerSession;
    final seen = <int>{};
    final result = <Word>[];

    final desiredNewQuota = (target * config.newCardRatio).round().clamp(0, target);
    final dailyRemaining = _getDailyNewRemaining();
    final newQuota = min(desiredNewQuota, dailyRemaining);
    final reviewTarget = max(0, target - newQuota);
    final dueQuota = reviewTarget == 0 ? 0 : max(1, (reviewTarget * 0.67).round());
    final hardQuota = reviewTarget == 0 ? 0 : max(0, reviewTarget - dueQuota);
    int newWordsPicked = 0;

    List<Word> takeWords(List<Word> source, int quota) {
      final picked = <Word>[];
      for (final w in source) {
        if (picked.length >= quota || result.length >= target) break;
        if (seen.add(w.id)) {
          picked.add(w);
          result.add(w);
        }
      }
      return picked;
    }

    final dueWords = await _progressRepository.getDueWords(config.levels);
    takeWords(dueWords, dueQuota);

    if (result.length < target && hardWordIds.isNotEmpty) {
      final hardPool = candidatePool.where((w) => hardWordIds.contains(w.id)).toList();
      takeWords(hardPool, hardQuota);
    }

    if (result.length < target && !config.onlyLeeches && newQuota > 0) {
      final need = min(newQuota, target - result.length);
      if (need > 0) {
        final newWords = await _progressRepository.getNewWords(config.levels, need * 2);
        newWords.shuffle(Random());
        final selected = newWords.take(need).toList();
        newWordsPicked += selected.length;
        takeWords(selected, selected.length);
      }
    }

    if (result.length < target) {
      final filler = candidatePool
          .where((w) =>
              !seen.contains(w.id) &&
              !hardWordIds.contains(w.id) &&
              !recentWordIds.contains(w.id))
          .toList();
      final sortedFiller = await _sortByLastReview(filler);
      takeWords(sortedFiller, target - result.length);
    }

    if (result.length < target && recentWordIds.isNotEmpty) {
      final recentFillers = candidatePool
          .where((w) => recentWordIds.contains(w.id) && !seen.contains(w.id))
          .toList();
      final sortedRecent = await _sortByLastReview(recentFillers);
      takeWords(sortedRecent, target - result.length);
    }

    if (config.onlyLeeches && result.length < target) {
      final leeches = await _progressRepository.getLeechWords(config.levels);
      takeWords(leeches, target - result.length);
    }

    if (result.length < target) {
      final remaining = candidatePool.where((w) => !seen.contains(w.id)).toList();
      final sortedRemaining = await _sortByLastReview(remaining);
      takeWords(sortedRemaining, target - result.length);
    }

    if (config.orderPolicy == 'random') {
      result.shuffle(Random());
    } else {
      result.sort((a, b) => a.level.compareTo(b.level));
    }

    if (result.length > target) {
      return result.take(target).toList();
    }

    if (newWordsPicked > 0) {
      await _consumeDailyNew(newWordsPicked);
    }
    return result;
  }

  Future<List<Word>> _sortByLastReview(List<Word> words) async {
    if (words.isEmpty) return words;
    final states = await _progressRepository.getCardStates(words.map((w) => w.id).toList());
    final stateMap = {for (final s in states) s.wordId: s};
    final sentinel = DateTime.fromMillisecondsSinceEpoch(0);
    words.sort((a, b) {
      final sa = stateMap[a.id];
      final sb = stateMap[b.id];
      final da = sa?.lastReview ?? sentinel;
      final db = sb?.lastReview ?? sentinel;
      return da.compareTo(db);
    });
    return words;
  }
}
