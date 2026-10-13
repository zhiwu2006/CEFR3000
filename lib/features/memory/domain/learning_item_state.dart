import '../../../models/card_state.dart';
import 'recall_models.dart';

/// Memory state keyed by a stable LearningItem rather than a legacy word ID.
///
/// The recognition CardState remains the compatibility projection for the old
/// UI. Production, listening and spelling can use this model without
/// overwriting recognition evidence.
class LearningItemState {
  final String itemId;
  final String lexemeId;
  final LearningSkill skill;
  final double stability;
  final double difficulty;
  final DateTime dueAt;
  final DateTime lastReviewedAt;
  final int lapses;
  final int rtP50;
  final int longTermReviews;
  final int revision;
  final String schedulerVersion;
  final String evidenceOrigin;

  const LearningItemState({
    required this.itemId,
    required this.lexemeId,
    required this.skill,
    required this.stability,
    required this.difficulty,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.lapses,
    required this.rtP50,
    required this.longTermReviews,
    required this.revision,
    required this.schedulerVersion,
    required this.evidenceOrigin,
  });

  factory LearningItemState.newItem({
    required String itemId,
    required String lexemeId,
    required LearningSkill skill,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return LearningItemState(
      itemId: itemId,
      lexemeId: lexemeId,
      skill: skill,
      stability: 1.5,
      difficulty: 2.5,
      dueAt: timestamp.add(const Duration(days: 1)),
      lastReviewedAt: timestamp,
      lapses: 0,
      rtP50: 0,
      longTermReviews: 0,
      revision: 0,
      schedulerVersion: 'legacy-srs-v1',
      evidenceOrigin: 'unreviewed',
    );
  }

  factory LearningItemState.fromJson(
    Map<String, dynamic> json,
  ) => LearningItemState(
    itemId: json['itemId'] as String,
    lexemeId: json['lexemeId'] as String,
    skill: LearningSkill.values.firstWhere(
      (value) => value.name == json['skill'],
      orElse: () => LearningSkill.meaningRecognition,
    ),
    stability: (json['stability'] as num?)?.toDouble() ?? 1.5,
    difficulty: (json['difficulty'] as num?)?.toDouble() ?? 2.5,
    dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
    lastReviewedAt:
        DateTime.tryParse(json['lastReviewedAt'] as String? ?? '') ??
        DateTime.now(),
    lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    rtP50: (json['rtP50'] as num?)?.toInt() ?? 0,
    longTermReviews: (json['longTermReviews'] as num?)?.toInt() ?? 0,
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    schedulerVersion: json['schedulerVersion'] as String? ?? 'legacy-srs-v1',
    evidenceOrigin: json['evidenceOrigin'] as String? ?? 'unreviewed',
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'lexemeId': lexemeId,
    'skill': skill.name,
    'stability': stability,
    'difficulty': difficulty,
    'dueAt': dueAt.toIso8601String(),
    'lastReviewedAt': lastReviewedAt.toIso8601String(),
    'lapses': lapses,
    'rtP50': rtP50,
    'longTermReviews': longTermReviews,
    'revision': revision,
    'schedulerVersion': schedulerVersion,
    'evidenceOrigin': evidenceOrigin,
  };

  bool get isDue => !dueAt.isAfter(DateTime.now());

  bool get isMastered => stability >= 16 && longTermReviews >= 2;

  LearningItemState copyWith({
    double? stability,
    double? difficulty,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? lapses,
    int? rtP50,
    int? longTermReviews,
    int? revision,
    String? schedulerVersion,
    String? evidenceOrigin,
  }) => LearningItemState(
    itemId: itemId,
    lexemeId: lexemeId,
    skill: skill,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    dueAt: dueAt ?? this.dueAt,
    lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    lapses: lapses ?? this.lapses,
    rtP50: rtP50 ?? this.rtP50,
    longTermReviews: longTermReviews ?? this.longTermReviews,
    revision: revision ?? this.revision,
    schedulerVersion: schedulerVersion ?? this.schedulerVersion,
    evidenceOrigin: evidenceOrigin ?? this.evidenceOrigin,
  );

  /// Compatibility projection used only when an old API needs CardState.
  CardState toCardState(int legacyWordId) => CardState(
    wordId: legacyWordId,
    stability: stability,
    difficulty: difficulty,
    due: dueAt,
    lapses: lapses,
    rtP50: rtP50,
    flags: 0,
    lastReview: lastReviewedAt,
    longTermReviews: longTermReviews,
    revision: revision,
  );

  static LearningItemState fromCardState({
    required CardState state,
    required String itemId,
    required String lexemeId,
    required LearningSkill skill,
    String evidenceOrigin = 'legacy',
  }) => LearningItemState(
    itemId: itemId,
    lexemeId: lexemeId,
    skill: skill,
    stability: state.stability,
    difficulty: state.difficulty,
    dueAt: state.due,
    lastReviewedAt: state.lastReview,
    lapses: state.lapses,
    rtP50: state.rtP50,
    longTermReviews: state.longTermReviews,
    revision: state.revision,
    schedulerVersion: 'legacy-srs-v1',
    evidenceOrigin: evidenceOrigin,
  );
}
