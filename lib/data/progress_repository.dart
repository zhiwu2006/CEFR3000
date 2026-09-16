import '../models/models.dart';
import '../domain/srs.dart';

/// 进度仓储接口
abstract class ProgressRepository {
  /// 获取单词的卡片状态
  Future<CardState?> getCardState(int wordId);

  /// 批量获取卡片状态
  Future<List<CardState>> getCardStates(List<int> wordIds);

  /// 保存卡片状态
  Future<void> saveCardState(CardState cardState);

  /// 批量更新卡片状态
  Future<void> batchUpdateCardStates(Map<int, CardState> states);

  /// 获取到期单词
  Future<List<Word>> getDueWords(Set<String> levels);

  /// 获取不熟悉单词
  Future<List<Word>> getLeechWords(Set<String> levels);

  /// 按用户配置获取不熟悉单词。
  ///
  /// 保留默认实现是为了让旧的仓储实现和测试替身继续兼容；新的调用方
  /// 应优先使用这个方法，避免把默认的失忆阈值写死在数据层。
  Future<List<Word>> getLeechWordsWithPolicy(
    Set<String> levels,
    LeechPolicy policy,
  ) => getLeechWords(levels);

  /// 获取新单词
  Future<List<Word>> getNewWords(Set<String> levels, int limit);

  /// 保存测试记录
  Future<void> saveTestRun(TestRun testRun);

  /// 获取测试记录历史
  Future<List<TestRun>> getTestRunHistory({int limit = 10});

  /// 获取最新的测试记录
  Future<TestRun?> getLatestTestRun();

  /// 批量保存答题记录
  Future<void> batchSaveAttempts(List<Attempt> attempts);

  /// 获取单词的答题记录
  Future<List<Attempt>> getWordAttempts(int wordId, {int limit = 10});

  /// 获取学习统计
  Future<Map<String, dynamic>> getLearningStats({
    LeechPolicy policy = LeechPolicy.defaultPolicy,
  });

  /// 清除所有进度
  Future<void> clearAllProgress();

  /// 清除测试记录
  Future<void> clearTestRuns();

  /// 清除答题记录
  Future<void> clearAttempts();

  /// 清除卡片状态
  Future<void> clearCardStates();

  /// 导出进度数据
  Future<Map<String, dynamic>> exportProgress();

  /// 导入进度数据
  Future<void> importProgress(Map<String, dynamic> data);

  /// 重置单词进度（标记为已掌握）
  Future<void> resetWordProgress(int wordId);

  /// 标记单词为已掌握（提升稳定度并清除疑难状态）
  Future<void> markWordKnown(int wordId);

  /// 标记单词为疑难
  Future<void> markWordDifficult(int wordId);

  /// 取消单词疑难标记
  Future<void> unmarkWordDifficult(int wordId);

  /// 获取指定天数的每日统计数据
  Future<List<Map<String, dynamic>>> getDailyStats(int days);

  /// 获取指定级别的进度
  Future<Map<String, int>> getLevelProgress(Set<String> levels);

  /// 获取指定级别的单词学习状态列表
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels);
}

/// 支持按用户配置筛选疑难词的仓储能力。
/// 老的测试替身或第三方实现可以只实现 ProgressRepository，调用方会回退到默认策略。
abstract class LeechPolicyProgressRepository {
  Future<List<Word>> getLeechWordsWithPolicy(
    Set<String> levels,
    LeechPolicy policy,
  );
}
