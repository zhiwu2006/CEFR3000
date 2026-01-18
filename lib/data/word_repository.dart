import '../models/models.dart';

/// 词库仓储接口
abstract class WordRepository {
  /// 加载所有单词
  Future<List<Word>> loadAll();

  /// 按级别加载单词
  Future<List<Word>> loadByLevels(Set<String> levels);

  /// 按ID获取单词
  Future<Word?> getById(int id);

  /// 批量按ID获取单词
  Future<List<Word>> getByIds(List<int> ids);

  /// 获取指定级别和词性的单词
  Future<List<Word>> getByLevelAndPos(String level, String pos);

  /// 获取同级别同词性的单词（用于干扰项生成）
  Future<List<Word>> getSameLevelSamePos(String level, String pos, {int? excludeId});

  /// 搜索单词
  Future<List<Word>> search(String query);

  /// 获取词汇统计信息
  Future<Map<String, int>> getStatistics();
  
  /// 强制重新加载词汇数据（清除缓存并重新从assets加载）
  Future<void> forceReload();
}