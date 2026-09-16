import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'word.g.dart';

/// 单词模型类
@HiveType(typeId: 0)
@JsonSerializable()
class Word {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String headword;

  @HiveField(2)
  final String lemma;

  @HiveField(3)
  final String level;

  @HiveField(4)
  final String pos;

  @HiveField(5)
  @JsonKey(name: 'cn_defs')
  final List<String> cnDefs;

  const Word({
    required this.id,
    required this.headword,
    required this.lemma,
    required this.level,
    required this.pos,
    required this.cnDefs,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
  Map<String, dynamic> toJson() => _$WordToJson(this);

  /// 获取首选中文释义
  String get primaryDefinition => cnDefs.isNotEmpty ? cnDefs.first : headword;

  /// 新内容模型使用的稳定 ID；旧资源的数值 ID 保留在映射中。
  String get stableId => 'legacy:$id';

  String get primarySenseId => '$stableId:sense:primary';

  /// 获取主要词性（去除细节）
  String get majorPos {
    final pos = this.pos.toLowerCase();
    if (pos.startsWith('n')) return 'n';
    if (pos.startsWith('v')) return 'v';
    if (pos.startsWith('adj')) return 'adj';
    if (pos.startsWith('adv')) return 'adv';
    return pos;
  }

  /// 检查是否为同一级别
  bool isSameLevel(String otherLevel) => level == otherLevel;

  /// 检查是否为同一主要词性
  bool isSameMajorPos(String otherPos) => majorPos == otherPos.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Word && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Word(id: $id, headword: $headword, level: $level, pos: $pos)';
}
