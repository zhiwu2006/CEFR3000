import 'dart:convert';
import 'dart:io';

class AiStudioModel {
  final String name;
  final String displayName;
  final List<String> supportedGenerationMethods;

  const AiStudioModel({
    required this.name,
    required this.displayName,
    required this.supportedGenerationMethods,
  });

  bool get isGenerative =>
      supportedGenerationMethods.contains('generateContent');

  /// Google AI Studio 免费层级 (Free tier) 模型：
  /// 具备 generateContent 生成能力且属于 Gemini 核心系列模型
  bool get isFreeTier {
    if (!isGenerative) return false;
    final lower = name.toLowerCase();
    return lower.contains('gemini');
  }

  factory AiStudioModel.fromJson(Map<String, dynamic> json) {
    final methods = <String>[];
    final rawMethods = json['supportedGenerationMethods'];
    if (rawMethods is List) {
      for (final method in rawMethods) {
        if (method != null) methods.add(method.toString());
      }
    }
    return AiStudioModel(
      name: json['name']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      supportedGenerationMethods: methods,
    );
  }
}

const List<AiStudioModel> fallbackAiStudioModels = [
  AiStudioModel(
    name: 'models/gemini-2.0-flash',
    displayName: 'Gemini 2.0 Flash',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-2.0-flash-lite',
    displayName: 'Gemini 2.0 Flash-Lite',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-1.5-flash',
    displayName: 'Gemini 1.5 Flash',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-1.5-pro',
    displayName: 'Gemini 1.5 Pro',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-2.5-flash',
    displayName: 'Gemini 2.5 Flash',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-2.5-flash-lite',
    displayName: 'Gemini 2.5 Flash-Lite',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-2.5-pro',
    displayName: 'Gemini 2.5 Pro',
    supportedGenerationMethods: ['generateContent'],
  ),
  AiStudioModel(
    name: 'models/gemini-3-flash-preview',
    displayName: 'Gemini 3 Flash Preview',
    supportedGenerationMethods: ['generateContent'],
  ),
];

Future<List<AiStudioModel>> fetchAiStudioModels({String? apiKey}) async {
  final trimmedKey = apiKey?.trim() ?? '';
  if (trimmedKey.isEmpty) {
    return [];
  }

  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$trimmedKey',
    );
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 10));
    request.headers.set('Accept', 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return [];
    final data = decoded['models'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => AiStudioModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return [];
  } finally {
    client.close(force: true);
  }
}
