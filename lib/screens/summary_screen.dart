import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../session/session_models.dart';
import '../session/base_providers.dart';
import '../models/models.dart';
import '../theme/theme_style.dart';
import '../theme/theme_manager.dart';
import 'home_screen.dart';
import 'test_screen.dart';

/// 解析主题风格字符串
ThemeStyle _parseThemeStyle(String value) {
  switch (value) {
    case 'highContrast':
      return ThemeStyle.highContrast;
    case 'bauhaus':
      return ThemeStyle.bauhaus;
    case 'minimal':
      return ThemeStyle.minimal;
    case 'nature':
      return ThemeStyle.nature;
    case 'cyberpunk':
      return ThemeStyle.cyberpunk;
    default:
      return ThemeStyle.standard;
  }
}

/// 总结/复盘页面
class SummaryScreen extends ConsumerWidget {
  final SessionData sessionData;

  const SummaryScreen({
    super.key,
    required this.sessionData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = _parseThemeStyle(settings.themeStyle);
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
            _buildOverallStats(context, theme, sessionData, themeStyle, correctColor, wrongColor),
            const SizedBox(height: 24),
            if (sessionData.wrongAttempts.isNotEmpty)
              _buildWrongAttemptsList(context, theme, sessionData, ref, themeStyle, correctColor, wrongColor),
            const SizedBox(height: 24),
            _buildActionButtons(context, theme, sessionData, ref, themeStyle, wrongColor),
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
    final accuracy = sessionData.accuracy * 100;
    final avgReactionTime = sessionData.avgReactionTime;
    final totalQuestions = sessionData.attempts.length;
    final correctCount = sessionData.attempts.where((a) => a.isCorrect).length;
    final wrongCount = sessionData.wrongAttempts.length;
    final slowCorrectCount = sessionData.slowCorrectAttempts.length;
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
                        _getAccuracyColor(accuracy, correctColor, warningColor, wrongColor),
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
                          color: _getAccuracyColor(accuracy, correctColor, warningColor, wrongColor),
                        ),
                      ),
                      Text('准确率', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(context, '总题数', '$totalQuestions', Icons.quiz, theme.colorScheme.primary),
                _buildStatColumn(context, '正确', '$correctCount', Icons.check_circle, correctColor),
                _buildStatColumn(context, '错误', '$wrongCount', Icons.cancel, wrongColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(context, '平均用时', '${(avgReactionTime / 1000).toStringAsFixed(1)}s', Icons.timer, theme.colorScheme.secondary),
                _buildStatColumn(context, '勉强正确', '$slowCorrectCount', Icons.schedule, warningColor),
                _buildStatColumn(context, '配置', '${(sessionData.config.timeLimitMs / 1000).toStringAsFixed(1)}s', Icons.settings, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
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
    final wrongAttempts = sessionData.wrongAttempts;
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
                  style: theme.textTheme.headlineSmall?.copyWith(color: wrongColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...wrongAttempts.map((attempt) => 
              FutureBuilder<Word?>(
                future: wordRepo.getById(attempt.wordId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final word = snapshot.data!;
                  return _buildWrongAttemptItem(context, theme, attempt, word, themeStyle, correctColor, wrongColor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWrongAttemptItem(
    BuildContext context,
    ThemeData theme,
    Attempt attempt,
    Word word,
    ThemeStyle themeStyle,
    Color correctColor,
    Color wrongColor,
  ) {
    final isTimeout = attempt.isTimeout;
    final reactionTime = isTimeout ? '超时' : '${(attempt.rtMs / 1000).toStringAsFixed(1)}s';
    final levelBadgeColor = ThemeManager.getLevelBadgeColor(themeStyle, word.level);
    final borderRadius = ThemeManager.getBorderRadius(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wrongColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: wrongColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word.headword,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '正确答案: ${word.primaryDefinition}',
            style: theme.textTheme.bodyMedium?.copyWith(color: correctColor, fontWeight: FontWeight.w500),
          ),
          if (!isTimeout)
            Text(
              '你的选择: ${_getChosenAnswer(attempt, word)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: wrongColor),
            ),
          Text(
            '用时: $reactionTime',
            style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor),
          ),
        ],
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
    final wrongCount = sessionData.wrongAttempts.length;

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
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            // 清除测试进度
            await ref.read(appSettingsProvider.notifier).clearTestProgress();
            ref.invalidate(learningStatsProvider);
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

  Color _getAccuracyColor(double accuracy, Color correctColor, Color warningColor, Color wrongColor) {
    if (accuracy >= 80) return correctColor;
    if (accuracy >= 60) return warningColor;
    return wrongColor;
  }

  String _getChosenAnswer(Attempt attempt, Word word) {
    return '选项${String.fromCharCode(65 + attempt.chosenIndex)}';
  }

  Future<void> _practiceWrongWords(BuildContext context, WidgetRef ref, SessionData sessionData) async {
    // 清除之前的测试进度
    await ref.read(appSettingsProvider.notifier).clearTestProgress();
    if (!context.mounted) return;
    
    final wrongWordIds = sessionData.wrongAttempts.map((a) => a.wordId).toSet();
    final config = sessionData.config.copyWith(
      onlyLeeches: true,
      wordsPerSession: wrongWordIds.length,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestScreen(config: config)),
    );
  }

  Future<void> _startNewTest(BuildContext context, WidgetRef ref, SessionData sessionData) async {
    // 清除之前的测试进度
    await ref.read(appSettingsProvider.notifier).clearTestProgress();
    if (!context.mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TestScreen(config: sessionData.config)),
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
