import 'package:hive/hive.dart';

import '../features/memory/domain/learning_item_state.dart';
import 'attempt.dart';
import 'card_state.dart';

/// 一次已经进入长期记忆流水线的回忆事实。
///
/// `pending` 是写前日志状态；应用启动时会把 pending 事件的 resultingState
/// 重放到卡片，再标记为 committed，从而覆盖 Hive 多 box 写入之间的崩溃窗口。
@HiveType(typeId: 7)
class ReviewEvent {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String sessionId;
  @HiveField(2)
  final Attempt attempt;
  @HiveField(3)
  final int beforeRevision;
  @HiveField(4)
  final CardState resultingState;
  @HiveField(5)
  final String status;
  @HiveField(6)
  final String evaluationSource;
  @HiveField(7)
  final String taskType;
  @HiveField(8)
  final DateTime createdAt;
  @HiveField(9)
  final bool isDueReview;
  @HiveField(10)
  final bool independentRecall;
  @HiveField(11)
  final String rating;
  @HiveField(12)
  final bool answerRevealed;
  @HiveField(13)
  final bool hintUsed;
  @HiveField(14)
  final int activeDurationMs;
  @HiveField(15)
  final String skill;
  @HiveField(16)
  final String schedulerVersion;
  @HiveField(17)
  final String contentVersion;
  @HiveField(18)
  final int timeLimitMs;
  @HiveField(19)
  final String localDate;
  @HiveField(20)
  final String? shadowSchedulerVersion;
  @HiveField(21)
  final DateTime? shadowDueAt;
  @HiveField(22)
  final double? shadowStability;
  @HiveField(23)
  final double? shadowDifficulty;
  @HiveField(24)
  final double? shadowRetrievability;
  @HiveField(25)
  final String? learningItemId;
  @HiveField(26)
  final LearningItemState? resultingItemState;

  const ReviewEvent({
    required this.id,
    required this.sessionId,
    required this.attempt,
    required this.beforeRevision,
    required this.resultingState,
    required this.status,
    required this.evaluationSource,
    required this.taskType,
    required this.createdAt,
    this.isDueReview = false,
    this.independentRecall = false,
    this.rating = 'unknown',
    this.answerRevealed = false,
    this.hintUsed = false,
    this.activeDurationMs = 0,
    this.skill = 'meaningRecognition',
    this.schedulerVersion = 'legacy-srs-v1',
    this.contentVersion = 'legacy-v1',
    this.timeLimitMs = 2000,
    this.localDate = '',
    this.shadowSchedulerVersion,
    this.shadowDueAt,
    this.shadowStability,
    this.shadowDifficulty,
    this.shadowRetrievability,
    this.learningItemId,
    this.resultingItemState,
  });

  bool get isCommitted => status == 'committed';

  bool get isSuccessful =>
      rating == 'unknown' ? attempt.isCorrect : rating != 'forgot';

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'attempt': attempt.toJson(),
    'beforeRevision': beforeRevision,
    'resultingState': resultingState.toJson(),
    'status': status,
    'evaluationSource': evaluationSource,
    'taskType': taskType,
    'createdAt': createdAt.toIso8601String(),
    'isDueReview': isDueReview,
    'independentRecall': independentRecall,
    'rating': rating,
    'answerRevealed': answerRevealed,
    'hintUsed': hintUsed,
    'activeDurationMs': activeDurationMs,
    'skill': skill,
    'schedulerVersion': schedulerVersion,
    'contentVersion': contentVersion,
    'timeLimitMs': timeLimitMs,
    'localDate': localDate,
    'shadowSchedulerVersion': shadowSchedulerVersion,
    'shadowDueAt': shadowDueAt?.toIso8601String(),
    'shadowStability': shadowStability,
    'shadowDifficulty': shadowDifficulty,
    'shadowRetrievability': shadowRetrievability,
    'learningItemId': learningItemId,
    'resultingItemState': resultingItemState?.toJson(),
  };

  factory ReviewEvent.fromJson(Map<String, dynamic> json) => ReviewEvent(
    id: json['id'] as String,
    sessionId: json['sessionId'] as String? ?? '',
    attempt: Attempt.fromJson(
      Map<String, dynamic>.from(json['attempt'] as Map),
    ),
    beforeRevision: (json['beforeRevision'] as num?)?.toInt() ?? 0,
    resultingState: CardState.fromJson(
      Map<String, dynamic>.from(json['resultingState'] as Map),
    ),
    status: json['status'] as String? ?? 'committed',
    evaluationSource: json['evaluationSource'] as String? ?? 'legacy',
    taskType: json['taskType'] as String? ?? 'recognition',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isDueReview: json['isDueReview'] as bool? ?? false,
    independentRecall: json['independentRecall'] as bool? ?? false,
    rating: json['rating'] as String? ?? 'unknown',
    answerRevealed: json['answerRevealed'] as bool? ?? false,
    hintUsed: json['hintUsed'] as bool? ?? false,
    activeDurationMs: (json['activeDurationMs'] as num?)?.toInt() ?? 0,
    skill: json['skill'] as String? ?? 'meaningRecognition',
    schedulerVersion: json['schedulerVersion'] as String? ?? 'legacy-srs-v1',
    contentVersion: json['contentVersion'] as String? ?? 'legacy-v1',
    timeLimitMs: (json['timeLimitMs'] as num?)?.toInt() ?? 2000,
    localDate: json['localDate'] as String? ?? '',
    shadowSchedulerVersion: json['shadowSchedulerVersion'] as String?,
    shadowDueAt: DateTime.tryParse(json['shadowDueAt'] as String? ?? ''),
    shadowStability: (json['shadowStability'] as num?)?.toDouble(),
    shadowDifficulty: (json['shadowDifficulty'] as num?)?.toDouble(),
    shadowRetrievability: (json['shadowRetrievability'] as num?)?.toDouble(),
    learningItemId: json['learningItemId'] as String?,
    resultingItemState: json['resultingItemState'] is Map
        ? LearningItemState.fromJson(
            Map<String, dynamic>.from(json['resultingItemState'] as Map),
          )
        : null,
  );

  ReviewEvent copyWith({String? status}) => ReviewEvent(
    id: id,
    sessionId: sessionId,
    attempt: attempt,
    beforeRevision: beforeRevision,
    resultingState: resultingState,
    status: status ?? this.status,
    evaluationSource: evaluationSource,
    taskType: taskType,
    createdAt: createdAt,
    isDueReview: isDueReview,
    independentRecall: independentRecall,
    rating: rating,
    answerRevealed: answerRevealed,
    hintUsed: hintUsed,
    activeDurationMs: activeDurationMs,
    skill: skill,
    schedulerVersion: schedulerVersion,
    contentVersion: contentVersion,
    timeLimitMs: timeLimitMs,
    localDate: localDate,
    shadowSchedulerVersion: shadowSchedulerVersion,
    shadowDueAt: shadowDueAt,
    shadowStability: shadowStability,
    shadowDifficulty: shadowDifficulty,
    shadowRetrievability: shadowRetrievability,
    learningItemId: learningItemId,
    resultingItemState: resultingItemState,
  );

  static String idFor({required String sessionId, required Attempt attempt}) =>
      '$sessionId:${attempt.wordId}:${attempt.timestamp.microsecondsSinceEpoch}:'
      '${attempt.result.name}:${attempt.chosenIndex}:${attempt.correctIndex}';
}

class ReviewEventAdapter extends TypeAdapter<ReviewEvent> {
  @override
  final int typeId = 7;

  @override
  ReviewEvent read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (var i = 0, count = reader.readByte(); i < count; i++)
        reader.readByte(): reader.read(),
    };
    return ReviewEvent(
      id: fields[0] as String,
      sessionId: fields[1] as String,
      attempt: fields[2] as Attempt,
      beforeRevision: fields[3] as int? ?? 0,
      resultingState: fields[4] as CardState,
      status: fields[5] as String? ?? 'committed',
      evaluationSource: fields[6] as String? ?? 'objective',
      taskType: fields[7] as String? ?? 'recognition',
      createdAt: fields[8] as DateTime? ?? DateTime.now(),
      isDueReview: fields[9] as bool? ?? false,
      independentRecall: fields[10] as bool? ?? false,
      rating: fields[11] as String? ?? 'unknown',
      answerRevealed: fields[12] as bool? ?? false,
      hintUsed: fields[13] as bool? ?? false,
      activeDurationMs: (fields[14] as num?)?.toInt() ?? 0,
      skill: fields[15] as String? ?? 'meaningRecognition',
      schedulerVersion: fields[16] as String? ?? 'legacy-srs-v1',
      contentVersion: fields[17] as String? ?? 'legacy-v1',
      timeLimitMs: (fields[18] as num?)?.toInt() ?? 2000,
      localDate: fields[19] as String? ?? '',
      shadowSchedulerVersion: fields[20] as String?,
      shadowDueAt: fields[21] as DateTime?,
      shadowStability: (fields[22] as num?)?.toDouble(),
      shadowDifficulty: (fields[23] as num?)?.toDouble(),
      shadowRetrievability: (fields[24] as num?)?.toDouble(),
      learningItemId: fields[25] as String?,
      resultingItemState: fields[26] is Map
          ? LearningItemState.fromJson(
              Map<String, dynamic>.from(fields[26] as Map),
            )
          : fields[26] as LearningItemState?,
    );
  }

  @override
  void write(BinaryWriter writer, ReviewEvent obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.attempt)
      ..writeByte(3)
      ..write(obj.beforeRevision)
      ..writeByte(4)
      ..write(obj.resultingState)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.evaluationSource)
      ..writeByte(7)
      ..write(obj.taskType)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isDueReview)
      ..writeByte(10)
      ..write(obj.independentRecall)
      ..writeByte(11)
      ..write(obj.rating)
      ..writeByte(12)
      ..write(obj.answerRevealed)
      ..writeByte(13)
      ..write(obj.hintUsed)
      ..writeByte(14)
      ..write(obj.activeDurationMs)
      ..writeByte(15)
      ..write(obj.skill)
      ..writeByte(16)
      ..write(obj.schedulerVersion)
      ..writeByte(17)
      ..write(obj.contentVersion)
      ..writeByte(18)
      ..write(obj.timeLimitMs)
      ..writeByte(19)
      ..write(obj.localDate)
      ..writeByte(20)
      ..write(obj.shadowSchedulerVersion)
      ..writeByte(21)
      ..write(obj.shadowDueAt)
      ..writeByte(22)
      ..write(obj.shadowStability)
      ..writeByte(23)
      ..write(obj.shadowDifficulty)
      ..writeByte(24)
      ..write(obj.shadowRetrievability)
      ..writeByte(25)
      ..write(obj.learningItemId)
      ..writeByte(26)
      ..write(obj.resultingItemState?.toJson());
  }
}
