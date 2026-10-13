import '../../../models/word.dart';
import '../../memory/domain/recall_models.dart';

/// 内容层的稳定词条。旧 Word.id 只作为 legacyWordId 保留。
class Lexeme {
  final String stableId;
  final int legacyWordId;
  final String headword;
  final String lemma;
  final String level;
  final String contentVersion;

  const Lexeme({
    required this.stableId,
    required this.legacyWordId,
    required this.headword,
    required this.lemma,
    required this.level,
    required this.contentVersion,
  });

  factory Lexeme.fromLegacyWord(
    Word word, {
    String contentVersion = 'legacy-1',
  }) => Lexeme(
    stableId: 'legacy:${word.id}',
    legacyWordId: word.id,
    headword: word.headword,
    lemma: word.lemma,
    level: word.level,
    contentVersion: contentVersion,
  );

  Map<String, dynamic> toJson() => {
    'stableId': stableId,
    'legacyWordId': legacyWordId,
    'headword': headword,
    'lemma': lemma,
    'level': level,
    'contentVersion': contentVersion,
  };

  factory Lexeme.fromJson(Map<String, dynamic> json) => Lexeme(
    stableId: json['stableId'] as String,
    legacyWordId: (json['legacyWordId'] as num).toInt(),
    headword: json['headword'] as String? ?? '',
    lemma: json['lemma'] as String? ?? '',
    level: json['level'] as String? ?? '',
    contentVersion: json['contentVersion'] as String? ?? 'legacy-1',
  );
}

class Sense {
  final String id;
  final String lexemeId;
  final String partOfSpeech;
  final String definition;
  final List<String> examples;
  final String source;
  final String qualityStatus;

  const Sense({
    required this.id,
    required this.lexemeId,
    required this.partOfSpeech,
    required this.definition,
    this.examples = const [],
    this.source = 'legacy',
    this.qualityStatus = 'unreviewed',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'lexemeId': lexemeId,
    'partOfSpeech': partOfSpeech,
    'definition': definition,
    'examples': examples,
    'source': source,
    'qualityStatus': qualityStatus,
  };

  factory Sense.fromJson(Map<String, dynamic> json) => Sense(
    id: json['id'] as String,
    lexemeId: json['lexemeId'] as String,
    partOfSpeech: json['partOfSpeech'] as String? ?? '',
    definition: json['definition'] as String? ?? '',
    examples: (json['examples'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    source: json['source'] as String? ?? 'legacy',
    qualityStatus: json['qualityStatus'] as String? ?? 'unreviewed',
  );
}

class LearningItem {
  final String id;
  final String senseId;
  final LearningSkill skill;
  final String promptVariant;
  final bool enabled;

  const LearningItem({
    required this.id,
    required this.senseId,
    required this.skill,
    this.promptVariant = 'default',
    this.enabled = true,
  });

  static LearningItem meaningRecognition(String senseId) => LearningItem(
    id: '$senseId:meaning-recognition',
    senseId: senseId,
    skill: LearningSkill.meaningRecognition,
  );

  static LearningItem meaningRecall(String senseId) => LearningItem(
    id: '$senseId:meaning-recall',
    senseId: senseId,
    skill: LearningSkill.meaningRecall,
  );

  static LearningItem englishProduction(String senseId) => LearningItem(
    id: '$senseId:english-production',
    senseId: senseId,
    skill: LearningSkill.englishProduction,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'senseId': senseId,
    'skill': skill.name,
    'promptVariant': promptVariant,
    'enabled': enabled,
  };

  factory LearningItem.fromJson(Map<String, dynamic> json) => LearningItem(
    id: json['id'] as String,
    senseId: json['senseId'] as String,
    skill: LearningSkill.values.firstWhere(
      (value) => value.name == json['skill'],
      orElse: () => LearningSkill.meaningRecognition,
    ),
    promptVariant: json['promptVariant'] as String? ?? 'default',
    enabled: json['enabled'] as bool? ?? true,
  );
}

class LegacyLexiconMapper {
  const LegacyLexiconMapper();

  ({Lexeme lexeme, Sense sense}) mapWord(Word word) {
    final lexeme = Lexeme.fromLegacyWord(word);
    final sense = Sense(
      id: '${lexeme.stableId}:sense:primary',
      lexemeId: lexeme.stableId,
      partOfSpeech: word.pos,
      definition: word.primaryDefinition,
      examples: const [],
      source: 'assets/words.json',
      qualityStatus: 'legacy-unreviewed',
    );
    return (lexeme: lexeme, sense: sense);
  }

  List<LearningItem> defaultItemsFor(Sense sense) => [
    LearningItem.meaningRecognition(sense.id),
    LearningItem.meaningRecall(sense.id),
  ];
}
