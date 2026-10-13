// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 6;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      session: fields[0] as SessionSettings,
      theme: fields[1] as ThemeSettings,
      tts: fields[2] as TtsSettings,
      srs: fields[3] as SrsSettings,
      algorithm: fields[4] as AlgorithmSettings,
      ai: fields[5] as AiSettings,
      currentSessionId: fields[10] as String?,
      currentProgress: fields[11] as int,
      totalWords: fields[12] as int,
      remainingWordIds: (fields[13] as List).cast<int>(),
      dailyNewDate: fields[14] as String,
      dailyNewUsed: fields[15] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.session)
      ..writeByte(1)
      ..write(obj.theme)
      ..writeByte(2)
      ..write(obj.tts)
      ..writeByte(3)
      ..write(obj.srs)
      ..writeByte(4)
      ..write(obj.algorithm)
      ..writeByte(5)
      ..write(obj.ai)
      ..writeByte(10)
      ..write(obj.currentSessionId)
      ..writeByte(11)
      ..write(obj.currentProgress)
      ..writeByte(12)
      ..write(obj.totalWords)
      ..writeByte(13)
      ..write(obj.remainingWordIds)
      ..writeByte(14)
      ..write(obj.dailyNewDate)
      ..writeByte(15)
      ..write(obj.dailyNewUsed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  session: SessionSettings.fromJson(json['session'] as Map<String, dynamic>),
  theme: ThemeSettings.fromJson(json['theme'] as Map<String, dynamic>),
  tts: TtsSettings.fromJson(json['tts'] as Map<String, dynamic>),
  srs: SrsSettings.fromJson(json['srs'] as Map<String, dynamic>),
  algorithm: AlgorithmSettings.fromJson(
    json['algorithm'] as Map<String, dynamic>,
  ),
  ai: AiSettings.fromJson(json['ai'] as Map<String, dynamic>),
  currentSessionId: json['currentSessionId'] as String?,
  currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
  totalWords: (json['totalWords'] as num?)?.toInt() ?? 0,
  remainingWordIds:
      (json['remainingWordIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  dailyNewDate: json['dailyNewDate'] as String? ?? '',
  dailyNewUsed: (json['dailyNewUsed'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'session': instance.session,
      'theme': instance.theme,
      'tts': instance.tts,
      'srs': instance.srs,
      'algorithm': instance.algorithm,
      'ai': instance.ai,
      'currentSessionId': instance.currentSessionId,
      'currentProgress': instance.currentProgress,
      'totalWords': instance.totalWords,
      'remainingWordIds': instance.remainingWordIds,
      'dailyNewDate': instance.dailyNewDate,
      'dailyNewUsed': instance.dailyNewUsed,
    };
