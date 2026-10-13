import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/review_commit_repository.dart';
import '../../../models/review_event.dart';
import '../../../session/base_providers.dart';
import '../domain/fsrs_optimizer.dart';
import '../domain/fsrs_scheduler.dart';

class FsrsFitState {
  final FsrsFitResult? result;
  final bool busy;
  final String? message;

  const FsrsFitState({this.result, this.busy = false, this.message});
}

/// 记忆模型拟合：结果存在本机（不同步），每周自动重拟合一次。
///
/// 拟合结果只用来给到期词排先后，不改变到期日，所以两台设备各自拟合也
/// 不会让同步后的卡片状态分叉。
class FsrsFitController extends StateNotifier<FsrsFitState> {
  static const _prefsKey = 'fsrs_fit_v1';
  static const refitAfter = Duration(days: 7);

  final Ref _ref;

  FsrsFitController(this._ref) : super(const FsrsFitState()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final raw = (await _ref.read(
        sharedPreferencesProvider.future,
      )).getString(_prefsKey);
      if (raw != null && mounted) {
        state = FsrsFitState(
          result: FsrsFitResult.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          ),
        );
      }
    } catch (error) {
      debugPrint('Stored FSRS fit unreadable: $error');
    } finally {
      _restored.complete();
    }
  }

  final _restored = Completer<void>();

  /// 启动时调用：没拟合过或上次拟合超过一周就在后台重拟合。
  Future<void> refitIfStale() async {
    await _restored.future;
    final last = state.result?.fittedAt;
    if (last == null || DateTime.now().difference(last) > refitAfter) {
      await refit(quiet: true);
    }
  }

  Future<List<ReviewEvent>?> _events() async {
    await _ref.read(initializationProvider.future);
    final repository = _ref.read(progressRepositoryProvider);
    if (repository is! ReviewCommitRepository) return null;
    return (repository as ReviewCommitRepository).getReviewEvents();
  }

  Future<void> refit({bool quiet = false}) async {
    if (state.busy) return;
    state = FsrsFitState(result: state.result, busy: true);
    try {
      final events = await _events();
      if (events == null) {
        state = FsrsFitState(result: state.result);
        return;
      }
      // 几百次重放要一两秒，放到后台 isolate，避免卡住界面。
      final result = await Isolate.run(() => const FsrsOptimizer().fit(events));
      if (result == null) {
        if (mounted) {
          state = FsrsFitState(
            result: state.result,
            message: quiet ? null : '跨天复习记录还不够，继续学习几天后再试',
          );
        }
        return;
      }
      (await _ref.read(
        sharedPreferencesProvider.future,
      )).setString(_prefsKey, jsonEncode(result.toJson()));
      if (mounted) state = FsrsFitState(result: result);
    } catch (error) {
      debugPrint('FSRS fit failed: $error');
      if (mounted) {
        state = FsrsFitState(
          result: state.result,
          message: quiet ? null : '拟合失败：$error',
        );
      }
    }
  }
}

final fsrsFitProvider = StateNotifierProvider<FsrsFitController, FsrsFitState>(
  (ref) => FsrsFitController(ref),
);

/// 采用拟合参数时，按全部作答估计每个词此刻的回忆概率；否则为空，
/// 计划仍按到期日排序。
final recallEstimatesProvider = FutureProvider<Map<int, double>>((ref) async {
  final result = ref.watch(fsrsFitProvider.select((s) => s.result));
  if (result == null || !result.improves) return const {};
  await ref.watch(initializationProvider.future);
  final repository = ref.read(progressRepositoryProvider);
  if (repository is! ReviewCommitRepository) return const {};
  final events = await (repository as ReviewCommitRepository).getReviewEvents();
  final FsrsParameters parameters = result.parameters;
  return Isolate.run(() => FsrsOptimizer.recallEstimates(events, parameters));
});
