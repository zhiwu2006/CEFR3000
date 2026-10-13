// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CardStateAdapter extends TypeAdapter<CardState> {
  @override
  final int typeId = 2;

  @override
  CardState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CardState(
      wordId: fields[0] as int,
      stability: fields[1] as double,
      difficulty: fields[2] as double,
      due: fields[3] as DateTime,
      lapses: fields[4] as int,
      rtP50: fields[5] as int,
      flags: fields[6] as int,
      lastReview: fields[7] as DateTime,
      longTermReviews:
          fields[8] as int? ?? ((fields[1] as double) >= 16 ? 2 : 0),
      revision: fields[9] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, CardState obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.wordId)
      ..writeByte(1)
      ..write(obj.stability)
      ..writeByte(2)
      ..write(obj.difficulty)
      ..writeByte(3)
      ..write(obj.due)
      ..writeByte(4)
      ..write(obj.lapses)
      ..writeByte(5)
      ..write(obj.rtP50)
      ..writeByte(6)
      ..write(obj.flags)
      ..writeByte(7)
      ..write(obj.lastReview)
      ..writeByte(8)
      ..write(obj.longTermReviews)
      ..writeByte(9)
      ..write(obj.revision);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CardState _$CardStateFromJson(Map<String, dynamic> json) => CardState(
  wordId: (json['wordId'] as num).toInt(),
  stability: (json['stability'] as num).toDouble(),
  difficulty: (json['difficulty'] as num).toDouble(),
  due: DateTime.parse(json['due'] as String),
  lapses: (json['lapses'] as num).toInt(),
  rtP50: (json['rtP50'] as num).toInt(),
  flags: (json['flags'] as num).toInt(),
  lastReview: DateTime.parse(json['lastReview'] as String),
  longTermReviews: (json['longTermReviews'] as num?)?.toInt() ?? 0,
  revision: (json['revision'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CardStateToJson(CardState instance) => <String, dynamic>{
  'wordId': instance.wordId,
  'stability': instance.stability,
  'difficulty': instance.difficulty,
  'due': instance.due.toIso8601String(),
  'lapses': instance.lapses,
  'rtP50': instance.rtP50,
  'flags': instance.flags,
  'lastReview': instance.lastReview.toIso8601String(),
  'longTermReviews': instance.longTermReviews,
  'revision': instance.revision,
};
