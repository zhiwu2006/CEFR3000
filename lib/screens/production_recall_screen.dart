import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../features/lexicon/domain/content_eligibility.dart';
import '../features/lexicon/domain/production_hint_helper.dart';
import '../features/memory/application/recall_commit_service.dart';
import '../features/memory/domain/recall_models.dart';
import '../models/attempt.dart';
import '../models/word.dart';
import '../session/base_providers.dart';
import '../session/session_models.dart';
import '../widgets/word_slot_input.dart';

class ProductionRecallArgs {
  final SessionConfig config;
  final List<int> wordIds;
  final bool allowLegacyFallback;

  const ProductionRecallArgs({
    required this.config,
    required this.wordIds,
    this.allowLegacyFallback = true,
  });
}

/// 英文产出题（看义拼词）。
/// 包含下划线字母槽位与三阶渐进式提示机制（辅音 -> 元音 -> 全词）。
class ProductionRecallScreen extends ConsumerStatefulWidget {
  final SessionConfig config;
  final List<int> wordIds;
  final bool allowLegacyFallback;

  const ProductionRecallScreen({
    super.key,
    required this.config,
    required this.wordIds,
    this.allowLegacyFallback = true,
  });

  @override
  ConsumerState<ProductionRecallScreen> createState() =>
      _ProductionRecallScreenState();
}

class _ProductionRecallScreenState
    extends ConsumerState<ProductionRecallScreen> {
  late final String _sessionId;
  late final RecallCommitService _commitService;
  final GlobalKey<WordSlotInputState> _slotKey = GlobalKey<WordSlotInputState>();
  String _currentAnswer = '';
  int _hintLevel = 0; // 0: 无提示, 1: 辅音骨架, 2: 元音透视, 3: 全词补全
  Set<int> _revealedIndices = const {};
  List<Word> _words = const [];
  int _index = 0;
  bool _loading = true;
  bool _committing = false;
  bool _submitted = false;
  bool _correct = false;
  String? _error;
  DateTime? _startedAt;

  Word? get _current => _index < _words.length ? _words[_index] : null;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _commitService = RecallCommitService(
      progressRepository: ref.read(progressRepositoryProvider),
      config: widget.config.srsConfig,
    );
    _loadWords();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      final repository = ref.read(wordRepositoryProvider);
      // The caller passes the already qualified skill plan. An empty plan is
      // a real "nothing due/eligible" result; do not silently refill it with
      // every word and bypass suspended items or the time budget.
      final candidates = widget.wordIds.isEmpty
          ? const <Word>[]
          : await repository.getByIds(widget.wordIds);
      final words = candidates
          .where(
            (word) => ContentEligibility.productionForWord(
              word,
              allowLegacyFallback: widget.allowLegacyFallback,
            ).enabled,
          )
          .take(widget.config.wordsPerSession)
          .toList();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
        _startedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _useNextHint() {
    final word = _current;
    if (_committing || _submitted || word == null || _hintLevel >= 3) return;
    setState(() {
      _hintLevel++;
      _revealedIndices = ProductionHintHelper.getRevealedIndices(
        word.headword,
        _hintLevel,
      );
      if (_hintLevel >= 3) {
        _currentAnswer = word.headword;
      }
    });
  }

  Future<void> _submit() async {
    final word = _current;
    if (_committing || _submitted || word == null) return;
    final eligibility = ContentEligibility.productionForWord(
      word,
      allowLegacyFallback: widget.allowLegacyFallback,
    );
    final answer = _currentAnswer.trim().isNotEmpty
        ? _currentAnswer
        : (_slotKey.currentState?.currentAnswer ?? '');
    final correct = ContentEligibility.matches(
      answer,
      eligibility.acceptedAnswers,
    );
    setState(() => _committing = true);
    final timestamp = DateTime.now();
    final reactionTime = timestamp
        .difference(_startedAt ?? timestamp)
        .inMilliseconds
        .clamp(0, 120000);
    final attempt = Attempt(
      wordId: word.id,
      result: correct ? AttemptResult.correct : AttemptResult.wrong,
      rtMs: reactionTime,
      chosenIndex: correct ? 0 : -1,
      correctIndex: 0,
      timestamp: timestamp,
    );

    // 根据提示级别精准定级 FSRS 认知负荷
    final RecallRating rating;
    if (!correct || _hintLevel >= 3) {
      rating = RecallRating.forgot;
    } else if (_hintLevel > 0) {
      rating = RecallRating.difficult;
    } else {
      rating = RecallRating.recalled;
    }

    try {
      final receipt = await _commitService.commitAttempt(
        sessionId: _sessionId,
        attempt: attempt,
        timeLimitMs: widget.config.timeLimitMs,
        slowThreshold: widget.config.slowThreshold,
        hintUsed: _hintLevel > 0,
        answerRevealed: _hintLevel >= 3,
        taskType: ReviewTaskType.production,
        skill: LearningSkill.englishProduction,
        source: eligibility.requiresSelfCheck
            ? EvaluationSource.selfReport
            : EvaluationSource.objective,
        ratingOverride: rating,
        contentVersion: eligibility.requiresSelfCheck
            ? 'legacy-fallback-v1'
            : 'reviewed-v1',
      );
      if (receipt.firstExposureToday) {
        await ref.read(appSettingsProvider.notifier).consumeDailyNew(1);
      }
      if (!mounted) return;
      setState(() {
        _committing = false;
        _submitted = true;
        _correct = correct;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _committing = false;
        _error = '$error';
      });
    }
  }

  void _next() {
    if (!_submitted) return;
    if (_index + 1 >= _words.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _submitted = false;
      _correct = false;
      _hintLevel = 0;
      _revealedIndices = const {};
      _currentAnswer = '';
      _startedAt = DateTime.now();
    });
    _slotKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('看义拼词')),
        body: Center(child: Text('无法保存本次练习：$_error')),
      );
    }
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('看义拼词')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '当前范围没有满足内容资格的看义拼词题。\n请先审核词条的义项和例句，再开启此题型。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final word = _current!;
    final eligibility = ContentEligibility.productionForWord(
      word,
      allowLegacyFallback: widget.allowLegacyFallback,
    );
    final theme = Theme.of(context);
    final progress = '${_index + 1}/${_words.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('看义拼词'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(progress)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            LinearProgressIndicator(value: (_index + 1) / _words.length),
            const SizedBox(height: 28),
            Text(
              '根据中文释义拼写英文单词',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              eligibility.prompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (eligibility.requiresSelfCheck) ...[
              const SizedBox(height: 8),
              Text(
                '传统词库基础练习 · 请结合释义自行核对',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
            const SizedBox(height: 32),

            // 字母槽位输入区域
            WordSlotInput(
              key: _slotKey,
              targetWord: word.headword,
              revealedIndices: _revealedIndices,
              enabled: !_submitted && !_committing,
              isSubmitted: _submitted,
              isCorrect: _correct,
              onChanged: (val) {
                _currentAnswer = val;
              },
              onSubmitted: (val) {
                _currentAnswer = val;
                _submit();
              },
            ),
            const SizedBox(height: 28),

            // 操作区（提示按钮 + 提交按钮）
            if (!_submitted) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _committing || _hintLevel >= 3 ? null : _useNextHint,
                    icon: Icon(
                      _hintLevel >= 3
                          ? Icons.lightbulb_outline
                          : Icons.lightbulb_rounded,
                      color: _hintLevel >= 3
                          ? Colors.grey
                          : const Color(0xFFD97706),
                    ),
                    label: Text(
                      switch (_hintLevel) {
                        0 => '提示 (1/3: 辅音骨架)',
                        1 => '提示 (2/3: 关键元音)',
                        2 => '提示 (3/3: 补全全词)',
                        _ => '已全词补全',
                      },
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _hintLevel >= 3
                            ? Colors.grey
                            : const Color(0xFFD97706),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _hintLevel >= 3
                            ? Colors.grey.withValues(alpha: 0.4)
                            : const Color(0xFFD97706),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _committing ? null : _submit,
                    icon: const Icon(Icons.check),
                    label: Text(_committing ? '保存中…' : '提交答案'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Icon(
                _correct ? Icons.check_circle : Icons.info_outline,
                color: _correct
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                _correct ? '回答正确！' : '这次没有匹配，正确答案是：${word.headword}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _correct
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _next,
                child: Text(_index + 1 >= _words.length ? '完成' : '下一词'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
