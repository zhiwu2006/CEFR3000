import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/ai_studio_models.dart';
import '../utils/openrouter_models.dart';

class BenchmarkResult {
  final int? latencyMs;
  final String? error;
  final DateTime timestamp;

  const BenchmarkResult({
    required this.latencyMs,
    required this.error,
    required this.timestamp,
  });

  bool get isSuccess => latencyMs != null && error == null;
}

class AiBenchmarkState {
  final Map<String, BenchmarkResult> openRouter;
  final Map<String, BenchmarkResult> aiStudio;
  final bool runningOpenRouter;
  final bool runningAiStudio;

  const AiBenchmarkState({
    this.openRouter = const {},
    this.aiStudio = const {},
    this.runningOpenRouter = false,
    this.runningAiStudio = false,
  });

  AiBenchmarkState copyWith({
    Map<String, BenchmarkResult>? openRouter,
    Map<String, BenchmarkResult>? aiStudio,
    bool? runningOpenRouter,
    bool? runningAiStudio,
  }) {
    return AiBenchmarkState(
      openRouter: openRouter ?? this.openRouter,
      aiStudio: aiStudio ?? this.aiStudio,
      runningOpenRouter: runningOpenRouter ?? this.runningOpenRouter,
      runningAiStudio: runningAiStudio ?? this.runningAiStudio,
    );
  }
}

class AiBenchmarkNotifier extends StateNotifier<AiBenchmarkState> {
  AiBenchmarkNotifier() : super(const AiBenchmarkState());

  Future<void> benchmarkOpenRouter({
    required List<OpenRouterModel> models,
    required String apiKey,
  }) async {
    if (state.runningOpenRouter) return;
    final trimmedKey = apiKey.trim();
    final results = Map<String, BenchmarkResult>.from(state.openRouter);

    if (trimmedKey.isEmpty) {
      final now = DateTime.now();
      for (final model in models) {
        results[model.id] = BenchmarkResult(
          latencyMs: null,
          error: 'missing_api_key',
          timestamp: now,
        );
      }
      state = state.copyWith(openRouter: results, runningOpenRouter: false);
      return;
    }

    state = state.copyWith(runningOpenRouter: true);
    for (final model in models) {
      final result = await _benchmarkOpenRouterModel(model.id, trimmedKey);
      results[model.id] = result;
      state = state.copyWith(openRouter: Map.unmodifiable(results));
    }
    state = state.copyWith(runningOpenRouter: false);
  }

  Future<void> benchmarkAiStudio({
    required List<AiStudioModel> models,
    required String apiKey,
  }) async {
    if (state.runningAiStudio) return;
    final trimmedKey = apiKey.trim();
    final results = Map<String, BenchmarkResult>.from(state.aiStudio);

    if (trimmedKey.isEmpty) {
      final now = DateTime.now();
      for (final model in models) {
        results[model.name] = BenchmarkResult(
          latencyMs: null,
          error: 'missing_api_key',
          timestamp: now,
        );
      }
      state = state.copyWith(aiStudio: results, runningAiStudio: false);
      return;
    }

    state = state.copyWith(runningAiStudio: true);
    for (final model in models) {
      final result = await _benchmarkAiStudioModel(model, trimmedKey);
      results[model.name] = result;
      state = state.copyWith(aiStudio: Map.unmodifiable(results));
    }
    state = state.copyWith(runningAiStudio: false);
  }

  Future<BenchmarkResult> _benchmarkOpenRouterModel(
    String modelId,
    String apiKey,
  ) async {
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    try {
      final request = await client
          .postUrl(Uri.parse('https://openrouter.ai/api/v1/chat/completions'))
          .timeout(const Duration(seconds: 10));
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': modelId,
            'messages': [
              {'role': 'user', 'content': 'ping'},
            ],
            'max_tokens': 1,
            'temperature': 0,
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      await response.drain();
      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BenchmarkResult(
          latencyMs: stopwatch.elapsedMilliseconds,
          error: null,
          timestamp: DateTime.now(),
        );
      }
      return BenchmarkResult(
        latencyMs: null,
        error: 'http_${response.statusCode}',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      return BenchmarkResult(
        latencyMs: null,
        error: 'request_failed',
        timestamp: DateTime.now(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<BenchmarkResult> _benchmarkAiStudioModel(
    AiStudioModel model,
    String apiKey,
  ) async {
    final method = _resolveAiStudioMethod(model);
    if (method == null) {
      return BenchmarkResult(
        latencyMs: null,
        error: 'unsupported',
        timestamp: DateTime.now(),
      );
    }

    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/${model.name}:$method?key=$apiKey',
      );
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set('Content-Type', 'application/json');
      final payload = method == 'embedContent'
          ? {
              'content': {
                'parts': [
                  {'text': 'ping'},
                ],
              },
            }
          : {
              'contents': [
                {
                  'parts': [
                    {'text': 'ping'},
                  ],
                },
              ],
            };
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      await response.drain();
      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BenchmarkResult(
          latencyMs: stopwatch.elapsedMilliseconds,
          error: null,
          timestamp: DateTime.now(),
        );
      }
      return BenchmarkResult(
        latencyMs: null,
        error: 'http_${response.statusCode}',
        timestamp: DateTime.now(),
      );
    } catch (_) {
      stopwatch.stop();
      return BenchmarkResult(
        latencyMs: null,
        error: 'request_failed',
        timestamp: DateTime.now(),
      );
    } finally {
      client.close(force: true);
    }
  }

  String? _resolveAiStudioMethod(AiStudioModel model) {
    if (model.supportedGenerationMethods.contains('generateContent')) {
      return 'generateContent';
    }
    if (model.supportedGenerationMethods.contains('embedContent')) {
      return 'embedContent';
    }
    return null;
  }
}
