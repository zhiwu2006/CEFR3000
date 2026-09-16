import '../../../models/word.dart';
import '../../memory/domain/recall_models.dart';
import 'lexicon_models.dart';

/// 内容资格的置信级别。题型可以使用传统词库降级，但必须把降级标记
/// 传给学习事件，避免把未经审核的素材伪装成高质量题目。
enum ContentConfidence { verified, legacyFallback }

enum ContentEligibilityReason {
  qualified,
  missingHeadword,
  missingDefinition,
  missingContext,
  legacyContent,
}

class ContentTaskEligibility {
  final LearningSkill skill;
  final bool enabled;
  final ContentConfidence? confidence;
  final ContentEligibilityReason reason;
  final String prompt;
  final List<String> acceptedAnswers;

  const ContentTaskEligibility({
    required this.skill,
    required this.enabled,
    required this.confidence,
    required this.reason,
    required this.prompt,
    this.acceptedAnswers = const [],
  });

  bool get requiresSelfCheck => confidence == ContentConfidence.legacyFallback;

  String get reasonLabel => switch (reason) {
    ContentEligibilityReason.qualified => '已审核内容',
    ContentEligibilityReason.missingHeadword => '缺少英文词条',
    ContentEligibilityReason.missingDefinition => '缺少可靠释义',
    ContentEligibilityReason.missingContext => '缺少明确语境',
    ContentEligibilityReason.legacyContent => '传统词库降级练习',
  };
}

/// 统一的题型资格检查和英文答案规范化规则。
///
/// 识别和中文回忆可以使用传统词库；英文产出默认要求审核过的义项和
/// 例句。迁移后的旧词库允许用户主动进入“基础产出练习”，但结果会被
/// 标记为 legacyFallback，不能当作内容审核通过的客观证据。
class ContentEligibility {
  const ContentEligibility._();

  static ContentTaskEligibility productionForSense(
    Sense sense, {
    required String headword,
    String? lemma,
    bool allowLegacyFallback = false,
  }) {
    final word = headword.trim();
    final definition = sense.definition.trim();
    if (word.isEmpty) {
      return const ContentTaskEligibility(
        skill: LearningSkill.englishProduction,
        enabled: false,
        confidence: null,
        reason: ContentEligibilityReason.missingHeadword,
        prompt: '',
      );
    }
    if (definition.isEmpty) {
      return ContentTaskEligibility(
        skill: LearningSkill.englishProduction,
        enabled: false,
        confidence: null,
        reason: ContentEligibilityReason.missingDefinition,
        prompt: word,
      );
    }
    if (sense.qualityStatus == 'reviewed' && sense.examples.isNotEmpty) {
      return ContentTaskEligibility(
        skill: LearningSkill.englishProduction,
        enabled: true,
        confidence: ContentConfidence.verified,
        reason: ContentEligibilityReason.qualified,
        prompt: definition,
        acceptedAnswers: _answers(word, lemma),
      );
    }
    if (allowLegacyFallback) {
      return ContentTaskEligibility(
        skill: LearningSkill.englishProduction,
        enabled: true,
        confidence: ContentConfidence.legacyFallback,
        reason: ContentEligibilityReason.legacyContent,
        prompt: definition,
        acceptedAnswers: _answers(word, lemma),
      );
    }
    return ContentTaskEligibility(
      skill: LearningSkill.englishProduction,
      enabled: false,
      confidence: null,
      reason: ContentEligibilityReason.missingContext,
      prompt: definition,
      acceptedAnswers: _answers(word, lemma),
    );
  }

  static ContentTaskEligibility productionForWord(
    Word word, {
    bool allowLegacyFallback = false,
  }) {
    final sense = Sense(
      id: word.primarySenseId,
      lexemeId: word.stableId,
      partOfSpeech: word.pos,
      definition: word.primaryDefinition,
      source: 'legacy-word',
      qualityStatus: 'legacy-unreviewed',
    );
    return productionForSense(
      sense,
      headword: word.headword,
      lemma: word.lemma,
      allowLegacyFallback: allowLegacyFallback,
    );
  }

  /// 用于输入比较和本地导出，不改变原始用户答案。
  static String normalizeAnswer(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[’']"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool matches(String answer, Iterable<String> acceptedAnswers) {
    final normalized = normalizeAnswer(answer);
    if (normalized.isEmpty) return false;
    return acceptedAnswers.any(
      (expected) => normalized == normalizeAnswer(expected),
    );
  }

  static List<String> _answers(String headword, String? lemma) => {
    headword.trim(),
    if (lemma != null && lemma.trim().isNotEmpty) lemma.trim(),
  }.toList(growable: false);
}
