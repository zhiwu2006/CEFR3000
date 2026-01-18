import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/domain/srs.dart';
import 'package:vocab_flash_test/models/models.dart';

void main() {
  group('SrsAlgorithm', () {
    test('calculates quality score correctly', () {
      // 错误或超时
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.wrong,
          reactionTime: 1500,
          timeLimit: 2000,
        ),
        equals(1),
      );
      
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.timeout,
          reactionTime: 2000,
          timeLimit: 2000,
        ),
        equals(1),
      );
      
      // 慢对（反应时间 > 80% 时限）
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.correct,
          reactionTime: 1700, // > 0.8 * 2000
          timeLimit: 2000,
        ),
        equals(3),
      );
      
      // 普通对
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.correct,
          reactionTime: 1200, // 0.5 < rt/timeLimit < 0.8
          timeLimit: 2000,
        ),
        equals(4),
      );
      
      // 快对（反应时间 <= 50% 时限）
      expect(
        SrsAlgorithm.calculateQuality(
          result: AttemptResult.correct,
          reactionTime: 1000, // <= 0.5 * 2000
          timeLimit: 2000,
        ),
        equals(5),
      );
    });
    
    test('updates difficulty within bounds', () {
      final initialState = CardState.newCard(1);
      
      // 错误答题应该增加难度
      final wrongState = SrsAlgorithm.updateCardState(initialState, 1);
      expect(wrongState.difficulty, greaterThan(initialState.difficulty));
      expect(wrongState.difficulty, greaterThanOrEqualTo(1.2));
      expect(wrongState.difficulty, lessThanOrEqualTo(3.0));
      
      // 快对应该减少难度
      final fastCorrectState = SrsAlgorithm.updateCardState(initialState, 5);
      expect(fastCorrectState.difficulty, lessThan(initialState.difficulty));
      expect(fastCorrectState.difficulty, greaterThanOrEqualTo(1.2));
      expect(fastCorrectState.difficulty, lessThanOrEqualTo(3.0));
    });
    
    test('updates stability correctly based on quality', () {
      final initialState = CardState.newCard(1);
      
      // 错误答题应该重置稳定度
      final wrongState = SrsAlgorithm.updateCardState(initialState, 1);
      expect(wrongState.stability, equals(1.2)); // 重置为 beta
      expect(wrongState.lapses, equals(initialState.lapses + 1));
      
      // 正确答题应该增加稳定度
      final correctState = SrsAlgorithm.updateCardState(initialState, 4);
      expect(correctState.stability, greaterThan(initialState.stability));
      expect(correctState.lapses, equals(initialState.lapses)); // 不增加失忆次数
    });
    
    test('calculates reasonable review intervals', () {
      final state = CardState.newCard(1);
      
      // 错误答题：稳定度低，难度高，间隔应该短
      final wrongState = SrsAlgorithm.updateCardState(state, 1);
      final wrongInterval = wrongState.due.difference(DateTime.now()).inDays;
      expect(wrongInterval, greaterThanOrEqualTo(1));
      expect(wrongInterval, lessThanOrEqualTo(45));
      
      // 快对：稳定度高，难度低，间隔应该长
      final fastState = SrsAlgorithm.updateCardState(state, 5);
      final fastInterval = fastState.due.difference(DateTime.now()).inDays;
      expect(fastInterval, greaterThanOrEqualTo(1));
      expect(fastInterval, lessThanOrEqualTo(45));
      expect(fastInterval, greaterThanOrEqualTo(wrongInterval));
    });
    
    test('batch updates multiple card states', () {
      final states = {
        1: CardState.newCard(1),
        2: CardState.newCard(2),
      };
      
      final attempts = [
        Attempt.correct(wordId: 1, rtMs: 1000, chosenIndex: 0, correctIndex: 0),
        Attempt.wrong(wordId: 2, rtMs: 1500, chosenIndex: 1, correctIndex: 0),
      ];
      
      final updatedStates = SrsAlgorithm.batchUpdateCardStates(
        states,
        attempts,
        2000, // timeLimit
      );
      
      expect(updatedStates.length, equals(2));
      expect(updatedStates[1]!.stability, greaterThan(states[1]!.stability));
      expect(updatedStates[2]!.lapses, equals(states[2]!.lapses + 1));
    });
    
    test('gets today deck correctly', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));
      
      final states = {
        1: CardState.newCard(1).copyWith(due: yesterday), // 到期
        2: CardState.newCard(2).copyWith(due: tomorrow), // 未到期
        3: CardState.newCard(3).copyWith(lapses: 2), // 不熟词
        4: CardState.newCard(4).markDifficult(), // 标记疑难
      };
      
      // 正常模式：包含到期词和不熟词
      final normalDeck = SrsAlgorithm.getTodayDeck(states, {'A1'}, false);
      expect(normalDeck, contains(1)); // 到期
      expect(normalDeck, isNot(contains(2))); // 未到期
      expect(normalDeck, contains(3)); // 不熟
      expect(normalDeck, contains(4)); // 标记疑难
      
      // 只练不熟模式：只包含不熟词
      final leechDeck = SrsAlgorithm.getTodayDeck(states, {'A1'}, true);
      expect(leechDeck, isNot(contains(1))); // 不包含到期词
      expect(leechDeck, contains(3)); // 不熟
      expect(leechDeck, contains(4)); // 标记疑难
    });
    
    test('predicts learning progress', () {
      final states = [
        CardState.newCard(1).copyWith(stability: 5.0), // 已学会
        CardState.newCard(2).copyWith(stability: 30.0), // 已掌握
        CardState.newCard(3).copyWith(stability: 1.0), // 未学会
      ];
      
      final progress = SrsAlgorithm.predictProgress(states);
      
      expect(progress['totalCards'], equals(3));
      expect(progress['learnedCards'], equals(1)); // stability >= 7
      expect(progress['masteredCards'], equals(1)); // stability >= 30
      expect(progress['avgStability'], equals(12.0)); // (5+30+1)/3
    });
  });
}