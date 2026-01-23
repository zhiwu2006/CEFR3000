import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'session_models.dart';

class DelayedReplayManager {
  const DelayedReplayManager();

  bool shouldDelayWord(Attempt attempt, SessionConfig config) {
    if (attempt.isWrong || attempt.isTimeout) {
      return true;
    }

    if (attempt.isCorrect) {
      final slowThreshold = config.timeLimitMs * config.slowThreshold;
      return attempt.rtMs > slowThreshold;
    }

    return false;
  }

  List<DelayedItem> scheduleDelayedReplay({
    required List<DelayedItem> delayedQueue,
    required Attempt attempt,
    required SessionConfig config,
  }) {
    final existingIndex = delayedQueue.indexWhere(
      (item) => item.wordId == attempt.wordId,
    );

    int delay;
    if (attempt.isWrong || attempt.isTimeout) {
      delay = config.wrongDelay;
    } else {
      delay = config.slowDelay;
    }

    if (existingIndex >= 0) {
      final existingItem = delayedQueue[existingIndex];

      if (attempt.isWrong || attempt.isTimeout) {
        delay = max(2, existingItem.afterN ~/ 2);
      } else {
        delay = existingItem.afterN + 3;
      }

      final updatedDelayed = List<DelayedItem>.from(delayedQueue);
      updatedDelayed[existingIndex] = existingItem.copyWith(afterN: delay);
      return updatedDelayed;
    }

    return [...delayedQueue, DelayedItem(wordId: attempt.wordId, afterN: delay)];
  }

  ({List<Word> mainQueue, List<DelayedItem> delayedQueue}) processDelayedQueue({
    required List<Word> mainQueue,
    required List<DelayedItem> delayedQueue,
    required List<Word> candidatePool,
  }) {
    if (delayedQueue.isEmpty) {
      return (mainQueue: mainQueue, delayedQueue: delayedQueue);
    }

    final updatedDelayed = delayedQueue
        .map((item) => item.copyWith(afterN: item.afterN - 1))
        .toList();

    final maturedItems = updatedDelayed
        .where((item) => item.afterN <= 0)
        .toList();
    final stillDelayed = updatedDelayed
        .where((item) => item.afterN > 0)
        .toList();

    if (maturedItems.isEmpty) {
      return (mainQueue: mainQueue, delayedQueue: stillDelayed);
    }

    final insertPosition = min(2, mainQueue.length);
    final newMainQueue = List<Word>.from(mainQueue);

    for (final item in maturedItems.reversed) {
      Word? word;
      try {
        word = candidatePool.firstWhere((w) => w.id == item.wordId);
      } catch (_) {
        word = null;
      }

      if (word != null) {
        newMainQueue.insert(insertPosition, word);
      } else {
        debugPrint('Warning: Could not find word ${item.wordId} for delayed replay, skipping');
      }
    }

    return (mainQueue: newMainQueue, delayedQueue: stillDelayed);
  }
}
