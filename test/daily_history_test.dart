import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/services/daily_history_service.dart';
import 'package:vocab_flash_test/data/progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';

class FakeWordRepository implements WordRepository {
  final Map<int, Word> _words;

  FakeWordRepository(this._words);

  @override
  Future<Word?> getById(int id) async => _words[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProgressRepository implements ProgressRepository {
  final List<TestRun> testRuns;
  final Map<int, CardState> cardStates;

  FakeProgressRepository({required this.testRuns, this.cardStates = const {}});

  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async =>
      testRuns.take(limit).toList();

  @override
  Future<CardState?> getCardState(int wordId) async => cardStates[wordId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DailyHistoryService & Focus Words Algorithm Tests', () {
    final wordsMap = {
      1: const Word(
        id: 1,
        headword: 'abandon',
        lemma: 'abandon',
        level: 'B2',
        pos: 'v.',
        cnDefs: ['放弃'],
      ),
      2: const Word(
        id: 2,
        headword: 'ability',
        lemma: 'ability',
        level: 'A2',
        pos: 'n.',
        cnDefs: ['能力'],
      ),
      3: const Word(
        id: 3,
        headword: 'absolute',
        lemma: 'absolute',
        level: 'B2',
        pos: 'adj.',
        cnDefs: ['绝对的'],
      ),
      4: const Word(
        id: 4,
        headword: 'academic',
        lemma: 'academic',
        level: 'B1',
        pos: 'adj.',
        cnDefs: ['学术的'],
      ),
    };

    test(
      'Groups test runs by natural date and computes daily metrics correctly',
      () async {
        final now = DateTime(2026, 9, 6, 10, 30);
        final earlierToday = DateTime(2026, 9, 6, 9, 0);
        final yesterday = DateTime(2026, 9, 5, 15, 0);

        final runToday1 = TestRun(
          id: 'run-1',
          startedAt: earlierToday,
          finishedAt: earlierToday.add(const Duration(minutes: 2)),
          size: 2,
          levels: ['A2', 'B2'],
          timeLimitMs: 2000,
          attempts: [
            Attempt(
              wordId: 1,
              result: AttemptResult.correct,
              rtMs: 800,
              chosenIndex: 0,
              correctIndex: 0,
              timestamp: earlierToday,
            ),
            Attempt(
              wordId: 2,
              result: AttemptResult.correct,
              rtMs: 900,
              chosenIndex: 1,
              correctIndex: 1,
              timestamp: earlierToday,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final runToday2 = TestRun(
          id: 'run-2',
          startedAt: now,
          finishedAt: now.add(const Duration(minutes: 3)),
          size: 2,
          levels: ['B2'],
          timeLimitMs: 2000,
          attempts: [
            Attempt(
              wordId: 1,
              result: AttemptResult.wrong,
              rtMs: 1200,
              chosenIndex: 2,
              correctIndex: 0,
              timestamp: now,
            ),
            Attempt(
              wordId: 3,
              result: AttemptResult.timeout,
              rtMs: 2000,
              chosenIndex: -1,
              correctIndex: 1,
              timestamp: now,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final runYesterday = TestRun(
          id: 'run-3',
          startedAt: yesterday,
          finishedAt: yesterday.add(const Duration(minutes: 1)),
          size: 1,
          levels: ['B1'],
          timeLimitMs: 2000,
          attempts: [
            Attempt(
              wordId: 4,
              result: AttemptResult.correct,
              rtMs: 600,
              chosenIndex: 0,
              correctIndex: 0,
              timestamp: yesterday,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final fakeProgress = FakeProgressRepository(
          testRuns: [runToday1, runToday2, runYesterday],
        );
        final fakeWords = FakeWordRepository(wordsMap);
        final service = DailyHistoryService(
          progressRepository: fakeProgress,
          wordRepository: fakeWords,
        );

        final summaries = await service.getDailySummaries();

        expect(summaries.length, equals(2));

        // 今日总结
        final todaySummary = summaries.first;
        expect(todaySummary.date, equals(DateTime(2026, 9, 6)));
        expect(todaySummary.sessionCount, equals(2));
        expect(todaySummary.totalWordsTested, equals(4));
        expect(todaySummary.averageAccuracy, equals(0.5)); // 2 correct out of 4
        expect(todaySummary.totalDurationMs, equals(5 * 60 * 1000)); // 2m + 3m

        // 昨日总结
        final yesterdaySummary = summaries.last;
        expect(yesterdaySummary.date, equals(DateTime(2026, 9, 5)));
        expect(yesterdaySummary.sessionCount, equals(1));
        expect(yesterdaySummary.totalWordsTested, equals(1));
        expect(yesterdaySummary.averageAccuracy, equals(1.0));
        expect(yesterdaySummary.focusWords, isEmpty);
      },
    );

    test(
      'Correctly identifies focus words with appropriate reasons and scores',
      () async {
        final testTime = DateTime(2026, 9, 6, 11, 0);

        final run = TestRun(
          id: 'run-focus',
          startedAt: testTime,
          finishedAt: testTime.add(const Duration(minutes: 2)),
          size: 4,
          levels: ['A2', 'B2'],
          timeLimitMs: 2000,
          attempts: [
            // 单词1: 答错 (+100)
            Attempt(
              wordId: 1,
              result: AttemptResult.wrong,
              rtMs: 1100,
              chosenIndex: 1,
              correctIndex: 0,
              timestamp: testTime,
            ),
            // 单词2: 超时 (+90)
            Attempt(
              wordId: 2,
              result: AttemptResult.timeout,
              rtMs: 2000,
              chosenIndex: -1,
              correctIndex: 0,
              timestamp: testTime,
            ),
            // 单词3: 迟疑答对 (rtMs: 1700 >= 1500) (+50)
            Attempt(
              wordId: 3,
              result: AttemptResult.correct,
              rtMs: 1700,
              chosenIndex: 0,
              correctIndex: 0,
              timestamp: testTime,
            ),
            // 单词4: 迅速答对 (rtMs: 700 < 1500) (0分，不进重点词)
            Attempt(
              wordId: 4,
              result: AttemptResult.correct,
              rtMs: 700,
              chosenIndex: 0,
              correctIndex: 0,
              timestamp: testTime,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final cardStates = {
          1: CardState.newCard(
            1,
          ).copyWith(lapses: 3, longTermReviews: 1), // FSRS 难词 (+30)
        };

        final fakeProgress = FakeProgressRepository(
          testRuns: [run],
          cardStates: cardStates,
        );
        final fakeWords = FakeWordRepository(wordsMap);
        final service = DailyHistoryService(
          progressRepository: fakeProgress,
          wordRepository: fakeWords,
        );

        final summaries = await service.getDailySummaries();
        final todaySummary = summaries.first;

        final focusWords = todaySummary.focusWords;
        expect(focusWords.length, equals(3));

        // 第1名: 单词 1 (100 + 30 = 130 分)
        expect(focusWords[0].word.id, equals(1));
        expect(focusWords[0].focusScore, equals(130));
        expect(focusWords[0].reasons.contains(FocusWordReason.wrong), isTrue);
        expect(focusWords[0].reasons.contains(FocusWordReason.leech), isTrue);
        expect(focusWords[0].primaryReasonText, equals('本次答错'));

        // 第2名: 单词 2 (90 分)
        expect(focusWords[1].word.id, equals(2));
        expect(focusWords[1].focusScore, equals(90));
        expect(focusWords[1].reasons.contains(FocusWordReason.timeout), isTrue);
        expect(focusWords[1].primaryReasonText, equals('答题超时'));

        // 第3名: 单词 3 (50 分)
        expect(focusWords[2].word.id, equals(3));
        expect(focusWords[2].focusScore, equals(50));
        expect(
          focusWords[2].reasons.contains(FocusWordReason.hesitation),
          isTrue,
        );
        expect(focusWords[2].primaryReasonText, contains('迟疑答对'));
      },
    );

    test(
      'Identifies frequent fails across multiple sessions on the same day',
      () async {
        final morning = DateTime(2026, 9, 6, 9, 0);
        final evening = DateTime(2026, 9, 6, 20, 0);

        final run1 = TestRun(
          id: 'run-m',
          startedAt: morning,
          finishedAt: morning.add(const Duration(minutes: 1)),
          size: 1,
          levels: ['B2'],
          timeLimitMs: 2000,
          attempts: [
            Attempt(
              wordId: 1,
              result: AttemptResult.wrong,
              rtMs: 1000,
              chosenIndex: 2,
              correctIndex: 0,
              timestamp: morning,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final run2 = TestRun(
          id: 'run-e',
          startedAt: evening,
          finishedAt: evening.add(const Duration(minutes: 1)),
          size: 1,
          levels: ['B2'],
          timeLimitMs: 2000,
          attempts: [
            Attempt(
              wordId: 1,
              result: AttemptResult.timeout,
              rtMs: 2000,
              chosenIndex: -1,
              correctIndex: 0,
              timestamp: evening,
            ),
          ],
          orderPolicy: 'random',
          onlyLeeches: false,
        );

        final fakeProgress = FakeProgressRepository(testRuns: [run1, run2]);
        final fakeWords = FakeWordRepository(wordsMap);
        final service = DailyHistoryService(
          progressRepository: fakeProgress,
          wordRepository: fakeWords,
        );

        final summaries = await service.getDailySummaries();
        final focusWords = summaries.first.focusWords;

        expect(focusWords.length, equals(1));
        final word1Item = focusWords.first;
        // 错误1次(+100) + 超时1次(+90) + 跨轮多错(+60) = 250
        expect(word1Item.focusScore, equals(250));
        expect(
          word1Item.reasons.contains(FocusWordReason.frequentFail),
          isTrue,
        );
        expect(word1Item.primaryReasonText, equals('高频顽固'));
      },
    );
  });
}
