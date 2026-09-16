import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/data/progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/screens/settings_screen.dart';
import 'package:vocab_flash_test/session/base_providers.dart';
import 'package:vocab_flash_test/utils/ai_studio_models.dart';
import 'package:vocab_flash_test/utils/openrouter_models.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWordRepository implements WordRepository {
  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OpenRouter Free Models Filter Tests', () {
    test('identifies :free models correctly (case insensitive)', () {
      const model1 = OpenRouterModel(
        id: 'google/gemini-2.0-flash:free',
        name: 'Gemini 2.0 Flash Free',
        promptPrice: '0',
        completionPrice: '0',
      );
      const model2 = OpenRouterModel(
        id: 'meta-llama/llama-3.3-70b-instruct:FREE',
        name: 'Llama 3.3 Free Uppercase',
        promptPrice: '?',
        completionPrice: '?',
      );
      expect(model1.isFree, isTrue);
      expect(model2.isFree, isTrue);
    });

    test('identifies models with 0 price as free', () {
      const model1 = OpenRouterModel(
        id: 'custom/free-model',
        name: 'Custom Free',
        promptPrice: '0',
        completionPrice: '0',
      );
      const model2 = OpenRouterModel(
        id: 'custom/free-float-model',
        name: 'Custom Free Float',
        promptPrice: '0.0',
        completionPrice: '0.0000',
      );
      expect(model1.isFree, isTrue);
      expect(model2.isFree, isTrue);
    });

    test('rejects paid models', () {
      const paidModel = OpenRouterModel(
        id: 'openai/gpt-4o',
        name: 'GPT-4o',
        promptPrice: '0.000005',
        completionPrice: '0.000015',
      );
      expect(paidModel.isFree, isFalse);
    });

    test('all fallbackFreeModels are marked as free', () {
      for (final model in fallbackFreeModels) {
        expect(
          model.isFree,
          isTrue,
          reason: '${model.id} should be marked as free',
        );
      }
    });
  });

  group('Google AI Studio Free Tier Filter Tests', () {
    test('identifies Gemini models with generateContent as Free Tier', () {
      const flashModel = AiStudioModel(
        name: 'models/gemini-2.0-flash',
        displayName: 'Gemini 2.0 Flash',
        supportedGenerationMethods: ['generateContent', 'countTokens'],
      );
      const proModel = AiStudioModel(
        name: 'models/gemini-1.5-pro',
        displayName: 'Gemini 1.5 Pro',
        supportedGenerationMethods: ['generateContent'],
      );
      expect(flashModel.isFreeTier, isTrue);
      expect(proModel.isFreeTier, isTrue);
    });

    test('rejects non-generative or non-gemini models', () {
      const embeddingModel = AiStudioModel(
        name: 'models/text-embedding-004',
        displayName: 'Text Embedding 004',
        supportedGenerationMethods: ['embedContent'],
      );
      const aqaModel = AiStudioModel(
        name: 'models/aqa',
        displayName: 'AQA',
        supportedGenerationMethods: ['generateAnswer'],
      );
      expect(embeddingModel.isFreeTier, isFalse);
      expect(aqaModel.isFreeTier, isFalse);
    });

    test('all fallbackAiStudioModels are marked as free tier', () {
      for (final model in fallbackAiStudioModels) {
        expect(
          model.isFreeTier,
          isTrue,
          reason: '${model.name} should be free tier',
        );
      }
    });
  });

  group('SettingsScreen API Refresh Button UI Tests', () {
    testWidgets('renders refresh button with tooltip in AI settings', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'app_settings':
            '{"ai": {"provider": "openrouter", "openRouterApiKey": "sk-or-test"}}',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
            wordRepositoryProvider.overrideWithValue(_FakeWordRepository()),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pump();

      // 验证存在刷新按钮
      final refreshButtonFinder = find.byTooltip('刷新模型列表');
      expect(refreshButtonFinder, findsOneWidget);

      // 验证按钮图标为 refresh
      expect(
        find.descendant(
          of: refreshButtonFinder,
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
    });
  });
}
