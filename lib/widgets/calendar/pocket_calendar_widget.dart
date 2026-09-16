import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_history_models.dart';
import '../../session/session_models.dart';
import '../../screens/test_screen.dart';
import '../../session/base_providers.dart';
import '../../theme/theme_manager.dart';
import '../../theme/theme_style.dart';

/// 日历分类筛选模式枚举
enum PocketCalendarFilter {
  all, // 全部打卡
  withFocus, // 包含重点复习词
  highAccuracy, // 高正确率 (>= 80%)
  needsReview, // 需重点攻克 (< 80% 或有错题)
}

/// Pocket Cal 风格月度日历学习统计组件
class PocketCalendarWidget extends ConsumerStatefulWidget {
  final List<DailyHistorySummary>? summaries;
  final ThemeStyle themeStyle;
  final DateTime? initialMonth;
  final void Function(DateTime date)? onOpenDailyHistory;
  final bool showFilterBar;

  const PocketCalendarWidget({
    super.key,
    this.summaries,
    required this.themeStyle,
    this.initialMonth,
    this.onOpenDailyHistory,
    this.showFilterBar = true,
  });

  @override
  ConsumerState<PocketCalendarWidget> createState() =>
      _PocketCalendarWidgetState();
}

class _PocketCalendarWidgetState extends ConsumerState<PocketCalendarWidget> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  PocketCalendarFilter _activeFilter = PocketCalendarFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = widget.initialMonth != null
        ? DateTime(widget.initialMonth!.year, widget.initialMonth!.month, 1)
        : DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // 若外部传入 summaries 则使用，否则从 Riverpod 订阅
    final summaries =
        widget.summaries ??
        ref.watch(dailyHistorySummariesProvider).valueOrNull ??
        [];

    final Map<String, DailyHistorySummary> summaryMap = {
      for (final s in summaries) _dateKey(s.date): s,
    };

    final textColor = ThemeManager.getTextColor(widget.themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(
      widget.themeStyle,
    );
    final primaryColor = ThemeManager.getPrimaryColor(widget.themeStyle);

    // 统计当前月各项指标
    int activeDaysCount = 0;
    int focusWordsDaysCount = 0;
    int highAccDaysCount = 0;
    int needsReviewDaysCount = 0;

    final daysInCurrentMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    for (int day = 1; day <= daysInCurrentMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final s = summaryMap[_dateKey(date)];
      if (s != null && s.sessionCount > 0) {
        activeDaysCount++;
        if (s.focusWords.isNotEmpty) focusWordsDaysCount++;
        if (s.averageAccuracy >= 0.8) highAccDaysCount++;
        if (s.averageAccuracy < 0.8 || s.focusWords.isNotEmpty) {
          needsReviewDaysCount++;
        }
      }
    }

    return Container(
      decoration: _buildContainerDecoration(widget.themeStyle),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 月份标题与控制栏 (Header)
          _buildMonthHeader(textColor, secondaryTextColor, primaryColor),

          const SizedBox(height: 18),

          // 2. 星期行表头 (SUN ~ SAT)
          _buildWeekdayHeader(secondaryTextColor),

          const SizedBox(height: 10),

          // 3. 7列卡片网格
          _buildCalendarGrid(summaryMap, textColor, secondaryTextColor),

          if (widget.showFilterBar) ...[
            const SizedBox(height: 18),
            // 4. 底部分类筛选胶囊条 (Filter Pills)
            _buildFilterPills(
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              primaryColor: primaryColor,
              allCount: activeDaysCount,
              focusCount: focusWordsDaysCount,
              highAccCount: highAccDaysCount,
              needsReviewCount: needsReviewDaysCount,
            ),
          ],
        ],
      ),
    );
  }

  /// 容器整体装饰
  BoxDecoration _buildContainerDecoration(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.digitalism:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        );
      case ThemeStyle.fono:
        return BoxDecoration(
          color: const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2C3545), width: 1.0),
        );
      case ThemeStyle.bauhaus:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        );
      case ThemeStyle.cyberpunk:
        return BoxDecoration(
          color: const Color(0xFF0F141C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00F0FF), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case ThemeStyle.minimal:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ThemeStyle.nature:
        return BoxDecoration(
          color: const Color(0xFFFAFDFA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFC8E6C9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ThemeStyle.highContrast:
        return BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2.0),
        );
      case ThemeStyle.standard:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  /// 1. 月份标题与翻页切换器
  Widget _buildMonthHeader(
    Color textColor,
    Color secondaryTextColor,
    Color primaryColor,
  ) {
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final enMonth = monthNames[_currentMonth.month - 1];
    final now = DateTime.now();
    final isCurrentMonthNow =
        now.year == _currentMonth.year && now.month == _currentMonth.month;

    Widget titleWidget;
    switch (widget.themeStyle) {
      case ThemeStyle.digitalism:
        titleWidget = Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFAB91),
                border: Border.all(color: Colors.black, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_currentMonth.year}.${_currentMonth.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.black,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              enMonth,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ],
        );
        break;
      case ThemeStyle.fono:
        titleWidget = Row(
          children: [
            Text(
              '// CAL.${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: Color(0xFF00E5FF),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              enMonth.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: Color(0xFF90A4AE),
              ),
            ),
          ],
        );
        break;
      case ThemeStyle.bauhaus:
        titleWidget = Row(
          children: [
            Container(
              width: 10,
              height: 24,
              color: const Color(0xFFD32F2F),
              margin: const EdgeInsets.only(right: 8),
            ),
            Text(
              enMonth,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_currentMonth.year}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          ],
        );
        break;
      case ThemeStyle.cyberpunk:
        titleWidget = Row(
          children: [
            Text(
              enMonth,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00F0FF),
                shadows: [Shadow(color: Color(0xFF00F0FF), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '// ${_currentMonth.year}',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Color(0xFFFFE600),
              ),
            ),
          ],
        );
        break;
      case ThemeStyle.minimal:
      case ThemeStyle.nature:
      case ThemeStyle.highContrast:
      case ThemeStyle.standard:
        titleWidget = Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              enMonth,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_currentMonth.year}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        );
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        titleWidget,

        // 控制按钮 (翻页与今天)
        Row(
          children: [
            if (!isCurrentMonthNow)
              GestureDetector(
                onTap: _jumpToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    '今',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            _buildNavButton(
              icon: Icons.chevron_left_rounded,
              onTap: _previousMonth,
              textColor: textColor,
            ),
            const SizedBox(width: 4),
            _buildNavButton(
              icon: Icons.chevron_right_rounded,
              onTap: _nextMonth,
              textColor: textColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: textColor),
      ),
    );
  }

  /// 2. 星期表头 (SUN, MON, TUE, WED, THU, FRI, SAT)
  Widget _buildWeekdayHeader(Color secondaryTextColor) {
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final isFono = widget.themeStyle == ThemeStyle.fono;

    return Row(
      children: [
        for (final w in weekdays)
          Expanded(
            child: Center(
              child: Text(
                w,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontFamily: isFono ? 'monospace' : null,
                  color: (w == 'SUN' || w == 'SAT')
                      ? secondaryTextColor.withValues(alpha: 0.7)
                      : secondaryTextColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 3. 7 列日历卡片网格
  Widget _buildCalendarGrid(
    Map<String, DailyHistorySummary> summaryMap,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final prevMonthDays = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      0,
    ).day;

    // 周日开始 (Sunday = 0, Monday = 1, ... Saturday = 6)
    final leadingDays = firstDayOfMonth.weekday % 7;
    final totalDays = leadingDays + daysInMonth;
    final trailingDays = (7 - (totalDays % 7)) % 7;
    final totalCells = totalDays + trailingDays;

    final now = DateTime.now();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 5,
        mainAxisSpacing: 6,
        childAspectRatio: 0.65, // 卡片更修长，对齐 pocket cal 布局，杜绝粗边框主题下微溢出
      ),
      itemBuilder: (context, index) {
        DateTime date;
        bool isCurrentMonth = true;

        if (index < leadingDays) {
          final day = prevMonthDays - leadingDays + index + 1;
          date = DateTime(_currentMonth.year, _currentMonth.month - 1, day);
          isCurrentMonth = false;
        } else if (index < leadingDays + daysInMonth) {
          final day = index - leadingDays + 1;
          date = DateTime(_currentMonth.year, _currentMonth.month, day);
          isCurrentMonth = true;
        } else {
          final day = index - leadingDays - daysInMonth + 1;
          date = DateTime(_currentMonth.year, _currentMonth.month + 1, day);
          isCurrentMonth = false;
        }

        final summary = summaryMap[_dateKey(date)];
        final hasStudy = summary != null && summary.sessionCount > 0;
        final isToday = _isSameDay(date, now);
        final isSelected =
            _selectedDate != null && _isSameDay(date, _selectedDate!);

        // 判断当前过滤模式是否满足
        bool isDimmedByFilter = false;
        if (isCurrentMonth && hasStudy) {
          switch (_activeFilter) {
            case PocketCalendarFilter.all:
              isDimmedByFilter = false;
              break;
            case PocketCalendarFilter.withFocus:
              isDimmedByFilter = summary.focusWords.isEmpty;
              break;
            case PocketCalendarFilter.highAccuracy:
              isDimmedByFilter = summary.averageAccuracy < 0.8;
              break;
            case PocketCalendarFilter.needsReview:
              isDimmedByFilter =
                  summary.averageAccuracy >= 0.8 && summary.focusWords.isEmpty;
              break;
          }
        }

        return _buildDayCard(
          context: context,
          date: date,
          isCurrentMonth: isCurrentMonth,
          hasStudy: hasStudy,
          summary: summary,
          isToday: isToday,
          isSelected: isSelected,
          isDimmedByFilter: isDimmedByFilter,
          textColor: textColor,
          secondaryTextColor: secondaryTextColor,
        );
      },
    );
  }

  /// 单个日期卡片 (对齐 Pocket Cal 风格)
  Widget _buildDayCard({
    required BuildContext context,
    required DateTime date,
    required bool isCurrentMonth,
    required bool hasStudy,
    required DailyHistorySummary? summary,
    required bool isToday,
    required bool isSelected,
    required bool isDimmedByFilter,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final style = widget.themeStyle;
    final cardDecoration = _getDayCardDecoration(
      style: style,
      isCurrentMonth: isCurrentMonth,
      hasStudy: hasStudy,
      isSelected: isSelected,
      isDimmed: isDimmedByFilter,
    );

    // 提取当日前 1~3 个重点词
    final focusWords = summary?.focusWords ?? [];

    Color dayNumColor;
    if (!isCurrentMonth) {
      dayNumColor = secondaryTextColor.withValues(alpha: 0.3);
    } else if (hasStudy) {
      dayNumColor = _getActiveDayNumberColor(style, textColor);
    } else {
      dayNumColor = secondaryTextColor;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        if (hasStudy && summary != null) {
          _showDayDetailModal(context, date, summary);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: cardDecoration,
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
        child: Opacity(
          opacity: isDimmedByFilter ? 0.35 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 顶部行：日序号 + 今天点 / 正确率小点
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          (hasStudy || isToday)
                              ? FontWeight.w900
                              : FontWeight.w600,
                      color: dayNumColor,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: ThemeManager.getPrimaryColor(style),
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (hasStudy && summary != null)
                    _buildMiniAccuracyDot(style, summary.averageAccuracy),
                ],
              ),

              const SizedBox(height: 2),

              // 2. 重点复习词列表 (对齐 pocket cal 任务项列表)
              if (isCurrentMonth && hasStudy && focusWords.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (int i = 0; i < focusWords.length && i < 2; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: Row(
                            children: [
                              _buildBulletPoint(style),
                              const SizedBox(width: 2.0),
                              Expanded(
                                child: Text(
                                  focusWords[i].word.headword,
                                  style: _getFocusWordTextStyle(style),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (focusWords.length > 2)
                        Text(
                          '+${focusWords.length - 2}',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: _getBulletColor(
                              style,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                )
              else if (isCurrentMonth && hasStudy && summary != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      '✓ ${summary.totalWordsTested}词',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: ThemeManager.getCorrectColor(style),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// 微型正确率指示圆点
  Widget _buildMiniAccuracyDot(ThemeStyle style, double accuracy) {
    final color =
        accuracy >= 0.8
            ? ThemeManager.getCorrectColor(style)
            : (accuracy >= 0.6 ? Colors.orange : Colors.redAccent);
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  /// 重点词列表项目符号 (■ / •)
  Widget _buildBulletPoint(ThemeStyle style) {
    final color = _getBulletColor(style);
    switch (style) {
      case ThemeStyle.digitalism:
      case ThemeStyle.minimal:
      case ThemeStyle.bauhaus:
        return Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              style == ThemeStyle.bauhaus ? 0 : 0.5,
            ),
          ),
        );
      case ThemeStyle.fono:
        return Container(
          width: 2.5,
          height: 5,
          color: color,
        );
      case ThemeStyle.cyberpunk:
        return Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.8),
                blurRadius: 2,
              ),
            ],
          ),
        );
      case ThemeStyle.nature:
      case ThemeStyle.highContrast:
      case ThemeStyle.standard:
        return Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
    }
  }

  Color _getBulletColor(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.digitalism:
        return Colors.black87;
      case ThemeStyle.fono:
        return const Color(0xFFE53935);
      case ThemeStyle.bauhaus:
        return const Color(0xFFD32F2F);
      case ThemeStyle.cyberpunk:
        return const Color(0xFF00F0FF);
      case ThemeStyle.minimal:
        return const Color(0xFF111827);
      case ThemeStyle.nature:
        return const Color(0xFF2E7D32);
      case ThemeStyle.highContrast:
        return Colors.white;
      case ThemeStyle.standard:
        return Colors.blue.shade800;
    }
  }

  TextStyle _getFocusWordTextStyle(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.digitalism:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontFamily: 'monospace',
          height: 1.1,
        );
      case ThemeStyle.fono:
        return const TextStyle(
          fontSize: 8.0,
          fontWeight: FontWeight.w600,
          color: Color(0xFFCFD8DC),
          fontFamily: 'monospace',
          height: 1.1,
        );
      case ThemeStyle.bauhaus:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: Colors.black,
          height: 1.1,
        );
      case ThemeStyle.cyberpunk:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E6ED),
          height: 1.1,
        );
      case ThemeStyle.minimal:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
          height: 1.1,
        );
      case ThemeStyle.highContrast:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.1,
        );
      case ThemeStyle.nature:
      case ThemeStyle.standard:
        return const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
          height: 1.1,
        );
    }
  }

  Color _getActiveDayNumberColor(ThemeStyle style, Color defaultTextColor) {
    switch (style) {
      case ThemeStyle.digitalism:
      case ThemeStyle.bauhaus:
        return Colors.black;
      case ThemeStyle.fono:
        return const Color(0xFF00E5FF);
      case ThemeStyle.cyberpunk:
        return const Color(0xFFFFE600);
      case ThemeStyle.nature:
        return const Color(0xFF1B5E20);
      case ThemeStyle.highContrast:
        return Colors.white;
      case ThemeStyle.minimal:
        return const Color(0xFF111827);
      case ThemeStyle.standard:
        return defaultTextColor;
    }
  }

  /// 针对 8 种主题量身打造的卡片边框与质感
  BoxDecoration _getDayCardDecoration({
    required ThemeStyle style,
    required bool isCurrentMonth,
    required bool hasStudy,
    required bool isSelected,
    required bool isDimmed,
  }) {
    if (!isCurrentMonth) {
      return BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_getCardCornerRadius(style)),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.08),
          width: 0.8,
        ),
      );
    }

    if (!hasStudy) {
      switch (style) {
        case ThemeStyle.digitalism:
          return BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.2),
              width: 1.2,
            ),
          );
        case ThemeStyle.fono:
          return BoxDecoration(
            color: const Color(0xFF10141A),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: const Color(0xFF222933),
              width: 1.0,
            ),
          );
        case ThemeStyle.bauhaus:
          return BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.2),
              width: 1.5,
            ),
          );
        case ThemeStyle.cyberpunk:
          return BoxDecoration(
            color: const Color(0xFF0B0F14),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          );
        case ThemeStyle.nature:
          return BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1.0,
            ),
          );
        case ThemeStyle.highContrast:
          return BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.grey.shade600,
              width: 1.0,
            ),
          );
        case ThemeStyle.minimal:
        case ThemeStyle.standard:
          return BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1.0,
            ),
          );
      }
    }

    // 当月且有学习记录（高亮活跃打卡卡片，对标 pocket cal 强化外边框）
    switch (style) {
      case ThemeStyle.minimal:
        return BoxDecoration(
          color: isSelected ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF111827),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );

      case ThemeStyle.digitalism:
        return BoxDecoration(
          color: const Color(0xFFFFCC80),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.black,
            width: isSelected ? 2.5 : 2.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(1.8, 1.8),
              blurRadius: 0,
            ),
          ],
        );

      case ThemeStyle.fono:
        return BoxDecoration(
          color: const Color(0xFF1A212B),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFFE53935),
            width: 1.4,
          ),
        );

      case ThemeStyle.bauhaus:
        return BoxDecoration(
          color: const Color(0xFFFFF59D),
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: Colors.black,
            width: isSelected ? 3.0 : 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        );

      case ThemeStyle.cyberpunk:
        return BoxDecoration(
          color: const Color(0xFF141C26),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFE600) : const Color(0xFF00F0FF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        );

      case ThemeStyle.nature:
        return BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E7D32),
            width: isSelected ? 2.0 : 1.5,
          ),
        );

      case ThemeStyle.highContrast:
        return BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.yellowAccent : Colors.white,
            width: 2.0,
          ),
        );

      case ThemeStyle.standard:
        return BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.blue.shade700,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        );
    }
  }

  double _getCardCornerRadius(ThemeStyle style) {
    switch (style) {
      case ThemeStyle.bauhaus:
        return 0;
      case ThemeStyle.fono:
        return 3;
      case ThemeStyle.cyberpunk:
        return 4;
      case ThemeStyle.highContrast:
        return 6;
      case ThemeStyle.nature:
        return 12;
      case ThemeStyle.digitalism:
      case ThemeStyle.minimal:
      case ThemeStyle.standard:
        return 10;
    }
  }

  /// 4. 底部筛选胶囊条 (对齐 pocket cal 底部 All 80, Daily Life 28 形式)
  Widget _buildFilterPills({
    required Color textColor,
    required Color secondaryTextColor,
    required Color primaryColor,
    required int allCount,
    required int focusCount,
    required int highAccCount,
    required int needsReviewCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterPillItem(
            filter: PocketCalendarFilter.all,
            label: '全部打卡',
            count: allCount,
            isSelected: _activeFilter == PocketCalendarFilter.all,
            activeColor: primaryColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(width: 8),
          _buildFilterPillItem(
            filter: PocketCalendarFilter.withFocus,
            label: '重点复习',
            count: focusCount,
            isSelected: _activeFilter == PocketCalendarFilter.withFocus,
            activeColor: Colors.orange.shade800,
            dotColor: Colors.orange,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(width: 8),
          _buildFilterPillItem(
            filter: PocketCalendarFilter.highAccuracy,
            label: '高正确率 (≥80%)',
            count: highAccCount,
            isSelected: _activeFilter == PocketCalendarFilter.highAccuracy,
            activeColor: Colors.green.shade700,
            dotColor: Colors.green,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(width: 8),
          _buildFilterPillItem(
            filter: PocketCalendarFilter.needsReview,
            label: '需攻克 (<80%)',
            count: needsReviewCount,
            isSelected: _activeFilter == PocketCalendarFilter.needsReview,
            activeColor: Colors.red.shade700,
            dotColor: Colors.redAccent,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPillItem({
    required PocketCalendarFilter filter,
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    Color? dotColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = filter;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : secondaryTextColor,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : secondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 5. 点击日期卡片下钻展示当日重点复盘明细弹层
  void _showDayDetailModal(
    BuildContext context,
    DateTime date,
    DailyHistorySummary summary,
  ) {
    final style = widget.themeStyle;
    final textColor = ThemeManager.getTextColor(style);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(style);
    final primaryColor = ThemeManager.getPrimaryColor(style);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: ThemeManager.getSurfaceColor(style),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: ThemeManager.getBorderColor(style),
              width: ThemeManager.getBorderWidth(style),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖动把手
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 标题与日期
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.year}年${date.month}月${date.day}日',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '当日学习复盘与重点攻克词',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 四项核心指标卡片
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildModalStatBadge(
                      '测试轮数',
                      '${summary.sessionCount} 轮',
                      primaryColor,
                    ),
                    _buildModalStatBadge(
                      '复习单词',
                      '${summary.totalWordsTested} 词',
                      primaryColor,
                    ),
                    _buildModalStatBadge(
                      '平均正确率',
                      '${(summary.averageAccuracy * 100).toInt()}%',
                      summary.averageAccuracy >= 0.8
                          ? Colors.green
                          : Colors.orange,
                    ),
                    _buildModalStatBadge(
                      '累计耗时',
                      '${(summary.totalDurationMs / 1000 / 60).toStringAsFixed(1)}m',
                      primaryColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 重点词列表标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '重点突破词汇 (${summary.focusWords.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (widget.onOpenDailyHistory != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        widget.onOpenDailyHistory!(date);
                      },
                      child: Text(
                        '完整档案 >',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // 单词明细列表
              Flexible(
                child: summary.focusWords.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            '🎉 当日全部答对，无须重点复习的生词！',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: summary.focusWords.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final item = summary.focusWords[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeManager.getSurfaceColor(style),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ThemeManager.getBorderColor(style),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.word.headword,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.word.pos,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: secondaryTextColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.word.primaryDefinition,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: secondaryTextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getReasonTagColor(
                                      item.primaryReasonText,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.primaryReasonText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getReasonTagColor(
                                        item.primaryReasonText,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // 底部行动按钮
              if (summary.focusWords.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startTargetedSession(context, summary.focusWords);
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text('针对练习当日重点词 (${summary.focusWords.length}个)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalStatBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getReasonTagColor(String reason) {
    if (reason.contains('高频') || reason.contains('顽固')) {
      return Colors.deepOrange;
    }
    if (reason.contains('答错')) return Colors.red;
    if (reason.contains('超时')) return Colors.purple;
    if (reason.contains('迟疑')) return Colors.orange;
    return Colors.amber.shade800;
  }

  /// 启动针对重点单词的闪测练习
  Future<void> _startTargetedSession(
    BuildContext context,
    List<FocusWordItem> focusWords,
  ) async {
    final settings = ref.read(appSettingsProvider);
    final wordIds = focusWords.map((fw) => fw.word.id).toList();

    final sessionId = await ref
        .read(appSettingsProvider.notifier)
        .stageCustomSession(wordIds);
    if (!context.mounted) return;

    if (sessionId.isNotEmpty) {
      final config = SessionConfig.fromAppSettings(
        settings,
      ).copyWith(wordsPerSession: wordIds.length, onlyLeeches: true);

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TestScreen(config: config)));
    }
  }
}
