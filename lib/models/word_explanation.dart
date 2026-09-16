class WordExplanation {
  final String ipa;
  final String shortMeaning;
  final String definitionEn;
  final String exampleEn;
  final String exampleCn;
  final String nuance;
  final List<String> collocations;
  final String? error;

  const WordExplanation({
    required this.ipa,
    required this.shortMeaning,
    required this.definitionEn,
    required this.exampleEn,
    required this.exampleCn,
    required this.nuance,
    required this.collocations,
    this.error,
  });

  factory WordExplanation.fromJson(Map<String, dynamic> json) {
    final example = json['example'];
    final exampleEn = example is Map
        ? example['en']?.toString()
        : json['example_en']?.toString();
    final exampleCn = example is Map
        ? example['cn']?.toString()
        : json['example_cn']?.toString();
    return WordExplanation(
      ipa: json['ipa']?.toString() ?? '',
      shortMeaning: json['short_meaning']?.toString() ?? '',
      definitionEn: json['definition_en']?.toString() ?? '',
      exampleEn: exampleEn ?? '',
      exampleCn: exampleCn ?? '',
      nuance: json['nuance']?.toString() ?? '',
      collocations: _readList(json['collocations']),
      error: json['error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ipa': ipa,
    'short_meaning': shortMeaning,
    'definition_en': definitionEn,
    'example': {'en': exampleEn, 'cn': exampleCn},
    'nuance': nuance,
    'collocations': collocations,
    if (error != null) 'error': error,
  };

  static List<String> _readList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }
}
