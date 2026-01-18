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
      selectedLevels: (fields[0] as List).cast<String>(),
      wordsPerSession: fields[1] as int,
      timeLimitMs: fields[2] as int,
      orderPolicy: fields[3] as String,
      onlyLeeches: fields[4] as bool,
      delayProfile: fields[5] as DelayProfile,
      ttsLocale: fields[6] as String,
      ttsRate: fields[7] as double,
      ttsPitch: fields[8] as double,
      highContrast: fields[9] as bool,
      uiLocale: fields[10] as String,
      currentSessionId: fields[11] as String?,
      currentProgress: fields[12] as int,
      totalWords: fields[13] as int,
      remainingWordIds: (fields[14] as List).cast<int>(),
      themeStyle: fields[15] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.selectedLevels)
      ..writeByte(1)
      ..write(obj.wordsPerSession)
      ..writeByte(2)
      ..write(obj.timeLimitMs)
      ..writeByte(3)
      ..write(obj.orderPolicy)
      ..writeByte(4)
      ..write(obj.onlyLeeches)
      ..writeByte(5)
      ..write(obj.delayProfile)
      ..writeByte(6)
      ..write(obj.ttsLocale)
      ..writeByte(7)
      ..write(obj.ttsRate)
      ..writeByte(8)
      ..write(obj.ttsPitch)
      ..writeByte(9)
      ..write(obj.highContrast)
      ..writeByte(10)
      ..write(obj.uiLocale)
      ..writeByte(11)
      ..write(obj.currentSessionId)
      ..writeByte(12)
      ..write(obj.currentProgress)
      ..writeByte(13)
      ..write(obj.totalWords)
      ..writeByte(14)
      ..write(obj.remainingWordIds)
      ..writeByte(15)
      ..write(obj.themeStyle);
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

class DelayProfileAdapter extends TypeAdapter<DelayProfile> {
  @override
  final int typeId = 5;

  @override
  DelayProfile read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DelayProfile.gentle;
      case 1:
        return DelayProfile.standard;
      case 2:
        return DelayProfile.aggressive;
      default:
        return DelayProfile.gentle;
    }
  }

  @override
  void write(BinaryWriter writer, DelayProfile obj) {
    switch (obj) {
      case DelayProfile.gentle:
        writer.writeByte(0);
        break;
      case DelayProfile.standard:
        writer.writeByte(1);
        break;
      case DelayProfile.aggressive:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DelayProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      selectedLevels: (json['selectedLevels'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      wordsPerSession: (json['wordsPerSession'] as num).toInt(),
      timeLimitMs: (json['timeLimitMs'] as num).toInt(),
      orderPolicy: json['orderPolicy'] as String,
      onlyLeeches: json['onlyLeeches'] as bool,
      delayProfile: $enumDecode(_$DelayProfileEnumMap, json['delayProfile']),
      ttsLocale: json['ttsLocale'] as String,
      ttsRate: (json['ttsRate'] as num).toDouble(),
      ttsPitch: (json['ttsPitch'] as num).toDouble(),
      highContrast: json['highContrast'] as bool,
      uiLocale: json['uiLocale'] as String,
      currentSessionId: json['currentSessionId'] as String?,
      currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
      totalWords: (json['totalWords'] as num?)?.toInt() ?? 0,
      remainingWordIds: (json['remainingWordIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      themeStyle: json['themeStyle'] as String? ?? 'standard',
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'selectedLevels': instance.selectedLevels,
      'wordsPerSession': instance.wordsPerSession,
      'timeLimitMs': instance.timeLimitMs,
      'orderPolicy': instance.orderPolicy,
      'onlyLeeches': instance.onlyLeeches,
      'delayProfile': _$DelayProfileEnumMap[instance.delayProfile]!,
      'ttsLocale': instance.ttsLocale,
      'ttsRate': instance.ttsRate,
      'ttsPitch': instance.ttsPitch,
      'highContrast': instance.highContrast,
      'uiLocale': instance.uiLocale,
      'currentSessionId': instance.currentSessionId,
      'currentProgress': instance.currentProgress,
      'totalWords': instance.totalWords,
      'remainingWordIds': instance.remainingWordIds,
      'themeStyle': instance.themeStyle,
    };

const _$DelayProfileEnumMap = {
  DelayProfile.gentle: 'gentle',
  DelayProfile.standard: 'standard',
  DelayProfile.aggressive: 'aggressive',
};
