import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../features/assistance/data/ai_explanation_cache.dart';

const _aiContentVersion = 'legacy-v1';
const _aiTemplateVersion = 'explain-template-v2';

class WordExplanationService {
  final HttpClient _client;

  WordExplanationService({HttpClient? client}) : _client = client ?? HttpClient();

  Future<WordExplanation> getExplanation({
    required Word word,
    required AppSettings settings,
    required SharedPreferences prefs,
  }) async {
    final cache = AiExplanationCache(prefs);
    final cacheKey = _buildCacheKey(word, settings);
    final cached = cache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          return WordExplanation.fromJson(decoded);
        }
      } catch (_) {
        // fall through to fetch
      }
    }

    final explanation = await _fetchExplanation(word, settings);
    if (explanation.error == null &&
        (explanation.shortMeaning.isNotEmpty ||
            explanation.definitionEn.isNotEmpty ||
            explanation.exampleEn.isNotEmpty ||
            explanation.exampleCn.isNotEmpty ||
            explanation.nuance.isNotEmpty)) {
      await cache.put(
        key: cacheKey,
        payload: jsonEncode(explanation.toJson()),
        contentVersion: _aiContentVersion,
        templateVersion: _aiTemplateVersion,
        provider: settings.aiProvider,
        model: settings.aiDefaultModel,
      );
    }
    return explanation;
  }

  Future<WordDetailedExplanation> getDetailedExplanation({
    required Word word,
    required AppSettings settings,
    required SharedPreferences prefs,
  }) async {
    final cache = AiExplanationCache(prefs);
    final cacheKey = _buildDetailedCacheKey(word, settings);
    final cached = cache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          return WordDetailedExplanation.fromJson(decoded);
        }
      } catch (_) {}
    }

    final explanation = await _fetchDetailedExplanation(word, settings);
    if (explanation.error == null &&
        (explanation.shortMeaning.isNotEmpty ||
            explanation.exampleEn.isNotEmpty ||
            explanation.exampleCn.isNotEmpty ||
            explanation.mnemonic.isNotEmpty ||
            explanation.definitionEn.isNotEmpty)) {
      await cache.put(
        key: cacheKey,
        payload: jsonEncode(explanation.toJson()),
        contentVersion: _aiContentVersion,
        templateVersion: '$_aiTemplateVersion:detailed',
        provider: settings.aiProvider,
        model: settings.aiDefaultModel,
      );
    }
    return explanation;
  }

  String _buildCacheKey(Word word, AppSettings settings) {
    return '${word.stableId}:${settings.uiLocale}:$_aiContentVersion:'
        '$_aiTemplateVersion:${settings.aiProvider}:${settings.aiDefaultModel}';
  }

  String _buildDetailedCacheKey(Word word, AppSettings settings) {
    return '${word.stableId}:${settings.uiLocale}:$_aiContentVersion:'
        '$_aiTemplateVersion:detailed:${settings.aiProvider}:'
        '${settings.aiDefaultModel}';
  }

  Future<WordExplanation> _fetchExplanation(
    Word word,
    AppSettings settings,
  ) async {
    final provider = settings.aiProvider;
    if (provider == 'openrouter') {
      if (settings.openRouterApiKey.trim().isEmpty) {
        return const WordExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          nuance: '',
          collocations: [],
          error: 'missing_api_key',
        );
      }
      return _fetchFromOpenRouter(word, settings);
    }

    if (settings.aiStudioApiKey.trim().isEmpty) {
      return const WordExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        nuance: '',
        collocations: [],
        error: 'missing_api_key',
      );
    }
    return _fetchFromAiStudio(word, settings);
  }

  Future<WordDetailedExplanation> _fetchDetailedExplanation(
    Word word,
    AppSettings settings,
  ) async {
    final provider = settings.aiProvider;
    if (provider == 'openrouter') {
      if (settings.openRouterApiKey.trim().isEmpty) {
        return const WordDetailedExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          morphologyRoot: '',
          morphologyAffixes: '',
          wordFamily: [],
          synonyms: [],
          antonyms: [],
          nuance: '',
          collocations: [],
          mnemonic: '',
          error: 'missing_api_key',
        );
      }
      return _fetchDetailedFromOpenRouter(word, settings);
    }

    if (settings.aiStudioApiKey.trim().isEmpty) {
      return const WordDetailedExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        morphologyRoot: '',
        morphologyAffixes: '',
        wordFamily: [],
        synonyms: [],
        antonyms: [],
        nuance: '',
        collocations: [],
        mnemonic: '',
        error: 'missing_api_key',
      );
    }
    return _fetchDetailedFromAiStudio(word, settings);
  }

  Future<WordExplanation> _fetchFromOpenRouter(
    Word word,
    AppSettings settings,
  ) async {
    try {
      final request = await _client
          .postUrl(Uri.parse('https://openrouter.ai/api/v1/chat/completions'))
          .timeout(const Duration(seconds: 10));
      request.headers.set(
        'Authorization',
        'Bearer ${settings.openRouterApiKey}',
      );
      request.headers.set('Content-Type', 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': settings.aiDefaultModel,
            'messages': [
              {'role': 'system', 'content': _buildSystemPrompt()},
              {'role': 'user', 'content': _buildUserPrompt(word)},
            ],
            'max_tokens': 220,
            'temperature': 0.2,
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'OpenRouter explain failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        debugPrint(body.length > 400 ? body.substring(0, 400) : body);
        return WordExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          nuance: '',
          collocations: [],
          error: 'http_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(body);
      String? content;
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final message = first['message'];
            if (message is Map) {
              final value = message['content'];
              if (value != null) content = value.toString();
            }
          }
        }
      }
      return _parseExplanation(content);
    } catch (e) {
      debugPrint('OpenRouter explain exception: $e');
      return const WordExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        nuance: '',
        collocations: [],
        error: 'request_failed',
      );
    }
  }

  Future<WordExplanation> _fetchFromAiStudio(
    Word word,
    AppSettings settings,
  ) async {
    try {
      final model = _normalizeAiStudioModel(settings.aiDefaultModel);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/$model:generateContent?key=${settings.aiStudioApiKey}',
      );
      final request = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set('Content-Type', 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _buildSystemPrompt()},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': _buildUserPrompt(word)},
                ],
              },
            ],
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'AI Studio explain failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        debugPrint(body.length > 400 ? body.substring(0, 400) : body);
        return WordExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          nuance: '',
          collocations: [],
          error: 'http_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(body);
      String? content;
      if (decoded is Map<String, dynamic>) {
        final candidates = decoded['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map) {
            final contentNode = first['content'];
            if (contentNode is Map) {
              final parts = contentNode['parts'];
              if (parts is List && parts.isNotEmpty) {
                final part = parts.first;
                if (part is Map) {
                  final value = part['text'];
                  if (value != null) content = value.toString();
                }
              }
            }
          }
        }
      }
      return _parseExplanation(content);
    } catch (e) {
      debugPrint('AI Studio explain exception: $e');
      return const WordExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        nuance: '',
        collocations: [],
        error: 'request_failed',
      );
    }
  }

  Future<WordDetailedExplanation> _fetchDetailedFromOpenRouter(
    Word word,
    AppSettings settings,
  ) async {
    try {
      final request = await _client
          .postUrl(Uri.parse('https://openrouter.ai/api/v1/chat/completions'))
          .timeout(const Duration(seconds: 10));
      request.headers.set(
        'Authorization',
        'Bearer ${settings.openRouterApiKey}',
      );
      request.headers.set('Content-Type', 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': settings.aiDefaultModel,
            'messages': [
              {'role': 'system', 'content': _buildDetailedSystemPrompt()},
              {'role': 'user', 'content': _buildDetailedUserPrompt(word)},
            ],
            'max_tokens': 320,
            'temperature': 0.2,
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'OpenRouter detailed failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        debugPrint(body.length > 400 ? body.substring(0, 400) : body);
        return WordDetailedExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          morphologyRoot: '',
          morphologyAffixes: '',
          wordFamily: [],
          synonyms: [],
          antonyms: [],
          nuance: '',
          collocations: [],
          mnemonic: '',
          error: 'http_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(body);
      String? content;
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map) {
            final message = first['message'];
            if (message is Map) {
              final value = message['content'];
              if (value != null) content = value.toString();
            }
          }
        }
      }
      return _parseDetailedExplanation(content);
    } catch (e) {
      debugPrint('OpenRouter detailed exception: $e');
      return const WordDetailedExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        morphologyRoot: '',
        morphologyAffixes: '',
        wordFamily: [],
        synonyms: [],
        antonyms: [],
        nuance: '',
        collocations: [],
        mnemonic: '',
        error: 'request_failed',
      );
    }
  }

  Future<WordDetailedExplanation> _fetchDetailedFromAiStudio(
    Word word,
    AppSettings settings,
  ) async {
    try {
      final model = _normalizeAiStudioModel(settings.aiDefaultModel);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/$model:generateContent?key=${settings.aiStudioApiKey}',
      );
      final request = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set('Content-Type', 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _buildDetailedSystemPrompt()},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': _buildDetailedUserPrompt(word)},
                ],
              },
            ],
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'AI Studio detailed failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        debugPrint(body.length > 400 ? body.substring(0, 400) : body);
        return WordDetailedExplanation(
          ipa: '',
          shortMeaning: '',
          definitionEn: '',
          exampleEn: '',
          exampleCn: '',
          morphologyRoot: '',
          morphologyAffixes: '',
          wordFamily: [],
          synonyms: [],
          antonyms: [],
          nuance: '',
          collocations: [],
          mnemonic: '',
          error: 'http_${response.statusCode}',
        );
      }

      final decoded = jsonDecode(body);
      String? content;
      if (decoded is Map<String, dynamic>) {
        final candidates = decoded['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map) {
            final contentNode = first['content'];
            if (contentNode is Map) {
              final parts = contentNode['parts'];
              if (parts is List && parts.isNotEmpty) {
                final part = parts.first;
                if (part is Map) {
                  final value = part['text'];
                  if (value != null) content = value.toString();
                }
              }
            }
          }
        }
      }
      return _parseDetailedExplanation(content);
    } catch (e) {
      debugPrint('AI Studio detailed exception: $e');
      return const WordDetailedExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        morphologyRoot: '',
        morphologyAffixes: '',
        wordFamily: [],
        synonyms: [],
        antonyms: [],
        nuance: '',
        collocations: [],
        mnemonic: '',
        error: 'request_failed',
      );
    }
  }

  String _normalizeAiStudioModel(String model) {
    if (model.startsWith('models/')) return model;
    return 'models/$model';
  }

  WordExplanation _parseExplanation(String? content) {
    if (content == null || content.trim().isEmpty) {
      return const WordExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        nuance: '',
        collocations: [],
        error: 'empty_response',
      );
    }

    final trimmed = content.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return WordExplanation.fromJson(decoded);
      }
    } catch (_) {
      // fallback to extracting JSON object
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = trimmed.substring(start, end + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map<String, dynamic>) {
          return WordExplanation.fromJson(decoded);
        }
      } catch (_) {}
    }

    return const WordExplanation(
      ipa: '',
      shortMeaning: '',
      definitionEn: '',
      exampleEn: '',
      exampleCn: '',
      nuance: '',
      collocations: [],
      error: 'invalid_response',
    );
  }

  WordDetailedExplanation _parseDetailedExplanation(String? content) {
    if (content == null || content.trim().isEmpty) {
      return const WordDetailedExplanation(
        ipa: '',
        shortMeaning: '',
        definitionEn: '',
        exampleEn: '',
        exampleCn: '',
        morphologyRoot: '',
        morphologyAffixes: '',
        wordFamily: [],
        synonyms: [],
        antonyms: [],
        nuance: '',
        collocations: [],
        mnemonic: '',
        error: 'empty_response',
      );
    }

    final trimmed = content.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return WordDetailedExplanation.fromJson(decoded);
      }
    } catch (_) {}

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = trimmed.substring(start, end + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map<String, dynamic>) {
          return WordDetailedExplanation.fromJson(decoded);
        }
      } catch (_) {}
    }

    return const WordDetailedExplanation(
      ipa: '',
      shortMeaning: '',
      definitionEn: '',
      exampleEn: '',
      exampleCn: '',
      morphologyRoot: '',
      morphologyAffixes: '',
      wordFamily: [],
      synonyms: [],
      antonyms: [],
      nuance: '',
      collocations: [],
      mnemonic: '',
      error: 'invalid_response',
    );
  }

  String _buildSystemPrompt() {
    return 'You are an expert Lexicographer and ESL Tutor specializing in cognitive linguistics for Chinese learners. '
        'Your task is to analyze an English word and return a strictly valid JSON object containing comprehensive learning data.\n'
        'Guiding Principles:\n'
        '1. Contextual Alignment: Strictly align the definition, example, and collocations with the specific Part of Speech (POS) and Chinese definitions provided by the user. Do not discuss other meanings unless relevant for differentiation.\n'
        '2. Scientific Accuracy: Etymology should focus on the root meaning to aid memory.\n'
        '3. Comprehensible Input: Examples must be authentic, context-rich, and suitable for the learner\'s level (CEFR alignment).\n'
        '4. Differentiation: Synonyms must include a very brief note on why they differ (nuance).\n'
        'Output Format:\n'
        '- Return ONLY the raw JSON object.\n'
        '- Do NOT use Markdown code blocks.\n'
        '- Ensure all Chinese text is Simplified Chinese.';
  }

  String _buildDetailedSystemPrompt() {
    return 'You are an expert Lexicographer and ESL Tutor specializing in cognitive linguistics for Chinese learners. '
        'Your task is to analyze an English word and return a strictly valid JSON object containing comprehensive learning data.\n'
        'Guiding Principles:\n'
        '1. Contextual Alignment: Strictly align the definition, example, and collocations with the specific Part of Speech (POS) and Chinese definitions provided by the user. Do not discuss other meanings unless relevant for differentiation.\n'
        '2. Scientific Accuracy: Etymology should focus on the root meaning to aid memory.\n'
        '3. Comprehensible Input: Examples must be authentic, context-rich, and suitable for the learner\'s level (CEFR alignment).\n'
        '4. Differentiation: Synonyms must include a very brief note on why they differ (nuance).\n'
        'Output Format:\n'
        '- Return ONLY the raw JSON object.\n'
        '- Do NOT use Markdown code blocks.\n'
        '- Ensure all Chinese text is Simplified Chinese.';
  }

  String _buildUserPrompt(Word word) {
    final defs = word.cnDefs.join('；');
    return 'Analyze the following word for a Chinese learner:\n\n'
        'Word: ${word.headword}\n'
        'Level: ${word.level}\n'
        'Target POS: ${word.pos}\n'
        'Reference Definitions: $defs\n\n'
        'Return a JSON object with the following specific keys and content:\n'
        '{\n'
        '  "ipa": "String. The US IPA phonetic transcription.",\n'
        '  "short_meaning": "String. The most accurate Chinese definition corresponding to the Target POS (max 15 chars).",\n'
        '  "definition_en": "String. A simple, clear English definition suitable for the learner\'s level.",\n'
        '  "example": {\n'
        '    "en": "String. A high-quality sentence demonstrating the word\'s usage in the specific context of the Reference Definitions.",\n'
        '    "cn": "String. Natural Chinese translation of the sentence."\n'
        '  },\n'
        '  "nuance": "String. A one-sentence explanation in Chinese clarifying when to use this word vs. its synonyms (e.g., formal vs. casual, specific connotation).",\n'
        '  "collocations": "Array of Strings. 3-4 common phrases/chunks containing the word."\n'
        '}';
  }

  String _buildDetailedUserPrompt(Word word) {
    final defs = word.cnDefs.join('；');
    return 'Analyze the following word for a Chinese learner:\n\n'
        'Word: ${word.headword}\n'
        'Level: ${word.level}\n'
        'Target POS: ${word.pos}\n'
        'Reference Definitions: $defs\n\n'
        'Return a JSON object with the following specific keys and content:\n'
        '{\n'
        '  "ipa": "String. The US IPA phonetic transcription.",\n'
        '  "short_meaning": "String. The most accurate Chinese definition corresponding to the Target POS (max 15 chars).",\n'
        '  "definition_en": "String. A simple, clear English definition suitable for the learner\'s level.",\n'
        '  "example": {\n'
        '    "en": "String. A high-quality sentence demonstrating the word\'s usage in the specific context of the Reference Definitions.",\n'
        '    "cn": "String. Natural Chinese translation of the sentence."\n'
        '  },\n'
        '  "morphology": {\n'
        '    "root": "String. The Latin/Greek root (if applicable) and its meaning.",\n'
        '    "affixes": "String. A concise breakdown of prefixes/suffixes (e.g., re- (again) + construct (build))."\n'
        '  },\n'
        '  "word_family": "Array of Strings. Top 3 derived words (e.g., noun/adjective forms) to help expand vocabulary.",\n'
        '  "synonyms": "Array of Strings. 2-3 high-frequency synonyms.",\n'
        '  "antonyms": "Array of Strings. 1-2 direct antonyms (if any).",\n'
        '  "nuance": "String. A one-sentence explanation in Chinese clarifying when to use this word vs. its synonyms (e.g., formal vs. casual, specific connotation).",\n'
        '  "collocations": "Array of Strings. 3-4 common phrases/chunks containing the word.",\n'
        '  "mnemonic": "String. A creative, brief memory aid (association, rhyme, or etymology logic) in Chinese."\n'
        '}';
  }
}
