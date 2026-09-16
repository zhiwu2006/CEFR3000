import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/models.dart';
import 'package:vocab_flash_test/session/session_models.dart';

void main() {
  group('Session Cleanliness & Progress Offset', () {
    const config = SessionConfig(
      levels: {'A1'},
      wordsPerSession: 20,
      timeLimitMs: 2000,
      orderPolicy: 'by_level',
      onlyLeeches: false,
      wrongDelay: 3,
      slowDelay: 5,
      slowThreshold: 1.5,
      newCardRatio: 0.25,
      dailyNewLimit: 30,
      ttsAutoPlay: false,
      ttsOnWrong: false,
      leechLapsesThreshold: 2,
      leechIncludeMarked: true,
    );

    test(
      'SessionData.initial with initialProgressOffset reflects correct progress without dummy attempts',
      () {
        final initialQueue = [
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
            headword: 'banana',
            lemma: 'banana',
            level: 'A1',
            pos: 'n.',
            cnDefs: ['香蕉'],
          ),
        ];

        // 模拟恢复之前已完成 5 题的会话
        final session = SessionData.initial(
          initialQueue: initialQueue,
          config: config,
          sessionId: 'test-session-123',
          initialProgressOffset: 5,
        );

        // 进度应为 5
        expect(session.currentProgress, equals(5));
        // attempts 列表必须是空的，绝不能包含 wordId: 0 的虚拟脏数据
        expect(session.attempts, isEmpty);
        expect(session.accuracy, equals(0.0));

        // 答一道真实题目
        final realAttempt = Attempt(
          wordId: 1,
          result: AttemptResult.correct,
          rtMs: 800,
          chosenIndex: 0,
          correctIndex: 0,
          timestamp: DateTime.now(),
        );

        final updatedSession = session.copyWith(attempts: [realAttempt]);

        // 进度应递增到 6
        expect(updatedSession.currentProgress, equals(6));
        expect(updatedSession.attempts.length, equals(1));
        expect(updatedSession.attempts.first.wordId, equals(1));
        expect(updatedSession.accuracy, equals(1.0));
      },
    );

    test(
      'Corrupted/dummy attempts with wordId <= 0 can be filtered cleanly',
      () {
        final mixedAttempts = [
          Attempt(
            wordId: 0, // 虚拟ID
            result: AttemptResult.correct,
            rtMs: 0,
            chosenIndex: 0,
            correctIndex: 0,
            timestamp: DateTime.now(),
          ),
          Attempt(
            wordId: 101, // 真实单词ID
            result: AttemptResult.correct,
            rtMs: 900,
            chosenIndex: 1,
            correctIndex: 1,
            timestamp: DateTime.now(),
          ),
        ];

        final cleanAttempts = mixedAttempts.where((a) => a.wordId > 0).toList();

        expect(cleanAttempts.length, equals(1));
        expect(cleanAttempts.first.wordId, equals(101));
      },
    );
  });
}
