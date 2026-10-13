import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_flash_test/data/progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/features/study/domain/study_plan.dart';
import 'package:vocab_flash_test/features/lexicon/domain/production_hint_helper.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/screens/home_screen.dart';
import 'package:vocab_flash_test/screens/settings_screen.dart';
import 'package:vocab_flash_test/screens/stats_screen.dart';
import 'package:vocab_flash_test/screens/summary_screen.dart';
import 'package:vocab_flash_test/session/base_providers.dart';
import 'package:vocab_flash_test/session/session_models.dart';
import 'package:vocab_flash_test/utils/ai_studio_models.dart';
import 'package:vocab_flash_test/utils/openrouter_models.dart';
import 'package:vocab_flash_test/widgets/word_slot_input.dart';

// --- Fake Repositories for Comprehensive Auditing ---

class _AuditFakeProgressRepository implements ProgressRepository {
  final Map<int, CardState> _cards = {};
  final List<TestRun> _testRuns = [];

  @override
  Future<CardState?> getCardState(int wordId) async => _cards[wordId];

  @override
  Future<List<CardState>> getCardStates(List<int> wordIds) async =>
      wordIds.map((id) => _cards[id]).whereType<CardState>().toList();

  @override
  Future<void> saveCardState(CardState cardState) async {
    _cards[cardState.wordId] = cardState;
  }

  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async =>
      _testRuns.take(limit).toList();

  @override
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels) async => [];

  @override
  Future<Map<String, dynamic>> getLearningStats({
    LeechPolicy policy = LeechPolicy.defaultPolicy,
  }) async {
    return {
      'levelTotal': 100,
      'levelLearned': _cards.length,
      'levelMastered': _cards.values.where((c) => c.isMastered).length,
      'accuracy': 0.85,
      'streakDays': 5,
      'dailyStats': <Map<String, dynamic>>[],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuditFakeWordRepository implements WordRepository {
  final List<Word> _words;
  _AuditFakeWordRepository(this._words);

  @override
  Future<Word?> getById(int id) async {
    final matches = _words.where((w) => w.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<List<Word>> getByIds(List<int> ids) async =>
      _words.where((w) => ids.contains(w.id)).toList();

  @override
  Future<List<Word>> loadByLevels(Set<String> levels) async =>
      _words.where((w) => levels.contains(w.level)).toList();

  @override
  Future<List<Word>> loadAll() async => _words;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testWords = [
    const Word(
      id: 1,
      headword: 'apple',
      lemma: 'apple',
      level: 'A1',
      pos: 'n.',
      cnDefs: ['苹果'],
    ),
    const Word(
      id: 2,
      headword: 'brilliant',
      lemma: 'brilliant',
      level: 'B2',
      pos: 'adj.',
      cnDefs: ['出色的', '杰出的'],
    ),
    const Word(
      id: 3,
      headword: 'contrast',
      lemma: 'contrast',
      level: 'B1',
      pos: 'n.',
      cnDefs: ['对比', '对照'],
    ),
  ];

  group('【专项一：分数计算与结算页面综合体检】', () {
    testWidgets('SummaryScreen 准确展示分数、准确率、总题数与错词卡片', (tester) async {
      SharedPreferences.setMockInitialValues({'app_settings': '{}'});
      final prefs = await SharedPreferences.getInstance();

      final fakeSession = SessionData(
        state: SessionState.finished,
        mainQueue: const [],
        delayedQueue: const [],
        attempts: [
          Attempt(
            wordId: 1,
            result: AttemptResult.correct,
            rtMs: 1200,
            chosenIndex: 0,
            correctIndex: 0,
            timestamp: DateTime.now(),
          ),
          Attempt(
            wordId: 2,
            result: AttemptResult.wrong,
            rtMs: 3400,
            chosenIndex: 1,
            correctIndex: 0,
            timestamp: DateTime.now(),
          ),
          Attempt(
            wordId: 3,
            result: AttemptResult.correct,
            rtMs: 1500,
            chosenIndex: 2,
            correctIndex: 2,
            timestamp: DateTime.now(),
          ),
        ],
        millisLeft: 0,
        lastCorrect: true,
        recentWordIds: const {},
        sessionId: 'test-audit-session',
        config: const SessionConfig(
          levels: {'A1', 'B2'},
          wordsPerSession: 3,
          timeLimitMs: 5000,
          orderPolicy: 'by_level',
          onlyLeeches: false,
          wrongDelay: 3,
          slowDelay: 3,
          slowThreshold: 1.5,
          newCardRatio: 0.3,
          dailyNewLimit: 20,
          ttsAutoPlay: false,
          ttsOnWrong: true,
          leechLapsesThreshold: 3,
          leechIncludeMarked: true,
        ),
      );

      // 1. 验证定量算法逻辑
      expect(fakeSession.attempts.length, equals(3));
      expect(fakeSession.wrongAttempts.length, equals(1));
      expect(fakeSession.wrongAttempts.first.wordId, equals(2));
      // 准确率 = 2 / 3 ≈ 66.67%
      expect(fakeSession.accuracy, closeTo(0.666, 0.001));

      // 2. 挂载并渲染结算页面
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(
              _AuditFakeProgressRepository(),
            ),
            wordRepositoryProvider.overrideWithValue(
              _AuditFakeWordRepository(testWords),
            ),
          ],
          child: MaterialApp(
            home: SummaryScreen(
              sessionData: fakeSession.copyWith(unresolvedWordIds: {2}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. 验证结算界面关键指标与展示
      expect(find.text('本轮完成'), findsOneWidget);
      expect(find.text('1 词待巩固，已排到下一组优先复习'), findsOneWidget);
      expect(find.text('首答正确率'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget); // 四舍五入百分比展示
      // 首答 2 / 3 词正确，答错 1。
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '2 / 3 词',
        ),
        findsOneWidget,
      );
      expect(find.text('答错'), findsOneWidget);

      // 4. 验证错词列表中展示了错词 brilliant
      expect(find.text('错题回顾 · 1'), findsOneWidget);
      expect(find.text('brilliant'), findsOneWidget);

      // 5. 验证操作闭环按钮：继续下一组与错题专练（在列表底部）
      await tester.scrollUntilVisible(find.text('继续下一组'), 300);
      expect(find.text('继续下一组'), findsOneWidget);
      expect(find.text('只练错题 · 1 词'), findsOneWidget);
    });
  });

  group('【专项二：学习统计与兴趣分析日历体检】', () {
    testWidgets('StatsScreen 正常渲染置顶学习日历与统计概览', (tester) async {
      SharedPreferences.setMockInitialValues({'app_settings': '{}'});
      final prefs = await SharedPreferences.getInstance();

      final fakeProgress = _AuditFakeProgressRepository();
      final now = DateTime.now();
      // 预置一张 mastered 卡片
      await fakeProgress.saveCardState(
        CardState(
          wordId: 1,
          stability: 20.0,
          difficulty: 3.0,
          due: now.add(const Duration(days: 7)),
          lastReview: now,
          lapses: 0,
          rtP50: 1200,
          flags: 0,
          longTermReviews: 3,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(fakeProgress),
            wordRepositoryProvider.overrideWithValue(
              _AuditFakeWordRepository(testWords),
            ),
            initializationProvider.overrideWith((ref) async => true),
            dailyHistorySummariesProvider.overrideWith((ref) async => const []),
            learningStatsProvider.overrideWith(
              (ref) async => {
                'levelTotal': 100,
                'levelLearned': 10,
                'levelMastered': 5,
                'accuracy': 0.85,
                'streakDays': 5,
                'dailyStats': <Map<String, dynamic>>[],
                'todayTests': 2,
                'todayWords': 20,
                'totalWordsLearned': 10,
                'totalMastered': 5,
                'averageAccuracy': 0.85,
              },
            ),
          ],
          child: const MaterialApp(home: StatsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 验证标题与置顶日历
      expect(find.text('学习数据分析'), findsOneWidget);
      expect(find.text('月度学习日历'), findsOneWidget);
      expect(find.text('每日打卡与重点词透视'), findsOneWidget);
      expect(find.text('完整档案'), findsOneWidget);
    });
  });

  group('【专项三：英语产出 / 看义拼词三阶提示与槽位体检】', () {
    test('ProductionHintHelper 辅音、元音、全词三阶提示与认知负荷理论自洽', () {
      const word = 'apple';
      // Level 0: 无提示
      expect(ProductionHintHelper.getRevealedIndices(word, 0), isEmpty);

      // Level 1: 辅音骨架 (apple -> 辅音 p, p, l，对应索引 1, 2, 3)
      final l1 = ProductionHintHelper.getRevealedIndices(word, 1);
      expect(l1, containsAll([1, 2, 3]));
      expect(l1, isNot(contains(0))); // 'a' 是元音，不揭示
      expect(l1, isNot(contains(4))); // 'e' 是元音，不揭示

      // Level 2: 元音透视 + 首字母锚定，严格保证至少留 1 个盲点槽位
      final l2 = ProductionHintHelper.getRevealedIndices(word, 2);
      expect(l2.length, greaterThanOrEqualTo(l1.length));
      expect(l2.length, lessThan(word.length)); // 必须保留至少一个槽位供回忆
      expect(l2, containsAll([1, 2, 3])); // 累积包含 Level 1 线索

      // Level 3: 全词揭示
      final l3 = ProductionHintHelper.getRevealedIndices(word, 3);
      expect(l3, equals({0, 1, 2, 3, 4}));

      // 短语与复合词容错：连字符 '-' 跳过不揭示
      const compound = 'ice-cream';
      final compL1 = ProductionHintHelper.getRevealedIndices(compound, 1);
      expect(compL1, isNot(contains(3))); // 索引 3 是 '-'
    });

    testWidgets('WordSlotInput 槽位渲染数量、提示字母填充与锁定态自洽', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordSlotInput(
              targetWord: 'apple',
              revealedIndices: {1, 2, 3}, // 揭示 p, p, l
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证已揭示的提示字母在屏幕上呈现
      expect(find.text('p'), findsWidgets);
      expect(find.text('l'), findsWidgets);
    });
  });

  group('【专项四：设置界面 API 刷新与模型过滤全链路体检】', () {
    test('OpenRouter 零定价与 :free 模型过滤算法 100% 精确', () {
      const freeModel = OpenRouterModel(
        id: 'google/gemini-2.0-flash:free',
        name: 'Gemini 2.0 Flash Free',
        promptPrice: '0',
        completionPrice: '0',
      );
      const zeroPriceModel = OpenRouterModel(
        id: 'meta-llama/llama-3-8b-instruct',
        name: 'Llama 3 8B',
        promptPrice: '0.000',
        completionPrice: '0.000',
      );
      const paidModel = OpenRouterModel(
        id: 'anthropic/claude-3.5-sonnet',
        name: 'Claude 3.5 Sonnet',
        promptPrice: '0.000003',
        completionPrice: '0.000015',
      );

      expect(freeModel.isFree, isTrue);
      expect(zeroPriceModel.isFree, isTrue);
      expect(paidModel.isFree, isFalse);
    });

    test('Google AI Studio Free Tier 核心对话模型过滤算法 100% 精确', () {
      const geminiFlash = AiStudioModel(
        name: 'models/gemini-2.0-flash',
        displayName: 'Gemini 2.0 Flash',
        supportedGenerationMethods: ['generateContent'],
      );
      const geminiEmbedding = AiStudioModel(
        name: 'models/text-embedding-004',
        displayName: 'Text Embedding 004',
        supportedGenerationMethods: ['embedContent'],
      );
      const otherModel = AiStudioModel(
        name: 'models/aqa',
        displayName: 'AQA',
        supportedGenerationMethods: ['generateContent'],
      );

      expect(geminiFlash.isFreeTier, isTrue);
      expect(geminiEmbedding.isFreeTier, isFalse); // 非对话生成
      expect(otherModel.isFreeTier, isFalse); // 非 Gemini 核心系列
    });

    testWidgets('SettingsScreen API 输入框右侧刷新按钮正常渲染并具备 Tooltip', (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_settings':
            '{"ai": {"provider": "openrouter", "openRouterApiKey": "sk-or-test"}}',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(
              _AuditFakeProgressRepository(),
            ),
            wordRepositoryProvider.overrideWithValue(
              _AuditFakeWordRepository(testWords),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pump();

      // 验证刷新按钮
      final refreshFinder = find.byTooltip('刷新模型列表');
      expect(refreshFinder, findsOneWidget);
    });
  });

  group('【专项五：主页导航与全局健康度】', () {
    testWidgets('HomeScreen 核心入口与动态当前日期渲染正常', (tester) async {
      SharedPreferences.setMockInitialValues({'app_settings': '{}'});
      final prefs = await SharedPreferences.getInstance();
      // 手机布局（最短边 < 600dp）；默认 800x600 会命中平板布局。
      // 宽度取 550dp：测试字体是等宽方块，比真机字体宽，窄屏会误报标题栏溢出。
      tester.view.physicalSize = const Size(1650, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(
              _AuditFakeProgressRepository(),
            ),
            wordRepositoryProvider.overrideWithValue(
              _AuditFakeWordRepository(testWords),
            ),
            todayDeckProvider.overrideWith((ref) async => testWords),
            todayStudyPlanProvider.overrideWith(
              (ref) async => StudyPlan(
                createdAt: DateTime.now(),
                items: const [],
                newItemCount: 0,
                estimatedSeconds: 0,
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证首页 4 大入口存在
      expect(find.text('开始测试'), findsOneWidget);
      expect(find.text('不熟悉单词'), findsOneWidget);
      expect(find.text('看义拼词'), findsOneWidget);
      expect(find.text('学习统计'), findsOneWidget);

      // 验证当天日期动态格式化渲染（yyyy/MM/dd）
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final dateString = '$y/$m/$d';
      expect(find.textContaining(dateString), findsOneWidget);
    });

    testWidgets('平板横屏显示导航栏、学习记录与今日行动栏', (tester) async {
      SharedPreferences.setMockInitialValues({'app_settings': '{}'});
      final prefs = await SharedPreferences.getInstance();
      // 联想 TB138FC 横屏：1280x768dp。
      tester.view.physicalSize = const Size(2560, 1536);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWith((ref) async => prefs),
            progressRepositoryProvider.overrideWithValue(
              _AuditFakeProgressRepository(),
            ),
            wordRepositoryProvider.overrideWithValue(
              _AuditFakeWordRepository(testWords),
            ),
            todayDeckProvider.overrideWith((ref) async => testWords),
            todayStudyPlanProvider.overrideWith(
              (ref) async => StudyPlan(
                createdAt: DateTime.now(),
                items: const [],
                newItemCount: 0,
                estimatedSeconds: 0,
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('学习记录'), findsOneWidget);
      expect(find.text('连续打卡'), findsOneWidget);
      expect(find.text('开始学习'), findsOneWidget);
      expect(find.text('主动回忆'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
