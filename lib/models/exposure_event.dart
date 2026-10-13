import 'package:hive/hive.dart';

/// 词条被实际展示/接触的事实。
///
/// Exposure 与 ReviewEvent 分开保存：看到释义、播放发音或进入回忆卡片
/// 可以算接触，但只有提交了未看答案的回忆才会影响长期回忆证据。
@HiveType(typeId: 8)
class ExposureEvent {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String sessionId;
  @HiveField(2)
  final int wordId;
  @HiveField(3)
  final DateTime occurredAt;
  @HiveField(4)
  final String localDate;
  @HiveField(5)
  final String contentVersion;

  const ExposureEvent({
    required this.id,
    required this.sessionId,
    required this.wordId,
    required this.occurredAt,
    required this.localDate,
    this.contentVersion = 'legacy-v1',
  });

  static String idFor({
    required String sessionId,
    required int wordId,
    String? localDate,
  }) => localDate == null
      ? '$sessionId:$wordId:exposure'
      : '$sessionId:$wordId:$localDate:exposure';

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'wordId': wordId,
    'occurredAt': occurredAt.toIso8601String(),
    'localDate': localDate,
    'contentVersion': contentVersion,
  };

  factory ExposureEvent.fromJson(Map<String, dynamic> json) => ExposureEvent(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String? ?? '',
    wordId: (json['wordId'] as num).toInt(),
    occurredAt:
        DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
        DateTime.now(),
    localDate: json['localDate'] as String? ?? '',
    contentVersion: json['contentVersion'] as String? ?? 'legacy-v1',
  );
}

class ExposureEventAdapter extends TypeAdapter<ExposureEvent> {
  @override
  final int typeId = 8;

  @override
  ExposureEvent read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (var i = 0, count = reader.readByte(); i < count; i++)
        reader.readByte(): reader.read(),
    };
    return ExposureEvent(
      id: fields[0] as String,
      sessionId: fields[1] as String? ?? '',
      wordId: (fields[2] as num).toInt(),
      occurredAt: fields[3] as DateTime? ?? DateTime.now(),
      localDate: fields[4] as String? ?? '',
      contentVersion: fields[5] as String? ?? 'legacy-v1',
    );
  }

  @override
  void write(BinaryWriter writer, ExposureEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.wordId)
      ..writeByte(3)
      ..write(obj.occurredAt)
      ..writeByte(4)
      ..write(obj.localDate)
      ..writeByte(5)
      ..write(obj.contentVersion);
  }
}
