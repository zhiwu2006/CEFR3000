import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/models.dart';
import 'word_repository.dart';

/// Hive实现的词库仓储
class HiveWordRepository implements WordRepository {
  static const String _boxName = 'words';
  late Box<Word> _box;
  List<Word>? _cachedWords;

  /// 初始化
  Future<void> init() async {
    try {
      debugPrint('Registering Word adapter...');
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(WordAdapter());
      }
      
      debugPrint('Opening words box...');
      _box = await Hive.openBox<Word>(_boxName);
      debugPrint('Words box opened, contains ${_box.length} words');
      
      // 如果box为空，则从assets加载
      if (_box.isEmpty) {
        debugPrint('Words box is empty, loading from assets...');
        await _loadFromAssets();
      } else {
        debugPrint('Words already loaded from previous session');
      }
    } catch (e, stackTrace) {
      debugPrint('Error in HiveWordRepository.init(): $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// 强制重新加载词汇数据（清除旧数据并重新从assets加载）
  @override
  Future<void> forceReload() async {
    debugPrint('Force reloading words from assets...');
    
    // 清除旧数据
    await _box.clear();
    
    // 清除缓存
    _clearCache();
    
    // 重新从assets加载
    await _loadFromAssets();
  }

  /// 从assets加载词汇数据
  Future<void> _loadFromAssets() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/words.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      final words = jsonList.map((json) => Word.fromJson(json)).toList();
      
      // 批量保存到Hive
      final Map<int, Word> wordMap = {for (var word in words) word.id: word};
      await _box.putAll(wordMap);
      
      debugPrint('Loaded ${words.length} words from assets');
    } catch (e) {
      debugPrint('Error loading words from assets: $e');
      rethrow;
    }
  }

  /// 获取缓存的单词列表
  List<Word> get _words {
    if (_cachedWords == null) {
      _cachedWords = _box.values.toList();
      _cachedWords!.sort((a, b) => a.id.compareTo(b.id));
    }
    return _cachedWords!;
  }

  /// 清除缓存
  void _clearCache() {
    _cachedWords = null;
  }

  @override
  Future<List<Word>> loadAll() async {
    return _words;
  }

  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async {
    return _words.where((word) => levels.contains(word.level)).toList();
  }

  @override
  Future<Word?> getById(int id) async {
    return _box.get(id);
  }

  @override
  Future<List<Word>> getByIds(List<int> ids) async {
    final List<Word> result = [];
    for (final id in ids) {
      final word = _box.get(id);
      if (word != null) {
        result.add(word);
      }
    }
    return result;
  }

  @override
  Future<List<Word>> getByLevelAndPos(String level, String pos) async {
    return _words
        .where((word) => word.level == level && word.pos == pos)
        .toList();
  }

  @override
  Future<List<Word>> getSameLevelSamePos(String level, String pos, {int? excludeId}) async {
    return _words
        .where((word) => 
            word.level == level && 
            word.majorPos == pos && 
            (excludeId == null || word.id != excludeId))
        .toList();
  }

  @override
  Future<List<Word>> search(String query) async {
    final lowerQuery = query.toLowerCase();
    return _words
        .where((word) => 
            word.headword.toLowerCase().contains(lowerQuery) ||
            word.lemma.toLowerCase().contains(lowerQuery) ||
            word.cnDefs.any((def) => def.contains(query)))
        .toList();
  }

  @override
  Future<Map<String, int>> getStatistics() async {
    final stats = <String, int>{};
    
    // 按级别统计
    for (final word in _words) {
      stats['level_${word.level}'] = (stats['level_${word.level}'] ?? 0) + 1;
      stats['pos_${word.majorPos}'] = (stats['pos_${word.majorPos}'] ?? 0) + 1;
    }
    
    stats['total'] = _words.length;
    
    return stats;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _box.close();
  }
}
