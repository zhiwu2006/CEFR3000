import 'dart:math';

import '../models/models.dart';
import '../data/repositories.dart';
import 'session_models.dart';

class WordSelectionService {
  final ProgressRepository _progressRepository;
  final int Function() _getDailyNewRemaining;
  final Future<void> Function(int) _consumeDailyNew;
  final bool consumeNewOnSelection;

  WordSelectionService({
    required ProgressRepository progressRepository,
    required int Function() getDailyNewRemaining,
    required Future<void> Function(int) consumeDailyNew,
    this.consumeNewOnSelection = true,
  }) : _progressRepository = progressRepository,
       _getDailyNewRemaining = getDailyNewRemaining,
       _consumeDailyNew = consumeDailyNew;

  Future<List<Word>> buildWordListForNewSession({
    required SessionConfig config,
    required List<Word> candidatePool,
    required Set<int> recentWordIds,
    required Set<int> hardWordIds,
  }) async {
    final target = config.wordsPerSession;

    // 1. [问题5修复] 仅疑难词模式：独立短路选词，绝不混入普通词或新词
    if (config.onlyLeeches) {
      final leeches = _progressRepository is LeechPolicyProgressRepository
          ? await (_progressRepository as LeechPolicyProgressRepository)
                .getLeechWordsWithPolicy(config.levels, config.leechPolicy)
          : await _progressRepository.getLeechWords(config.levels);
      final uniqueLeeches = <Word>[];
      final seenIds = <int>{};
      for (final w in leeches) {
        if (seenIds.add(w.id)) {
          uniqueLeeches.add(w);
        }
      }
      if (config.orderPolicy == 'random') {
        uniqueLeeches.shuffle(Random());
      } else {
        uniqueLeeches.sort((a, b) => a.level.compareTo(b.level));
      }
      return uniqueLeeches.take(target).toList();
    }

    final seen = <int>{};
    final result = <Word>[];

    final desiredNewQuota = (target * config.newCardRatio).round().clamp(
      0,
      target,
    );
    final dailyRemaining = _getDailyNewRemaining();
    final newQuota = min(desiredNewQuota, dailyRemaining);
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

    // 2. 到期词优先。复习积压时允许它们占满牌组，自动挤出新词配额。
    final dueWords = await _progressRepository.getDueWords(config.levels);
    takeWords(dueWords, target);

    // 3. 到期词不足时，再补充上一轮答错或超时的词。
    if (result.length < target && hardWordIds.isNotEmpty) {
      final hardPool = candidatePool
          .where((w) => hardWordIds.contains(w.id))
          .toList();
      takeWords(hardPool, target - result.length);
    }

    // 4. 抽取额度内的新词
    if (result.length < target && newQuota > 0) {
      final need = min(newQuota, target - result.length);
      if (need > 0) {
        final newWords = await _progressRepository.getNewWords(
          config.levels,
          need * 2,
        );
        newWords.shuffle(Random());
        final selected = newWords.take(need).toList();
        final picked = takeWords(selected, selected.length);
        newWordsPicked += picked.length;
      }
    }

    // 5. [问题4修复] 填充已学复习词（优先补充已学过、有lastReview的词，不占新词配额）
    if (result.length < target) {
      final filler = candidatePool
          .where(
            (w) =>
                !seen.contains(w.id) &&
                !hardWordIds.contains(w.id) &&
                !recentWordIds.contains(w.id),
          )
          .toList();
      final reviewedFiller = await _filterAndSortReviewedWords(filler);
      takeWords(reviewedFiller, target - result.length);
    }

    // 6. 填充已学过的近期词
    if (result.length < target && recentWordIds.isNotEmpty) {
      final recentFillers = candidatePool
          .where((w) => recentWordIds.contains(w.id) && !seen.contains(w.id))
          .toList();
      final reviewedRecent = await _filterAndSortReviewedWords(recentFillers);
      takeWords(reviewedRecent, target - result.length);
    }

    // 7. [问题4修复] 纯新词兜底填充：严格受每日新词剩余额度钳制，绝不绕过上限
    if (result.length < target) {
      final remainingDailyQuota = max(0, dailyRemaining - newWordsPicked);
      final canTakeNew = min(target - result.length, remainingDailyQuota);
      if (canTakeNew > 0) {
        var remainingNew = await _progressRepository.getNewWords(
          config.levels,
          canTakeNew * 2,
        );
        if (remainingNew.isEmpty) {
          // 兼容只实现了基础仓储接口的测试替身；正式 Hive 仓储会由
          // getNewWords 直接返回未建卡单词。
          final remainingPool = candidatePool
              .where((w) => !seen.contains(w.id))
              .toList();
          final states = await _progressRepository.getCardStates(
            remainingPool.map((w) => w.id).toList(),
          );
          final stateMap = {for (final state in states) state.wordId: state};
          remainingNew = remainingPool
              .where((w) => !stateMap.containsKey(w.id))
              .toList();
        }
        final purelyNew =
            remainingNew.where((w) => !seen.contains(w.id)).toList()
              ..shuffle(Random());
        final picked = takeWords(purelyNew, canTakeNew);
        newWordsPicked += picked.length;
      }
    }

    // 8. 排序逻辑
    if (config.orderPolicy == 'random') {
      result.shuffle(Random());
    } else {
      result.sort((a, b) => a.level.compareTo(b.level));
    }

    // 9. 扣减已消耗的每日新词额度
    if (newWordsPicked > 0 && consumeNewOnSelection) {
      await _consumeDailyNew(newWordsPicked);
    }

    if (result.length > target) {
      return result.take(target).toList();
    }
    return result;
  }

  /// 过滤出已有复习记录的已学词，并按最久未复习（lastReview 升序）排序
  Future<List<Word>> _filterAndSortReviewedWords(List<Word> words) async {
    if (words.isEmpty) return [];
    final states = await _progressRepository.getCardStates(
      words.map((w) => w.id).toList(),
    );
    final stateMap = {for (final s in states) s.wordId: s};
    final reviewed = <Word>[];
    for (final w in words) {
      final s = stateMap[w.id];
      if (s != null) {
        reviewed.add(w);
      }
    }
    reviewed.sort((a, b) {
      final da = stateMap[a.id]!.lastReview;
      final db = stateMap[b.id]!.lastReview;
      return da.compareTo(db);
    });
    return reviewed;
  }
}
