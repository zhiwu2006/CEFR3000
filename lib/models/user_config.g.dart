// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionSettingsAdapter extends TypeAdapter<SessionSettings> {
  @override
  final int typeId = 10;

  @override
  SessionSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionSettings(
      selectedLevels: (fields[0] as List).cast<String>(),
      wordsPerSession: fields[1] as int,
      timeLimitMs: fields[2] as int,
      orderPolicy: fields[3] as String,
      onlyLeeches: fields[4] as bool,
      learningMode: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SessionSettings obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.learningMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThemeSettingsAdapter extends TypeAdapter<ThemeSettings> {
  @override
  final int typeId = 11;

  @override
  ThemeSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThemeSettings(
      themeStyle: fields[0] as String,
      highContrast: fields[1] as bool,
      uiLocale: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ThemeSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.themeStyle)
      ..writeByte(1)
      ..write(obj.highContrast)
      ..writeByte(2)
      ..write(obj.uiLocale);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TtsSettingsAdapter extends TypeAdapter<TtsSettings> {
  @override
  final int typeId = 12;

  @override
  TtsSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TtsSettings(
      locale: fields[0] as String,
      rate: fields[1] as double,
      pitch: fields[2] as double,
      autoPlay: fields[3] as bool,
      onWrong: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TtsSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.locale)
      ..writeByte(1)
      ..write(obj.rate)
      ..writeByte(2)
      ..write(obj.pitch)
      ..writeByte(3)
      ..write(obj.autoPlay)
      ..writeByte(4)
      ..write(obj.onWrong);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TtsSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SrsSettingsAdapter extends TypeAdapter<SrsSettings> {
  @override
  final int typeId = 13;

  @override
  SrsSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SrsSettings(
      alphaStability: fields[0] as double,
      betaFailure: fields[1] as double,
      gammaInterval: fields[2] as double,
      maxIntervalDays: fields[3] as int,
      delayProfile: fields[4] as String,
      slowThreshold: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SrsSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.alphaStability)
      ..writeByte(1)
      ..write(obj.betaFailure)
      ..writeByte(2)
      ..write(obj.gammaInterval)
      ..writeByte(3)
      ..write(obj.maxIntervalDays)
      ..writeByte(4)
      ..write(obj.delayProfile)
      ..writeByte(5)
      ..write(obj.slowThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SrsSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AlgorithmSettingsAdapter extends TypeAdapter<AlgorithmSettings> {
  @override
  final int typeId = 14;

  @override
  AlgorithmSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlgorithmSettings(
      leechWordsPerSession: fields[0] as int,
      newCardRatio: fields[1] as double,
      dailyNewLimit: fields[2] as int,
      leechLapsesThreshold: fields[3] as int,
      leechIncludeMarked: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AlgorithmSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.leechWordsPerSession)
      ..writeByte(1)
      ..write(obj.newCardRatio)
      ..writeByte(2)
      ..write(obj.dailyNewLimit)
      ..writeByte(3)
      ..write(obj.leechLapsesThreshold)
      ..writeByte(4)
      ..write(obj.leechIncludeMarked);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AiSettingsAdapter extends TypeAdapter<AiSettings> {
  @override
  final int typeId = 15;

  @override
  AiSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiSettings(
      provider: fields[0] as String,
      defaultModel: fields[1] as String,
      openRouterApiKey: fields[2] as String,
      openRouterDefaultModel: fields[3] as String,
      aiStudioApiKey: fields[4] as String,
      aiStudioDefaultModel: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AiSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.provider)
      ..writeByte(1)
      ..write(obj.defaultModel)
      ..writeByte(2)
      ..write(obj.openRouterApiKey)
      ..writeByte(3)
      ..write(obj.openRouterDefaultModel)
      ..writeByte(4)
      ..write(obj.aiStudioApiKey)
      ..writeByte(5)
      ..write(obj.aiStudioDefaultModel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionSettings _$SessionSettingsFromJson(Map<String, dynamic> json) =>
    SessionSettings(
      selectedLevels:
          (json['selectedLevels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['A1'],
      wordsPerSession: (json['wordsPerSession'] as num?)?.toInt() ?? 20,
      timeLimitMs: (json['timeLimitMs'] as num?)?.toInt() ?? 0,
      orderPolicy: json['orderPolicy'] as String? ?? 'random',
      onlyLeeches: json['onlyLeeches'] as bool? ?? false,
      learningMode: json['learningMode'] as String? ?? 'standard',
    );

Map<String, dynamic> _$SessionSettingsToJson(SessionSettings instance) =>
    <String, dynamic>{
      'selectedLevels': instance.selectedLevels,
      'wordsPerSession': instance.wordsPerSession,
      'timeLimitMs': instance.timeLimitMs,
      'orderPolicy': instance.orderPolicy,
      'onlyLeeches': instance.onlyLeeches,
      'learningMode': instance.learningMode,
    };

ThemeSettings _$ThemeSettingsFromJson(Map<String, dynamic> json) =>
    ThemeSettings(
      themeStyle: json['themeStyle'] as String? ?? 'digitalism',
      highContrast: json['highContrast'] as bool? ?? false,
      uiLocale: json['uiLocale'] as String? ?? 'zh_CN',
    );

Map<String, dynamic> _$ThemeSettingsToJson(ThemeSettings instance) =>
    <String, dynamic>{
      'themeStyle': instance.themeStyle,
      'highContrast': instance.highContrast,
      'uiLocale': instance.uiLocale,
    };

TtsSettings _$TtsSettingsFromJson(Map<String, dynamic> json) => TtsSettings(
  locale: json['locale'] as String? ?? 'en-US',
  rate: (json['rate'] as num?)?.toDouble() ?? 0.5,
  pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
  autoPlay: json['autoPlay'] as bool? ?? true,
  onWrong: json['onWrong'] as bool? ?? true,
);

Map<String, dynamic> _$TtsSettingsToJson(TtsSettings instance) =>
    <String, dynamic>{
      'locale': instance.locale,
      'rate': instance.rate,
      'pitch': instance.pitch,
      'autoPlay': instance.autoPlay,
      'onWrong': instance.onWrong,
    };

SrsSettings _$SrsSettingsFromJson(Map<String, dynamic> json) => SrsSettings(
  alphaStability: (json['alphaStability'] as num?)?.toDouble() ?? 0.18,
  betaFailure: (json['betaFailure'] as num?)?.toDouble() ?? 1.2,
  gammaInterval: (json['gammaInterval'] as num?)?.toDouble() ?? 1.0,
  maxIntervalDays: (json['maxIntervalDays'] as num?)?.toInt() ?? 90,
  delayProfile: json['delayProfile'] as String? ?? 'standard',
  slowThreshold: (json['slowThreshold'] as num?)?.toDouble() ?? 1.5,
);

Map<String, dynamic> _$SrsSettingsToJson(SrsSettings instance) =>
    <String, dynamic>{
      'alphaStability': instance.alphaStability,
      'betaFailure': instance.betaFailure,
      'gammaInterval': instance.gammaInterval,
      'maxIntervalDays': instance.maxIntervalDays,
      'delayProfile': instance.delayProfile,
      'slowThreshold': instance.slowThreshold,
    };

AlgorithmSettings _$AlgorithmSettingsFromJson(
  Map<String, dynamic> json,
) => AlgorithmSettings(
  leechWordsPerSession: (json['leechWordsPerSession'] as num?)?.toInt() ?? 5,
  newCardRatio: (json['newCardRatio'] as num?)?.toDouble() ?? 0.3,
  dailyNewLimit: (json['dailyNewLimit'] as num?)?.toInt() ?? 50,
  leechLapsesThreshold: (json['leechLapsesThreshold'] as num?)?.toInt() ?? 2,
  leechIncludeMarked: json['leechIncludeMarked'] as bool? ?? true,
);

Map<String, dynamic> _$AlgorithmSettingsToJson(AlgorithmSettings instance) =>
    <String, dynamic>{
      'leechWordsPerSession': instance.leechWordsPerSession,
      'newCardRatio': instance.newCardRatio,
      'dailyNewLimit': instance.dailyNewLimit,
      'leechLapsesThreshold': instance.leechLapsesThreshold,
      'leechIncludeMarked': instance.leechIncludeMarked,
    };

AiSettings _$AiSettingsFromJson(Map<String, dynamic> json) => AiSettings(
  provider: json['provider'] as String? ?? 'openrouter',
  defaultModel: json['defaultModel'] as String? ?? '',
  openRouterApiKey: json['openRouterApiKey'] as String? ?? '',
  openRouterDefaultModel: json['openRouterDefaultModel'] as String? ?? '',
  aiStudioApiKey: json['aiStudioApiKey'] as String? ?? '',
  aiStudioDefaultModel: json['aiStudioDefaultModel'] as String? ?? '',
);

Map<String, dynamic> _$AiSettingsToJson(AiSettings instance) =>
    <String, dynamic>{
      'provider': instance.provider,
      'defaultModel': instance.defaultModel,
      'openRouterApiKey': instance.openRouterApiKey,
      'openRouterDefaultModel': instance.openRouterDefaultModel,
      'aiStudioApiKey': instance.aiStudioApiKey,
      'aiStudioDefaultModel': instance.aiStudioDefaultModel,
    };
