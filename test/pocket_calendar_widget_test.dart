import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/daily_history_models.dart';
import 'package:vocab_flash_test/models/word.dart';
import 'package:vocab_flash_test/theme/theme_style.dart';
import 'package:vocab_flash_test/widgets/calendar/pocket_calendar_widget.dart';

void main() {
  group('PocketCalendarWidget Widget & Interaction Tests', () {
    final testDate = DateTime(2026, 9, 15);

    final mockFocusWords = [
      const FocusWordItem(
        word: Word(
          id: 1,
          headword: 'abandon',
          lemma: 'abandon',
          level: 'B2',
          pos: 'v.',
          cnDefs: ['放弃'],
        ),
        focusScore: 100,
        reasons: {FocusWordReason.wrong},
      ),
      const FocusWordItem(
        word: Word(
          id: 2,
          headword: 'contrast',
          lemma: 'contrast',
          level: 'B1',
          pos: 'n.',
          cnDefs: ['对比'],
        ),
        focusScore: 80,
        reasons: {FocusWordReason.hesitation},
      ),
      const FocusWordItem(
        word: Word(
          id: 3,
          headword: 'persist',
          lemma: 'persist',
          level: 'C1',
          pos: 'v.',
          cnDefs: ['坚持'],
        ),
        focusScore: 60,
        reasons: {FocusWordReason.timeout},
      ),
    ];

    final mockSummaries = [
      DailyHistorySummary(
        date: testDate,
        sessions: [
          SessionRunSummary(
            id: 'run-1',
            startedAt: DateTime(2026, 9, 15, 10, 0),
            totalQuestions: 10,
            correctCount: 7,
            wrongCount: 3,
            accuracy: 0.7,
            avgRtMs: 1200,
            timeLimitMs: 2000,
            levels: ['B1', 'B2'],
            focusWordCount: 3,
          ),
        ],
        totalWordsTested: 10,
        averageAccuracy: 0.7,
        totalDurationMs: 60000,
        focusWords: mockFocusWords,
      ),
    ];

    testWidgets('Renders PocketCalendarWidget in Minimal Theme with Month and Weekdays', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PocketCalendarWidget(
                  themeStyle: ThemeStyle.minimal,
                  initialMonth: DateTime(2026, 9, 1),
                  summaries: mockSummaries,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('September'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);

      // Verify Weekday Headers
      expect(find.text('SUN'), findsOneWidget);
      expect(find.text('MON'), findsOneWidget);
      expect(find.text('SAT'), findsOneWidget);

      // Verify Day 15 card exists and displays the focus word
      expect(find.text('15'), findsOneWidget);
      expect(find.text('abandon'), findsOneWidget);
      expect(find.text('contrast'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget); // 3 words - 2 = +1
    });

    testWidgets('Renders in Digitalism and Bauhaus themes correctly', (tester) async {
      for (final style in [
        ThemeStyle.digitalism,
        ThemeStyle.bauhaus,
        ThemeStyle.fono,
        ThemeStyle.cyberpunk,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PocketCalendarWidget(
                    themeStyle: style,
                    initialMonth: DateTime(2026, 9, 1),
                    summaries: mockSummaries,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('15'), findsOneWidget);
        expect(find.text('abandon'), findsOneWidget);
      }
    });

    testWidgets('Switching months updates displayed month and dates', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PocketCalendarWidget(
                  themeStyle: ThemeStyle.minimal,
                  initialMonth: DateTime(2026, 9, 1),
                  summaries: mockSummaries,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('September'), findsOneWidget);

      // Tap next month
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(find.text('October'), findsOneWidget);

      // Tap previous month twice
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('September'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('August'), findsOneWidget);
    });

    testWidgets('Tapping on a day card with study opens Day Detail Modal Sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PocketCalendarWidget(
                  themeStyle: ThemeStyle.minimal,
                  initialMonth: DateTime(2026, 9, 1),
                  summaries: mockSummaries,
                ),
              ),
            ),
          ),
        ),
      );

      // Find day 15 and tap it
      final day15 = find.text('15');
      await tester.tap(day15);
      await tester.pumpAndSettle();

      // Modal sheet should now be open
      expect(find.text('2026年9月15日'), findsOneWidget);
      expect(find.text('当日学习复盘与重点攻克词'), findsOneWidget);
      expect(find.text('测试轮数'), findsOneWidget);
      expect(find.text('1 轮'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget); // 0.7 accuracy

      // Verify focus words listed in modal
      expect(find.text('abandon'), findsWidgets);
      expect(find.text('放弃'), findsOneWidget);
      expect(find.text('本次答错'), findsOneWidget);
    });

    testWidgets('Filter pills toggle selection state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PocketCalendarWidget(
                  themeStyle: ThemeStyle.minimal,
                  initialMonth: DateTime(2026, 9, 1),
                  summaries: mockSummaries,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('全部打卡'), findsOneWidget);
      expect(find.text('重点复习'), findsOneWidget);
      expect(find.text('高正确率 (≥80%)'), findsOneWidget);
      expect(find.text('需攻克 (<80%)'), findsOneWidget);

      // Tap on '重点复习' filter pill
      await tester.tap(find.text('重点复习'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap on '高正确率 (≥80%)' filter pill
      await tester.tap(find.text('高正确率 (≥80%)'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Day 15 has 70% accuracy, so in highAccuracy filter it is dimmed but still present
      expect(find.text('15'), findsOneWidget);
    });
  });
}
