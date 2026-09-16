// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordAdapter extends TypeAdapter<Word> {
  @override
  final int typeId = 0;

  @override
  Word read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Word(
      id: fields[0] as int,
      headword: fields[1] as String,
      lemma: fields[2] as String,
      level: fields[3] as String,
      pos: fields[4] as String,
      cnDefs: (fields[5] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Word obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.headword)
      ..writeByte(2)
      ..write(obj.lemma)
      ..writeByte(3)
      ..write(obj.level)
      ..writeByte(4)
      ..write(obj.pos)
      ..writeByte(5)
      ..write(obj.cnDefs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Word _$WordFromJson(Map<String, dynamic> json) => Word(
  id: (json['id'] as num).toInt(),
  headword: json['headword'] as String,
  lemma: json['lemma'] as String,
  level: json['level'] as String,
  pos: json['pos'] as String,
  cnDefs: (json['cn_defs'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$WordToJson(Word instance) => <String, dynamic>{
  'id': instance.id,
  'headword': instance.headword,
  'lemma': instance.lemma,
  'level': instance.level,
  'pos': instance.pos,
  'cn_defs': instance.cnDefs,
};
