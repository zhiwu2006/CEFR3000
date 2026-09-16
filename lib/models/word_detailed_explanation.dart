class WordDetailedExplanation {
  final String ipa;
  final String shortMeaning;
  final String definitionEn;
  final String exampleEn;
  final String exampleCn;
  final String morphologyRoot;
  final String morphologyAffixes;
  final List<String> wordFamily;
  final List<String> synonyms;
  final List<String> antonyms;
  final String nuance;
  final List<String> collocations;
  final String mnemonic;
  final String? error;

  const WordDetailedExplanation({
    required this.ipa,
    required this.shortMeaning,
    required this.definitionEn,
    required this.exampleEn,
    required this.exampleCn,
    required this.morphologyRoot,
    required this.morphologyAffixes,
    required this.wordFamily,
    required this.synonyms,
    required this.antonyms,
    required this.nuance,
    required this.collocations,
    required this.mnemonic,
    this.error,
  });

  factory WordDetailedExplanation.fromJson(Map<String, dynamic> json) {
    final example = json['example'];
    final exampleEn = example is Map
        ? example['en']?.toString()
        : json['example_en']?.toString();
    final exampleCn = example is Map
        ? example['cn']?.toString()
        : json['example_cn']?.toString();
    final morphology = json['morphology'];
    final morphRoot = morphology is Map
        ? morphology['root']?.toString()
        : json['morphology_root']?.toString();
    final morphAffixes = morphology is Map
        ? morphology['affixes']?.toString()
        : json['morphology_affixes']?.toString();
    return WordDetailedExplanation(
      ipa: json['ipa']?.toString() ?? '',
      shortMeaning: json['short_meaning']?.toString() ?? '',
      definitionEn: json['definition_en']?.toString() ?? '',
      exampleEn: exampleEn ?? '',
      exampleCn: exampleCn ?? '',
      morphologyRoot: morphRoot ?? '',
      morphologyAffixes: morphAffixes ?? '',
      wordFamily: _readList(json['word_family']),
      synonyms: _readList(json['synonyms']),
      antonyms: _readList(json['antonyms']),
      nuance: json['nuance']?.toString() ?? '',
      collocations: _readList(json['collocations']),
      mnemonic: json['mnemonic']?.toString() ?? '',
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ipa': ipa,
    'short_meaning': shortMeaning,
    'definition_en': definitionEn,
    'example': {'en': exampleEn, 'cn': exampleCn},
    'morphology': {'root': morphologyRoot, 'affixes': morphologyAffixes},
    'word_family': wordFamily,
    'synonyms': synonyms,
    'antonyms': antonyms,
    'nuance': nuance,
    'collocations': collocations,
    'mnemonic': mnemonic,
    if (error != null) 'error': error,
  };

  static List<String> _readList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }
}
