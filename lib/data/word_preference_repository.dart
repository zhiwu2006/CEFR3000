import 'dart:convert';

/// 用户对词条的声明与学习开关。
///
/// 这些字段是偏好事实，不会伪造 ReviewEvent，也不会直接修改能力级
/// MemoryState。`suspended` 只影响计划选择，`selfDeclaredKnown` 只影响展示。
class UserWordPreference {
  final String lexemeId;
  final bool suspended;
  final bool selfDeclaredKnown;
  final bool manualDifficult;
  final DateTime updatedAt;

  const UserWordPreference({
    required this.lexemeId,
    this.suspended = false,
    this.selfDeclaredKnown = false,
    this.manualDifficult = false,
    required this.updatedAt,
  });

  UserWordPreference copyWith({
    bool? suspended,
    bool? selfDeclaredKnown,
    bool? manualDifficult,
    DateTime? updatedAt,
  }) => UserWordPreference(
    lexemeId: lexemeId,
    suspended: suspended ?? this.suspended,
    selfDeclaredKnown: selfDeclaredKnown ?? this.selfDeclaredKnown,
    manualDifficult: manualDifficult ?? this.manualDifficult,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'lexemeId': lexemeId,
    'suspended': suspended,
    'selfDeclaredKnown': selfDeclaredKnown,
    'manualDifficult': manualDifficult,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserWordPreference.fromJson(Map<String, dynamic> json) =>
      UserWordPreference(
        lexemeId: json['lexemeId'] as String,
        suspended: json['suspended'] as bool? ?? false,
        selfDeclaredKnown: json['selfDeclaredKnown'] as bool? ?? false,
        manualDifficult: json['manualDifficult'] as bool? ?? false,
        updatedAt:
            DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  String encode() => jsonEncode(toJson());

  static UserWordPreference decode(String value) =>
      UserWordPreference.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
}

abstract interface class WordPreferenceRepository {
  Future<UserWordPreference?> getWordPreference(String lexemeId);

  Future<List<UserWordPreference>> getWordPreferences();

  Future<void> saveWordPreference(UserWordPreference preference);

  Future<void> clearWordPreference(String lexemeId);
}
