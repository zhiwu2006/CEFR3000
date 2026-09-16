import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_models.dart';
import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import 'home_screen.dart';
import 'test_screen.dart';

/// 总结/复盘页面
class SummaryScreen extends ConsumerWidget {
  final SessionData sessionData;

  const SummaryScreen({super.key, required this.sessionData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = ThemeStyle.fromString(settings.themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);

    return Scaffold(
      appBar: AppBar(
        title: const Text('测试总结'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              // 清除测试进度
              await ref.read(appSettingsProvider.notifier).clearTestProgress();
              ref.invalidate(learningStatsProvider);
              ref.invalidate(dailyHistorySummariesProvider);
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverallStats(
              context,
              theme,
              sessionData,
              themeStyle,
              correctColor,
              wrongColor,
            ),
            const SizedBox(height: 24),
            if (sessionData.firstWrongAttempts.isNotEmpty)
              _buildWrongAttemptsList(
                context,
                theme,
                sessionData,
                ref,
                themeStyle,
                correctColor,
                wrongColor,
              ),
            const SizedBox(height: 24),
            _buildActionButtons(
              context,
              theme,
              sessionData,
              ref,
              themeStyle,
              wrongColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    ThemeStyle themeStyle,
    Color correctColor,
    Color wrongColor,
  ) {
    final accuracy = sessionData.firstAccuracy * 100;
    final avgReactionTime = sessionData.avgReactionTime;
    final totalWords = sessionData.firstAttempts.length;
    final totalAttempts = sessionData.attempts.length;
    final correctCount = sessionData.firstAttempts
        .where((a) => a.isCorrect)
        .length;
    final wrongCount = sessionData.firstWrongWordIds.length;
    final slowCorrectCount = sessionData.firstSlowCorrectAttempts.length;
    final warningColor = ThemeManager.getWarningColor(themeStyle);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: accuracy / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getAccuracyColor(
                          accuracy,
                          correctColor,
                          warningColor,
                          wrongColor,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${accuracy.round()}%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getAccuracyColor(
                            accuracy,
                            correctColor,
                            warningColor,
                            wrongColor,
                          ),
                        ),
                      ),
                      Text('准确率', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 24,
              runSpacing: 16,
              children: [
                _buildStatColumn(
                  context,
                  '总题数',
                  '$totalWords',
                  Icons.quiz,
                  theme.colorScheme.primary,
                ),
                _buildStatColumn(
                  context,
                  '正确',
                  '$correctCount',
                  Icons.check_circle,
                  correctColor,
                ),
                _buildStatColumn(
                  context,
                  '错误',
                  '$wrongCount',
                  Icons.cancel,
                  wrongColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 24,
              runSpacing: 16,
              children: [
                if (totalAttempts > totalWords)
                  _buildStatColumn(
                    context,
                    '总作答',
                    '$totalAttempts',
                    Icons.repeat,
                    theme.colorScheme.primary,
                  ),
                _buildStatColumn(
                  context,
                  '纠错成功',
                  '${sessionData.correctedWordIds.length}',
                  Icons.auto_fix_high,
                  correctColor,
                ),
                _buildStatColumn(
                  context,
                  '平均用时',
                  '${(avgReactionTime / 1000).toStringAsFixed(1)}s',
                  Icons.timer,
                  theme.colorScheme.secondary,
                ),
                _buildStatColumn(
                  context,
                  '勉强正确',
                  '$slowCorrectCount',
                  Icons.schedule,
                  warningColor,
                ),
                _buildStatColumn(
                  context,
                  '配置',
                  '${(sessionData.config.timeLimitMs / 1000).toStringAsFixed(1)}s',
                  Icons.settings,
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildWrongAttemptsList(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    WidgetRef ref,
    ThemeStyle themeStyle,
    Color correctColor,
    Color wrongColor,
  ) {
    final wrongAttempts = sessionData.firstWrongAttempts;
    final wordRepo = ref.read(wordRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: wrongColor),
                const SizedBox(width: 8),
                Text(
                  '错题回顾 (${wrongAttempts.length})',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: wrongColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...wrongAttempts.map(
              (attempt) => FutureBuilder<Word?>(
                future: wordRepo.getById(attempt.wordId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final word = snapshot.data!;
                  return _WrongAttemptItem(
                    attempt: attempt,
                    word: word,
                    themeStyle: themeStyle,
                    correctColor: correctColor,
                    wrongColor: wrongColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    SessionData sessionData,
    WidgetRef ref,
    ThemeStyle themeStyle,
    Color wrongColor,
  ) {
    final wrongCount = sessionData.firstWrongWordIds.length;

    return Column(
      children: [
        if (wrongCount > 0) ...[
          ElevatedButton.icon(
            onPressed: () => _practiceWrongWords(context, ref, sessionData),
            icon: const Icon(Icons.replay),
            label: Text('只练错题 ($wrongCount 词)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: wrongColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: () => _startNewTest(context, ref, sessionData),
          icon: const Icon(Icons.refresh),
          label: const Text('重新测试'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(dailyHistorySummariesProvider);
            Navigator.of(context).pushNamed('/daily_history');
          },
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('查看每日档案与重点复盘'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            // 清除测试进度
            await ref.read(appSettingsProvider.notifier).clearTestProgress();
            ref.invalidate(learningStatsProvider);
            ref.invalidate(dailyHistorySummariesProvider);
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
          icon: const Icon(Icons.home),
          label: const Text('回到首页'),
        ),
      ],
    );
  }

  Color _getAccuracyColor(
    double accuracy,
    Color correctColor,
    Color warningColor,
    Color wrongColor,
  ) {
    if (accuracy >= 80) return correctColor;
    if (accuracy >= 60) return warningColor;
    return wrongColor;
  }

  Future<void> _practiceWrongWords(
    BuildContext context,
    WidgetRef ref,
    SessionData sessionData,
  ) async {
    final wrongWordIds = sessionData.firstWrongAttempts
        .map((a) => a.wordId)
        .toSet()
        .toList();
    if (wrongWordIds.isEmpty) return;

    final sessionId = await ref
        .read(appSettingsProvider.notifier)
        .stageCustomSession(wrongWordIds);
    if (!context.mounted) return;

    if (sessionId.isNotEmpty) {
      final config = sessionData.config.copyWith(
        onlyLeeches: true,
        wordsPerSession: wrongWordIds.length,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TestScreen(config: config)),
      );
    }
  }

  Future<void> _startNewTest(
    BuildContext context,
    WidgetRef ref,
    SessionData sessionData,
  ) async {
    // 清除之前的测试进度
    await ref.read(appSettingsProvider.notifier).clearTestProgress();
    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestScreen(config: sessionData.config)),
    );
  }
}

class _WrongAttemptItem extends ConsumerStatefulWidget {
  final Attempt attempt;
  final Word word;
  final ThemeStyle themeStyle;
  final Color correctColor;
  final Color wrongColor;

  const _WrongAttemptItem({
    required this.attempt,
    required this.word,
    required this.themeStyle,
    required this.correctColor,
    required this.wrongColor,
  });

  @override
  ConsumerState<_WrongAttemptItem> createState() => _WrongAttemptItemState();
}

class _WrongAttemptItemState extends ConsumerState<_WrongAttemptItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attempt = widget.attempt;
    final word = widget.word;
    final isTimeout = attempt.isTimeout;
    final reactionTime = isTimeout
        ? '超时'
        : '${(attempt.rtMs / 1000).toStringAsFixed(1)}s';
    final levelBadgeColor = ThemeManager.getLevelBadgeColor(
      widget.themeStyle,
      word.level,
    );
    final borderRadius = ThemeManager.getBorderRadius(widget.themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(
      widget.themeStyle,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.wrongColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: widget.wrongColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word.headword,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: levelBadgeColor,
                  borderRadius: BorderRadius.circular(borderRadius * 0.5),
                ),
                child: Text(
                  word.level,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案: ${word.primaryDefinition}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.correctColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isTimeout)
            Text(
              '你的选择: ${_getChosenAnswer(attempt, word)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: widget.wrongColor,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '用时: $reactionTime',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.smart_toy_outlined,
                  size: 16,
                ),
                label: Text(_isExpanded ? '收起' : 'AI 助记'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 12),
            _ExplanationContent(word: word),
          ],
        ],
      ),
    );
  }

  String _getChosenAnswer(Attempt attempt, Word word) {
    return '选项${String.fromCharCode(65 + attempt.chosenIndex)}';
  }
}

class _ExplanationContent extends ConsumerWidget {
  final Word word;

  const _ExplanationContent({required this.word});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final explanationAsync = ref.watch(wordExplanationProvider(word));

    return explanationAsync.when(
      data: (explanation) {
        if (explanation.error != null) {
          String msg = '加载失败';
          if (explanation.error == 'missing_api_key') {
            msg = '未设置 API Key';
          } else if (explanation.error!.startsWith('http_')) {
            msg = '请求失败 (${explanation.error})';
          } else if (explanation.error == 'empty_response') {
            msg = '无响应内容';
          } else if (explanation.error == 'request_failed') {
            msg = '网络请求失败';
          }
          return _buildError(context, msg);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (explanation.shortMeaning.isNotEmpty) ...[
              _buildSection(
                context,
                '核心含义',
                explanation.ipa.isNotEmpty
                    ? '[${explanation.ipa}] ${explanation.shortMeaning}'
                    : explanation.shortMeaning,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation.definitionEn.isNotEmpty) ...[
              _buildSection(context, '英文释义', explanation.definitionEn),
              const SizedBox(height: 8),
            ],
            if (explanation.exampleEn.isNotEmpty ||
                explanation.exampleCn.isNotEmpty) ...[
              _buildExampleSection(
                context,
                explanation.exampleEn,
                explanation.exampleCn,
              ),
              const SizedBox(height: 8),
            ],
            if (explanation.nuance.isNotEmpty) ...[
              _buildSection(context, '细微差别', explanation.nuance),
              const SizedBox(height: 8),
            ],
            if (explanation.collocations.isNotEmpty)
              _buildSection(
                context,
                '常见搭配',
                explanation.collocations.join(', '),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, stack) => _buildError(context, '加载出错: $err'),
    );
  }

  Widget _buildError(BuildContext context, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(content, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildExampleSection(BuildContext context, String en, String cn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '例句',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        if (en.isNotEmpty) Text(en, style: const TextStyle(fontSize: 13)),
        if (cn.isNotEmpty)
          Text(cn, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

extension SessionConfigCopyWith on SessionConfig {
  SessionConfig copyWith({
    Set<String>? levels,
    int? wordsPerSession,
    int? timeLimitMs,
    String? orderPolicy,
    bool? onlyLeeches,
    int? wrongDelay,
    int? slowDelay,
    double? slowThreshold,
    double? newCardRatio,
    int? dailyNewLimit,
    bool? ttsAutoPlay,
    bool? ttsOnWrong,
    int? leechLapsesThreshold,
    bool? leechIncludeMarked,
  }) {
    return SessionConfig(
      levels: levels ?? this.levels,
      wordsPerSession: wordsPerSession ?? this.wordsPerSession,
      timeLimitMs: timeLimitMs ?? this.timeLimitMs,
      orderPolicy: orderPolicy ?? this.orderPolicy,
      onlyLeeches: onlyLeeches ?? this.onlyLeeches,
      wrongDelay: wrongDelay ?? this.wrongDelay,
      slowDelay: slowDelay ?? this.slowDelay,
      slowThreshold: slowThreshold ?? this.slowThreshold,
      newCardRatio: newCardRatio ?? this.newCardRatio,
      dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
      ttsAutoPlay: ttsAutoPlay ?? this.ttsAutoPlay,
      ttsOnWrong: ttsOnWrong ?? this.ttsOnWrong,
      leechLapsesThreshold: leechLapsesThreshold ?? this.leechLapsesThreshold,
      leechIncludeMarked: leechIncludeMarked ?? this.leechIncludeMarked,
    );
  }
}
