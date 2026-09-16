// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attempt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttemptAdapter extends TypeAdapter<Attempt> {
  @override
  final int typeId = 1;

  @override
  Attempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attempt(
      wordId: fields[0] as int,
      result: fields[1] as AttemptResult,
      rtMs: fields[2] as int,
      chosenIndex: fields[3] as int,
      correctIndex: fields[4] as int,
      timestamp: fields[5] as DateTime,
      kind: fields[6] as AttemptKind? ?? AttemptKind.initial,
      highestHintLevel: fields[7] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Attempt obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.wordId)
      ..writeByte(1)
      ..write(obj.result)
      ..writeByte(2)
      ..write(obj.rtMs)
      ..writeByte(3)
      ..write(obj.chosenIndex)
      ..writeByte(4)
      ..write(obj.correctIndex)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.kind)
      ..writeByte(7)
      ..write(obj.highestHintLevel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttemptResultAdapter extends TypeAdapter<AttemptResult> {
  @override
  final int typeId = 4;

  @override
  AttemptResult read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttemptResult.correct;
      case 1:
        return AttemptResult.wrong;
      case 2:
        return AttemptResult.timeout;
      default:
        return AttemptResult.correct;
    }
  }

  @override
  void write(BinaryWriter writer, AttemptResult obj) {
    switch (obj) {
      case AttemptResult.correct:
        writer.writeByte(0);
        break;
      case AttemptResult.wrong:
        writer.writeByte(1);
        break;
      case AttemptResult.timeout:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttemptKindAdapter extends TypeAdapter<AttemptKind> {
  @override
  final int typeId = 5;

  @override
  AttemptKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttemptKind.initial;
      case 1:
        return AttemptKind.inSessionRetry;
      case 2:
        return AttemptKind.scheduledReview;
      case 3:
        return AttemptKind.targetedPractice;
      default:
        return AttemptKind.initial;
    }
  }

  @override
  void write(BinaryWriter writer, AttemptKind obj) {
    switch (obj) {
      case AttemptKind.initial:
        writer.writeByte(0);
        break;
      case AttemptKind.inSessionRetry:
        writer.writeByte(1);
        break;
      case AttemptKind.scheduledReview:
        writer.writeByte(2);
        break;
      case AttemptKind.targetedPractice:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attempt _$AttemptFromJson(Map<String, dynamic> json) => Attempt(
  wordId: (json['wordId'] as num).toInt(),
  result: $enumDecode(_$AttemptResultEnumMap, json['result']),
  rtMs: (json['rtMs'] as num).toInt(),
  chosenIndex: (json['chosenIndex'] as num).toInt(),
  correctIndex: (json['correctIndex'] as num).toInt(),
  timestamp: DateTime.parse(json['timestamp'] as String),
  kind: $enumDecodeNullable(_$AttemptKindEnumMap, json['kind']) ??
      AttemptKind.initial,
  highestHintLevel: (json['highestHintLevel'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$AttemptToJson(Attempt instance) => <String, dynamic>{
  'wordId': instance.wordId,
  'result': _$AttemptResultEnumMap[instance.result]!,
  'rtMs': instance.rtMs,
  'chosenIndex': instance.chosenIndex,
  'correctIndex': instance.correctIndex,
  'timestamp': instance.timestamp.toIso8601String(),
  'kind': _$AttemptKindEnumMap[instance.kind]!,
  'highestHintLevel': instance.highestHintLevel,
};

const _$AttemptResultEnumMap = {
  AttemptResult.correct: 'correct',
  AttemptResult.wrong: 'wrong',
  AttemptResult.timeout: 'timeout',
};

const _$AttemptKindEnumMap = {
  AttemptKind.initial: 'initial',
  AttemptKind.inSessionRetry: 'inSessionRetry',
  AttemptKind.scheduledReview: 'scheduledReview',
  AttemptKind.targetedPractice: 'targetedPractice',
};
