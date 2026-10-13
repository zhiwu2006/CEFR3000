import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../features/memory/application/recall_commit_service.dart';
import '../features/memory/domain/recall_models.dart';
import '../models/attempt.dart';
import '../models/word.dart';
import '../session/base_providers.dart';
import '../session/session_models.dart';

class ActiveRecallArgs {
  final SessionConfig config;
  final List<int> wordIds;

  const ActiveRecallArgs({required this.config, required this.wordIds});
}

/// 主动回忆学习流：先隐藏答案回忆，再揭示答案并进行自评。
class ActiveRecallScreen extends ConsumerStatefulWidget {
  final SessionConfig config;
  final List<int> wordIds;

  const ActiveRecallScreen({
    super.key,
    required this.config,
    required this.wordIds,
  });

  @override
  ConsumerState<ActiveRecallScreen> createState() => _ActiveRecallScreenState();
}

class _ActiveRecallScreenState extends ConsumerState<ActiveRecallScreen> {
  late final String _sessionId;
  late final RecallCommitService _commitService;
  List<Word> _words = const [];
  int _index = 0;
  bool _revealed = false;

  /// 用户在看到答案前是否声称已回忆出来。
  /// true = 独立回忆（显示答案仅用于验证），false = 依赖答案。
  bool _recalledBeforeReveal = false;
  bool _loading = true;
  bool _committing = false;
  DateTime? _startedAt;
  Object? _error;

  Word? get _current => _index < _words.length ? _words[_index] : null;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    final progress = ref.read(progressRepositoryProvider);
    _commitService = RecallCommitService(
      progressRepository: progress,
      config: widget.config.srsConfig,
    );
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final repository = ref.read(wordRepositoryProvider);
      // The caller passes the already qualified, budgeted plan. An empty
      // plan is a real "nothing due/eligible" result; refilling it with the
      // whole level would bypass suspended words and the daily new-word cap.
      final words = widget.wordIds.isEmpty
          ? const <Word>[]
          : await repository.getByIds(widget.wordIds);
      if (!mounted) return;
      setState(() {
        _words = words.take(widget.config.wordsPerSession).toList();
        _loading = false;
        _startedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  /// 用户做出预判后揭示答案。
  /// [recalled] 为 true 表示用户声称已独立回忆出答案（仅验证）。
  void _revealWithJudgment({required bool recalled}) {
    if (_committing || _current == null) return;
    setState(() {
      _recalledBeforeReveal = recalled;
      _revealed = true;
    });
  }

  Future<void> _submit(RecallRating rating) async {
    final word = _current;
    if (_committing || word == null) return;
    setState(() => _committing = true);
    final timestamp = DateTime.now();
    final reactionTime = timestamp
        .difference(_startedAt ?? timestamp)
        .inMilliseconds
        .clamp(0, 120000);
    final attempt = Attempt(
      wordId: word.id,
      result: rating == RecallRating.forgot
          ? AttemptResult.wrong
          : AttemptResult.correct,
      rtMs: reactionTime,
      chosenIndex: rating == RecallRating.forgot ? -1 : 0,
      correctIndex: 0,
      timestamp: timestamp,
    );

    try {
      final receipt = await _commitService.commitAttempt(
        sessionId: _sessionId,
        attempt: attempt,
        timeLimitMs: widget.config.timeLimitMs,
        slowThreshold: widget.config.slowThreshold,
        // 若用户在揭示答案前声称已回忆出来（_recalledBeforeReveal），
        // 则视为独立回忆，answerRevealed = false；否则为辅助回忆。
        answerRevealed: !_recalledBeforeReveal,
        hintUsed: false,
        taskType: ReviewTaskType.recall,
        skill: LearningSkill.meaningRecall,
        source: EvaluationSource.selfReport,
        ratingOverride: rating,
      );
      if (receipt.firstExposureToday) {
        await ref.read(appSettingsProvider.notifier).consumeDailyNew(1);
      }
      if (!mounted) return;
      if (_index + 1 >= _words.length) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _index++;
        _revealed = false;
        _recalledBeforeReveal = false;
        _committing = false;
        _startedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _committing = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('主动回忆')),
        body: Center(child: Text('无法保存本次回忆：$_error')),
      );
    }
    final word = _current;
    if (word == null) {
      return const Scaffold(body: Center(child: Text('今日没有可复习的词条')));
    }
    final theme = Theme.of(context);
    final progress = '${_index + 1}/${_words.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('主动回忆'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(progress)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (_index + 1) / _words.length),
              const Spacer(),
              Text(
                word.headword,
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                word.pos,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 36),
              if (!_revealed)
                Column(
                  children: [
                    Text(
                      '先在心里回忆中文含义',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _revealWithJudgment(recalled: true),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('想起来了'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () => _revealWithJudgment(recalled: false),
                          icon: const Icon(Icons.help_outline),
                          label: const Text('没想起来'),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Chip(
                      avatar: Icon(
                        _recalledBeforeReveal ? Icons.star : Icons.visibility,
                        size: 16,
                      ),
                      label: Text(
                        _recalledBeforeReveal ? '独立回忆 · 验证答案' : '辅助回忆',
                      ),
                      backgroundColor: _recalledBeforeReveal
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      word.cnDefs.join('；'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text('这次回忆的感觉如何？', textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ratingButton('没想起', RecallRating.forgot, Colors.red),
                        _ratingButton(
                          '费力想起',
                          RecallRating.difficult,
                          Colors.orange,
                        ),
                        _ratingButton(
                          '想起',
                          RecallRating.recalled,
                          Colors.green,
                        ),
                        _ratingButton('很轻松', RecallRating.easy, Colors.blue),
                      ],
                    ),
                  ],
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingButton(String label, RecallRating rating, Color color) {
    return OutlinedButton(
      onPressed: _committing ? null : () => _submit(rating),
      style: OutlinedButton.styleFrom(foregroundColor: color),
      child: Text(label),
    );
  }
}
