import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../session/base_providers.dart';
import '../session/session_models.dart';
import '../theme/theme_manager.dart';
import '../theme/theme_style.dart';
import '../widgets/calendar/pocket_calendar_widget.dart';
import 'test_screen.dart';

/// 每日测试档案与重点单词复盘二级页面
class DailyHistoryScreen extends ConsumerStatefulWidget {
  const DailyHistoryScreen({super.key});

  @override
  ConsumerState<DailyHistoryScreen> createState() => _DailyHistoryScreenState();
}

class _DailyHistoryScreenState extends ConsumerState<DailyHistoryScreen> {
  int _selectedTabIndex = 0; // 0: 重点单词, 1: 轮次测试
  DateTime? _selectedDate;
  bool _showCalendarView = true; // 是否展示日历看板模式（默认置顶展示）

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final themeStyle = ThemeStyle.fromString(settings.themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);
    final gradientColors = ThemeManager.getGradientColors(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final wrongColor = ThemeManager.getWrongColor(themeStyle);

    final summariesAsync = ref.watch(dailyHistorySummariesProvider);

    return Scaffold(
      backgroundColor: ThemeManager.getBackgroundColor(themeStyle),
      appBar: AppBar(
        title: Text(
          '每日学习复盘',
          style: TextStyle(
            color: ThemeManager.getHeaderTextColor(themeStyle),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ThemeManager.getHeaderTextColor(themeStyle),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendarView
                  ? Icons.view_agenda_rounded
                  : Icons.calendar_month_rounded,
              color: ThemeManager.getHeaderTextColor(themeStyle),
            ),
            tooltip: _showCalendarView ? '时间轴视图' : '日历看板视图',
            onPressed: () {
              setState(() {
                _showCalendarView = !_showCalendarView;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: ThemeManager.getHeaderTextColor(themeStyle),
            ),
            tooltip: '生成演示数据',
            onPressed: () async {
              await ref.read(dailyHistoryServiceProvider).seedDemoHistoryData();
              ref.invalidate(dailyHistorySummariesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已生成多日演练复盘数据！')));
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: ThemeManager.getHeaderTextColor(themeStyle),
            ),
            tooltip: '刷新记录',
            onPressed: () => ref.refresh(dailyHistorySummariesProvider),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
      ),
      body: summariesAsync.when(
        data: (summaries) {
          if (summaries.isEmpty) {
            return _buildEmptyState(
              context,
              themeStyle,
              textColor,
              secondaryTextColor,
            );
          }

          // 默认选中第一天（最新的一天）
          final activeDate = _selectedDate ?? summaries.first.date;
          final currentSummary = summaries.firstWhere(
            (s) => _isSameDay(s.date, activeDate),
            orElse: () => summaries.first,
          );

          return Column(
            children: [
              // 主体可滚动区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. 置顶月度学习日历看板（最上面第一个显示）
                      if (_showCalendarView) ...[
                        PocketCalendarWidget(
                          summaries: summaries,
                          themeStyle: themeStyle,
                          onOpenDailyHistory: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 2. 顶部水平日期快捷选择栏
                      _buildDateSelector(
                        summaries,
                        currentSummary.date,
                        themeStyle,
                      ),
                      const SizedBox(height: 12),

                      // 3. 当日综合看板
                      _buildDailyOverviewCard(
                        context,
                        currentSummary,
                        themeStyle,
                        textColor,
                        secondaryTextColor,
                        correctColor,
                      ),
                      const SizedBox(height: 16),

                      // 4. 分段控制器 (Tab: 重点单词 vs 轮次明细)
                      _buildSegmentTabs(
                        currentSummary,
                        themeStyle,
                        textColor,
                        wrongColor,
                      ),
                      const SizedBox(height: 16),

                      // 内容区域
                      if (_selectedTabIndex == 0)
                        _buildFocusWordsView(
                          context,
                          currentSummary,
                          themeStyle,
                          textColor,
                          secondaryTextColor,
                          wrongColor,
                        )
                      else
                        _buildSessionsView(
                          context,
                          currentSummary,
                          themeStyle,
                          textColor,
                          secondaryTextColor,
                          correctColor,
                          wrongColor,
                        ),
                    ],
                  ),
                ),
              ),

              // 3. 底部吸底操作栏（仅在重点单词 Tab 且有重点词时展示）
              if (_selectedTabIndex == 0 &&
                  currentSummary.focusWords.isNotEmpty)
                _buildBottomActionBar(
                  context,
                  currentSummary.focusWords,
                  themeStyle,
                  wrongColor,
                ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: ThemeManager.getPrimaryColor(themeStyle),
          ),
        ),
        error: (err, stack) => Center(
          child: Text('数据加载失败: $err', style: TextStyle(color: textColor)),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return '今日 (${date.month}/${date.day})';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) {
      return '昨日 (${date.month}/${date.day})';
    }
    return '${date.month}月${date.day}日';
  }

  /// 顶部日期横向滑动选择栏
  Widget _buildDateSelector(
    List<DailyHistorySummary> summaries,
    DateTime selectedDate,
    ThemeStyle themeStyle,
  ) {
    final primaryColor = ThemeManager.getPrimaryColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: ThemeManager.getBorderColor(
              themeStyle,
            ).withValues(alpha: 0.1),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: summaries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final summary = summaries[index];
          final isSelected = _isSameDay(summary.date, selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = summary.date;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : ThemeManager.getBorderColor(
                          themeStyle,
                        ).withValues(alpha: 0.3),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    _formatDateLabel(summary.date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : ThemeManager.getTextColor(themeStyle),
                    ),
                  ),
                  if (summary.focusWords.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 当日综合数据卡片
  Widget _buildDailyOverviewCard(
    BuildContext context,
    DailyHistorySummary summary,
    ThemeStyle themeStyle,
    Color textColor,
    Color secondaryTextColor,
    Color correctColor,
  ) {
    final minutes = (summary.totalDurationMs / 60000).ceil();
    final accPercent = (summary.averageAccuracy * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(themeStyle, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDateLabel(summary.date)} 学习战报',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: correctColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '综合正确率 $accPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: correctColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                '测试轮次',
                '${summary.sessionCount} 轮',
                Icons.repeat,
                textColor,
                secondaryTextColor,
              ),
              _buildMetricItem(
                '累计测词',
                '${summary.totalWordsTested} 个',
                Icons.format_list_numbered,
                textColor,
                secondaryTextColor,
              ),
              _buildMetricItem(
                '专注用时',
                '$minutes 分钟',
                Icons.timer_outlined,
                textColor,
                secondaryTextColor,
              ),
              _buildMetricItem(
                '待巩固重点',
                '${summary.focusWords.length} 词',
                Icons.priority_high,
                textColor,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color textColor,
    Color accentColor,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: accentColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// 分段控制器
  Widget _buildSegmentTabs(
    DailyHistorySummary summary,
    ThemeStyle themeStyle,
    Color textColor,
    Color wrongColor,
  ) {
    final primaryColor = ThemeManager.getPrimaryColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeManager.getBorderColor(themeStyle).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: _selectedTabIndex == 0
                            ? Colors.white
                            : wrongColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '重点记忆单词 (${summary.focusWords.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 0
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? primaryColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: _selectedTabIndex == 1
                            ? Colors.white
                            : textColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '每轮测试明细 (${summary.sessionCount})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 重点单词视图
  Widget _buildFocusWordsView(
    BuildContext context,
    DailyHistorySummary summary,
    ThemeStyle themeStyle,
    Color textColor,
    Color secondaryTextColor,
    Color wrongColor,
  ) {
    if (summary.focusWords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: ThemeManager.getCardDecoration(themeStyle),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 56,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              '太棒了！今日无待巩固重点单词',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '今日所有测试均保持了极高流利度与准确率',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return Column(
      children: summary.focusWords.map((item) {
        return _buildFocusWordCard(
          context,
          item,
          themeStyle,
          textColor,
          secondaryTextColor,
          wrongColor,
        );
      }).toList(),
    );
  }

  /// 单个重点单词卡片
  Widget _buildFocusWordCard(
    BuildContext context,
    FocusWordItem item,
    ThemeStyle themeStyle,
    Color textColor,
    Color secondaryTextColor,
    Color wrongColor,
  ) {
    final word = item.word;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(themeStyle, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 单词拼写
              Expanded(
                child: Row(
                  children: [
                    Text(
                      word.headword,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // CEFR 难度标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        word.level,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    if (word.pos.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        word.pos,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 发音按钮
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 22),
                color: ThemeManager.getPrimaryColor(themeStyle),
                tooltip: '播放发音',
                onPressed: () {
                  ref.read(ttsServiceProvider).speak(word.headword);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 中文释义
          Text(
            word.cnDefs.isNotEmpty
                ? word.cnDefs.join('； ')
                : word.primaryDefinition,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          // 归因原因标签组
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: item.reasons.map((reason) {
              Color tagBgColor;
              Color tagTextColor;
              String tagText;

              switch (reason) {
                case FocusWordReason.wrong:
                  tagBgColor = Colors.red.withValues(alpha: 0.15);
                  tagTextColor = Colors.redAccent;
                  tagText = '本次答错';
                  break;
                case FocusWordReason.timeout:
                  tagBgColor = Colors.orange.withValues(alpha: 0.15);
                  tagTextColor = Colors.orange;
                  tagText = '答题超时';
                  break;
                case FocusWordReason.hesitation:
                  tagBgColor = Colors.amber.withValues(alpha: 0.2);
                  tagTextColor = Colors.brown;
                  final sec = ((item.reactionTimeMs ?? 0) / 1000)
                      .toStringAsFixed(1);
                  tagText = '迟疑答对 (${sec}s)';
                  break;
                case FocusWordReason.frequentFail:
                  tagBgColor = Colors.purple.withValues(alpha: 0.15);
                  tagTextColor = Colors.purpleAccent;
                  tagText = '今日多轮连错';
                  break;
                case FocusWordReason.leech:
                  tagBgColor = Colors.deepPurple.withValues(alpha: 0.15);
                  tagTextColor = Colors.deepPurple;
                  tagText = 'FSRS 历史难词';
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tagText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tagTextColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 轮次测试明细视图
  Widget _buildSessionsView(
    BuildContext context,
    DailyHistorySummary summary,
    ThemeStyle themeStyle,
    Color textColor,
    Color secondaryTextColor,
    Color correctColor,
    Color wrongColor,
  ) {
    return Column(
      children: summary.sessions.asMap().entries.map((entry) {
        final index = entry.key;
        final run = entry.value;
        final runNumber = summary.sessions.length - index; // 保持序号从 1 开始
        final timeStr =
            '${run.startedAt.hour.toString().padLeft(2, '0')}:${run.startedAt.minute.toString().padLeft(2, '0')}';
        final accPercent = (run.accuracy * 100).toStringAsFixed(1);
        final durationSec = run.duration.inSeconds;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: ThemeManager.getCardDecoration(
            themeStyle,
            elevated: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeManager.getPrimaryColor(
                            themeStyle,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '第 $runNumber 轮 · $timeStr',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: ThemeManager.getPrimaryColor(themeStyle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '耗时 ${durationSec}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$accPercent%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: run.accuracy >= 0.8 ? correctColor : wrongColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSessionSubMetric(
                      '题目总数',
                      '${run.totalQuestions} 词',
                      textColor,
                      secondaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: _buildSessionSubMetric(
                      '正确',
                      '${run.correctCount} 题',
                      correctColor,
                      secondaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: _buildSessionSubMetric(
                      '错误/超时',
                      '${run.wrongCount} 题',
                      wrongColor,
                      secondaryTextColor,
                    ),
                  ),
                  Expanded(
                    child: _buildSessionSubMetric(
                      '平均反应时',
                      '${(run.avgRtMs / 1000).toStringAsFixed(1)}s',
                      textColor,
                      secondaryTextColor,
                    ),
                  ),
                ],
              ),
              if (run.levels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '参与级别: ${run.levels.join(', ')}',
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionSubMetric(
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
      ],
    );
  }

  /// 底部吸底操作栏（一键专项测试）
  Widget _buildBottomActionBar(
    BuildContext context,
    List<FocusWordItem> focusWords,
    ThemeStyle themeStyle,
    Color wrongColor,
  ) {
    final primaryColor = ThemeManager.getPrimaryColor(themeStyle);
    final surfaceColor = ThemeManager.getSurfaceColor(themeStyle);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 20),
            label: Text(
              '🎯 重点单词一键专项强化 (${focusWords.length} 词)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _startFocusWordsPractice(context, focusWords),
          ),
        ),
      ),
    );
  }

  /// 启动重点单词专项测试
  Future<void> _startFocusWordsPractice(
    BuildContext context,
    List<FocusWordItem> focusWords,
  ) async {
    final settings = ref.read(appSettingsProvider);
    final words = focusWords.map((f) => f.word).toList();
    if (words.isEmpty) return;

    final wordIds = words.map((w) => w.id).toList();
    final sessionId = await ref
        .read(appSettingsProvider.notifier)
        .stageCustomSession(wordIds);
    if (!context.mounted) return;

    if (sessionId.isNotEmpty) {
      final config = SessionConfig.fromAppSettings(
        settings,
      ).copyWith(wordsPerSession: words.length, onlyLeeches: true);

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TestScreen(config: config)));
    }
  }

  /// 空状态界面
  Widget _buildEmptyState(
    BuildContext context,
    ThemeStyle themeStyle,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: secondaryTextColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史测试记录',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '完成一次单词练习后，系统将自动按天为您生成测试战报与重点单词归因分析。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('开始今日测试'),
              onPressed: () async {
                await ref
                    .read(appSettingsProvider.notifier)
                    .clearTestProgress();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed(
                  '/test',
                  arguments: SessionConfig.defaultConfig,
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('生成演示复盘数据'),
              onPressed: () async {
                await ref
                    .read(dailyHistoryServiceProvider)
                    .seedDemoHistoryData();
                ref.invalidate(dailyHistorySummariesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已生成多日演练复盘数据！')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
