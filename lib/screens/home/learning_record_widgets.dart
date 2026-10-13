import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/progress/domain/daily_records.dart';
import '../../theme/theme_manager.dart';
import '../../theme/theme_style.dart';

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 带标题的记录面板。
class RecordSection extends StatelessWidget {
  final ThemeStyle themeStyle;
  final String title;
  final Widget? trailing;
  final Widget child;

  const RecordSection({
    super.key,
    required this.themeStyle,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeManager.getCardDecoration(themeStyle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ThemeManager.getTextColor(themeStyle),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 打卡日历：按周排列的热力格，颜色深浅表示当天题量。
///
/// 显示的周数随宽度自动铺满（[minWeeks]~53 周），最后一列是本周。
class StudyHeatmap extends StatelessWidget {
  final ThemeStyle themeStyle;
  final List<DailyRecord> records;
  final int minWeeks;
  final DateTime? today;

  const StudyHeatmap({
    super.key,
    required this.themeStyle,
    required this.records,
    this.minWeeks = 8,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final base = ThemeManager.getCorrectColor(themeStyle);
    final empty = ThemeManager.getProgressBackgroundColor(themeStyle);
    final byDay = {for (final r in records) r.day: r};
    final maxAttempts = records.fold<int>(1, (m, r) => math.max(m, r.attempts));
    final now = _dayOf(today ?? DateTime.now());
    const labels = ['一', '', '三', '', '五', '', '日'];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        const labelWidth = 18.0;
        const maxCell = 22.0;
        final weeks = ((constraints.maxWidth - labelWidth) / (maxCell + gap))
            .floor()
            .clamp(minWeeks, 53);
        final cell = math.min(
          maxCell,
          (constraints.maxWidth - labelWidth - gap * weeks) / weeks,
        );
        // 用日历构造器回推周一，避免跨夏令时按 24 小时相减错位。
        final firstMonday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1) - 7 * (weeks - 1),
        );
        Widget square(DateTime day) {
          final record = byDay[day];
          final future = day.isAfter(now);
          final level = record == null || !record.checkedIn
              ? 0.0
              : 0.35 + 0.65 * (record.attempts / maxAttempts);
          return Tooltip(
            message: record == null
                ? '${day.month}/${day.day} 未打卡'
                : '${day.month}/${day.day} · ${record.attempts} 题 · '
                      '准确率 ${(record.accuracy * 100).round()}%',
            child: Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: future
                    ? Colors.transparent
                    : level == 0
                    ? empty
                    : base.withValues(alpha: level),
                borderRadius: BorderRadius.circular(3),
                border: day == now
                    ? Border.all(
                        color: ThemeManager.getTextColor(themeStyle),
                        width: 1.5,
                      )
                    : null,
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Column(
                children: [
                  for (final l in labels)
                    SizedBox(
                      height: cell + gap,
                      child: Text(
                        l,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var w = 0; w < weeks; w++)
              Padding(
                padding: const EdgeInsets.only(right: gap),
                child: Column(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: gap),
                        child: square(
                          DateTime(
                            firstMonday.year,
                            firstMonday.month,
                            firstMonday.day + w * 7 + d,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 每日准确率（折线）与题量（柱）趋势，可切换 7/30/90 天。
class DailyTrendChart extends StatefulWidget {
  final ThemeStyle themeStyle;
  final List<DailyRecord> records;
  final DateTime? today;

  const DailyTrendChart({
    super.key,
    required this.themeStyle,
    required this.records,
    this.today,
  });

  @override
  State<DailyTrendChart> createState() => _DailyTrendChartState();
}

class _DailyTrendChartState extends State<DailyTrendChart> {
  int _range = 30;

  @override
  Widget build(BuildContext context) {
    final style = widget.themeStyle;
    final theme = Theme.of(context);
    final secondary = ThemeManager.getSecondaryTextColor(style);
    final now = _dayOf(widget.today ?? DateTime.now());
    final byDay = {for (final r in widget.records) r.day: r};
    final days = [
      for (var i = _range - 1; i >= 0; i--)
        DateTime(now.year, now.month, now.day - i),
    ];
    final points = [for (final d in days) byDay[d]];
    final active = points.whereType<DailyRecord>().toList();
    final avgAccuracy = active.isEmpty
        ? null
        : active.fold<int>(0, (s, r) => s + r.correct) /
              math.max(1, active.fold<int>(0, (s, r) => s + r.attempts));

    return RecordSection(
      themeStyle: style,
      title: '每日准确率与题量',
      trailing: SegmentedButton<int>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 7, label: Text('7天')),
          ButtonSegment(value: 30, label: Text('30天')),
          ButtonSegment(value: 90, label: Text('90天')),
        ],
        selected: {_range},
        onSelectionChanged: (s) => setState(() => _range = s.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            avgAccuracy == null
                ? '这段时间还没有完成的轮次'
                : '学习 ${active.length} 天 · 平均准确率 '
                      '${(avgAccuracy * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: Size.infinite,
              painter: _TrendPainter(
                points: points,
                barColor: ThemeManager.getPrimaryColor(
                  style,
                ).withValues(alpha: 0.25),
                lineColor: ThemeManager.getCorrectColor(style),
                gridColor: ThemeManager.getBorderColor(
                  style,
                ).withValues(alpha: 0.12),
                labelStyle:
                    theme.textTheme.labelSmall?.copyWith(color: secondary) ??
                    TextStyle(color: secondary, fontSize: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${days.first.month}/${days.first.day}',
                style: theme.textTheme.labelSmall?.copyWith(color: secondary),
              ),
              Row(
                children: [
                  _legend(
                    ThemeManager.getCorrectColor(style),
                    '准确率',
                    secondary,
                  ),
                  const SizedBox(width: 12),
                  _legend(
                    ThemeManager.getPrimaryColor(style).withValues(alpha: 0.35),
                    '题数',
                    secondary,
                  ),
                ],
              ),
              Text(
                '今天',
                style: theme.textTheme.labelSmall?.copyWith(color: secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text, Color textColor) => Row(
    children: [
      Container(width: 10, height: 10, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: textColor)),
    ],
  );
}

class _TrendPainter extends CustomPainter {
  final List<DailyRecord?> points;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  _TrendPainter({
    required this.points,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 32.0;
    final chart = Rect.fromLTWH(
      leftPad,
      6,
      size.width - leftPad,
      size.height - 12,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final pct in [0, 50, 100]) {
      final y = chart.bottom - chart.height * pct / 100;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final tp = TextPainter(
        text: TextSpan(text: '$pct%', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final n = points.length;
    final slot = chart.width / n;
    final maxAttempts = points.fold<int>(
      1,
      (m, r) => math.max(m, r?.attempts ?? 0),
    );
    final bar = Paint()..color = barColor;
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = lineColor;
    final path = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final r = points[i];
      if (r == null || r.attempts == 0) {
        started = false; // 断签日让折线断开，避免把没学的日子连成一条线
        continue;
      }
      final x = chart.left + slot * (i + 0.5);
      final h = chart.height * r.attempts / maxAttempts;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - slot * 0.35, chart.bottom - h, slot * 0.7, h),
          const Radius.circular(2),
        ),
        bar,
      );
      final y = chart.bottom - chart.height * r.accuracy;
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
      if (n <= 31) canvas.drawCircle(Offset(x, y), 3, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.lineColor != lineColor;
}

/// 作答构成：正确 / 答错 / 超时，用来区分"不会"和"来不及"。
class AnswerCompositionCard extends StatelessWidget {
  final ThemeStyle themeStyle;
  final List<DailyRecord> records;
  final int days;
  final DateTime? today;

  const AnswerCompositionCard({
    super.key,
    required this.themeStyle,
    required this.records,
    this.days = 30,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final now = _dayOf(today ?? DateTime.now());
    final from = DateTime(now.year, now.month, now.day - days + 1);
    final mix = AnswerComposition.of(
      records.where((r) => !r.day.isBefore(from)),
    );
    final parts = [
      ('正确', mix.correct, ThemeManager.getCorrectColor(themeStyle)),
      ('答错', mix.wrong, ThemeManager.getWrongColor(themeStyle)),
      ('超时', mix.timeout, ThemeManager.getWarningColor(themeStyle)),
    ];
    String pct(int v) =>
        mix.total == 0 ? '—' : '${(v * 100 / mix.total).round()}%';

    return RecordSection(
      themeStyle: themeStyle,
      title: '作答构成 · 近 $days 天',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: mix.total == 0
                  ? ColoredBox(
                      color: ThemeManager.getProgressBackgroundColor(
                        themeStyle,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final p in parts)
                          if (p.$2 > 0)
                            Expanded(
                              flex: p.$2,
                              child: ColoredBox(color: p.$3),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: p.$3,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.$1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${pct(p.$2)}  ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${p.$2}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          if (mix.total > 0 && mix.timeout * 100 / mix.total >= 15)
            Text(
              '超时较多：不少题可能是来不及答，可以在设置里放宽答题时限。',
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
        ],
      ),
    );
  }
}

/// 每日明细表（最近的在上）。
class DailyRecordTable extends StatelessWidget {
  final ThemeStyle themeStyle;
  final List<DailyRecord> records;
  final int maxRows;
  final VoidCallback? onOpenDetail;

  const DailyRecordTable({
    super.key,
    required this.themeStyle,
    required this.records,
    this.maxRows = 14,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondary = ThemeManager.getSecondaryTextColor(themeStyle);
    final rows = records.reversed.take(maxRows).toList();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final header = theme.textTheme.labelMedium?.copyWith(color: secondary);
    final cell = theme.textTheme.bodyMedium?.copyWith(color: textColor);

    Widget row(List<String> values, TextStyle? style, {Color? accuracyColor}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(values[0], style: style)),
              for (var i = 1; i < values.length; i++)
                Expanded(
                  flex: 2,
                  child: Text(
                    values[i],
                    textAlign: TextAlign.right,
                    style: i == 4 && accuracyColor != null
                        ? style?.copyWith(
                            color: accuracyColor,
                            fontWeight: FontWeight.w700,
                          )
                        : style,
                  ),
                ),
            ],
          ),
        );

    return RecordSection(
      themeStyle: themeStyle,
      title: '每日明细',
      trailing: onOpenDetail == null
          ? null
          : TextButton(onPressed: onOpenDetail, child: const Text('错题详情')),
      child: rows.isEmpty
          ? Text('还没有完成的轮次', style: header)
          : Column(
              children: [
                row(['日期', '轮次', '题数', '单词', '准确率', '超时', '用时'], header),
                Divider(
                  height: 1,
                  color: ThemeManager.getBorderColor(
                    themeStyle,
                  ).withValues(alpha: 0.15),
                ),
                for (final r in rows)
                  row(
                    [
                      '${r.day.month}/${r.day.day} 周${weekdays[r.day.weekday - 1]}',
                      '${r.rounds}',
                      '${r.attempts}',
                      '${r.distinctWords}',
                      '${(r.accuracy * 100).round()}%',
                      '${r.timeout}',
                      '${(r.studyMs / 60000).round()} 分',
                    ],
                    cell,
                    accuracyColor: r.accuracy >= 0.6
                        ? ThemeManager.getCorrectColor(themeStyle)
                        : r.accuracy < 0.45
                        ? ThemeManager.getWrongColor(themeStyle)
                        : null,
                  ),
              ],
            ),
    );
  }
}
