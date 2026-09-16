import 'dart:convert';
import 'dart:io';

class OpenRouterModel {
  final String id;
  final String name;
  final String promptPrice;
  final String completionPrice;
  final int? contextLength;

  const OpenRouterModel({
    required this.id,
    required this.name,
    required this.promptPrice,
    required this.completionPrice,
    this.contextLength,
  });

  bool get isFree {
    final lowerId = id.trim().toLowerCase();
    if (lowerId.endsWith(':free')) {
      return true;
    }
    final p = double.tryParse(promptPrice);
    final c = double.tryParse(completionPrice);
    if (p != null && c != null && p == 0 && c == 0) {
      return true;
    }
    return promptPrice == '0' && completionPrice == '0';
  }

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] is Map
        ? Map<String, dynamic>.from(json['pricing'] as Map)
        : const <String, dynamic>{};
    return OpenRouterModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      promptPrice: pricing['prompt']?.toString() ?? '',
      completionPrice: pricing['completion']?.toString() ?? '',
      contextLength: json['context_length'] is int
          ? json['context_length'] as int
          : null,
    );
  }
}

const List<OpenRouterModel> fallbackFreeModels = [
  OpenRouterModel(
    id: 'google/gemini-2.0-flash:free',
    name: 'Gemini 2.0 Flash',
    promptPrice: '0',
    completionPrice: '0',
    contextLength: 1000000,
  ),
  OpenRouterModel(
    id: 'meta-llama/llama-3.3-70b-instruct:free',
    name: 'Llama 3.3 70B Instruct',
    promptPrice: '0',
    completionPrice: '0',
  ),
  OpenRouterModel(
    id: 'mistralai/devstral-2:free',
    name: 'Devstral 2',
    promptPrice: '0',
    completionPrice: '0',
  ),
  OpenRouterModel(
    id: 'xiaomi/mimo-v2-flash:free',
    name: 'MiMo v2 Flash',
    promptPrice: '0',
    completionPrice: '0',
  ),
  OpenRouterModel(
    id: 'microsoft/phi-3-mini-128k-instruct:free',
    name: 'Phi-3 Mini 128k Instruct',
    promptPrice: '0',
    completionPrice: '0',
    contextLength: 128000,
  ),
  OpenRouterModel(
    id: 'qwen/qwen-2.5-72b-instruct:free',
    name: 'Qwen 2.5 72B Instruct',
    promptPrice: '0',
    completionPrice: '0',
  ),
];

Future<List<OpenRouterModel>> fetchOpenRouterModels({String? apiKey}) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('https://openrouter.ai/api/v1/models'))
        .timeout(const Duration(seconds: 10));
    request.headers.set('Accept', 'application/json');
    final trimmedKey = apiKey?.trim() ?? '';
    if (trimmedKey.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer $trimmedKey');
    }
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return [];
    final data = decoded['data'];
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map(
          (item) => OpenRouterModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  } catch (_) {
    return [];
  } finally {
    client.close(force: true);
  }
}
