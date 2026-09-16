// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_run.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TestRunAdapter extends TypeAdapter<TestRun> {
  @override
  final int typeId = 3;

  @override
  TestRun read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TestRun(
      id: fields[0] as String,
      startedAt: fields[1] as DateTime,
      finishedAt: fields[2] as DateTime?,
      size: fields[3] as int,
      levels: (fields[4] as List).cast<String>(),
      timeLimitMs: fields[5] as int,
      accuracy: fields[6] as double?,
      avgRtMs: fields[7] as int?,
      attempts: (fields[8] as List).cast<Attempt>(),
      orderPolicy: fields[9] as String,
      onlyLeeches: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TestRun obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startedAt)
      ..writeByte(2)
      ..write(obj.finishedAt)
      ..writeByte(3)
      ..write(obj.size)
      ..writeByte(4)
      ..write(obj.levels)
      ..writeByte(5)
      ..write(obj.timeLimitMs)
      ..writeByte(6)
      ..write(obj.accuracy)
      ..writeByte(7)
      ..write(obj.avgRtMs)
      ..writeByte(8)
      ..write(obj.attempts)
      ..writeByte(9)
      ..write(obj.orderPolicy)
      ..writeByte(10)
      ..write(obj.onlyLeeches);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestRunAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestRun _$TestRunFromJson(Map<String, dynamic> json) => TestRun(
  id: json['id'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  finishedAt: json['finishedAt'] == null
      ? null
      : DateTime.parse(json['finishedAt'] as String),
  size: (json['size'] as num).toInt(),
  levels: (json['levels'] as List<dynamic>).map((e) => e as String).toList(),
  timeLimitMs: (json['timeLimitMs'] as num).toInt(),
  accuracy: (json['accuracy'] as num?)?.toDouble(),
  avgRtMs: (json['avgRtMs'] as num?)?.toInt(),
  attempts: (json['attempts'] as List<dynamic>)
      .map((e) => Attempt.fromJson(e as Map<String, dynamic>))
      .toList(),
  orderPolicy: json['orderPolicy'] as String,
  onlyLeeches: json['onlyLeeches'] as bool,
);

Map<String, dynamic> _$TestRunToJson(TestRun instance) => <String, dynamic>{
  'id': instance.id,
  'startedAt': instance.startedAt.toIso8601String(),
  'finishedAt': instance.finishedAt?.toIso8601String(),
  'size': instance.size,
  'levels': instance.levels,
  'timeLimitMs': instance.timeLimitMs,
  'accuracy': instance.accuracy,
  'avgRtMs': instance.avgRtMs,
  'attempts': instance.attempts,
  'orderPolicy': instance.orderPolicy,
  'onlyLeeches': instance.onlyLeeches,
};
