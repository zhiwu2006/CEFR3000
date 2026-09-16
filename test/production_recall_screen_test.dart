import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/data/progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/screens/production_recall_screen.dart';
import 'package:vocab_flash_test/session/base_providers.dart';
import 'package:vocab_flash_test/session/session_models.dart';
import 'package:vocab_flash_test/widgets/word_slot_input.dart';

class _FakeProgressRepository implements ProgressRepository {
  CardState? state;

  @override
  Future<CardState?> getCardState(int wordId) async => state;

  @override
  Future<void> saveCardState(CardState cardState) async {
    state = cardState;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWordRepository implements WordRepository {
  final List<Word> words;
  _FakeWordRepository(this.words);

  @override
  Future<List<Word>> getByIds(List<int> ids) async {
    return words.where((w) => ids.contains(w.id)).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ProductionRecallScreen full graduated hint workflow', (tester) async {
    final fakeWord = Word(
      id: 1,
      headword: 'apple',
      lemma: 'apple',
      level: 'A1',
      pos: 'n.',
      cnDefs: ['苹果'],
    );

    final progressRepo = _FakeProgressRepository();
    final wordRepo = _FakeWordRepository([fakeWord]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(progressRepo),
          wordRepositoryProvider.overrideWithValue(wordRepo),
        ],
        child: const MaterialApp(
          home: ProductionRecallScreen(
            config: SessionConfig.defaultConfig,
            wordIds: [1],
            allowLegacyFallback: true,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. 验证标题与释义
    expect(find.text('看义拼词'), findsOneWidget);
    expect(find.text('根据中文释义拼写英文单词'), findsOneWidget);
    expect(find.text('苹果'), findsOneWidget);
    expect(find.byType(WordSlotInput), findsOneWidget);

    // 2. 验证初始状态下的三阶提示按钮
    expect(find.text('提示 (1/3: 辅音骨架)'), findsOneWidget);

    // 3. 点击第 1 阶提示（辅音骨架）
    await tester.tap(find.text('提示 (1/3: 辅音骨架)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 辅音 p, l 应当显示在槽位中，而元音 a, e 依然空白
    expect(find.text('p'), findsNWidgets(2));
    expect(find.text('l'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('提示 (2/3: 关键元音)'), findsOneWidget);

    // 4. 点击第 2 阶提示（关键元音与透视）
    await tester.tap(find.text('提示 (2/3: 关键元音)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 提示按钮更新为第 3 阶
    expect(find.text('提示 (3/3: 补全全词)'), findsOneWidget);

    // 5. 点击第 3 阶提示（全词补全）
    await tester.tap(find.text('提示 (3/3: 补全全词)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('已全词补全'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('p'), findsNWidgets(2));
    expect(find.text('l'), findsOneWidget);
    expect(find.text('e'), findsOneWidget);

    // 6. 提交答案
    await tester.tap(find.text('提交答案'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 7. 验证结果状态与反馈
    expect(find.text('回答正确！'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });
}
