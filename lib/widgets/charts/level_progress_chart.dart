import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/theme_manager.dart';
import '../../theme/theme_style.dart';

class LevelProgressChart extends StatelessWidget {
  final int total;
  final int learned;
  final int mastered;
  final ThemeStyle themeStyle;

  const LevelProgressChart({
    super.key,
    required this.total,
    required this.learned,
    required this.mastered,
    required this.themeStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate segments
    // Logic:
    // Total = Mastered + Learning + NotStarted
    // But input is:
    // - Total (all words)
    // - Learned (encountered) -> Includes Mastered? Usually yes.
    // - Mastered (high accuracy)

    // So:
    // Mastered Segment = mastered
    // Learning Segment = learned - mastered
    // Not Started Segment = total - learned

    final learningCount = max(0, learned - mastered);
    final notStartedCount = max(0, total - learned);
    final safeTotal = total > 0 ? total : 1;

    // Percentages
    final masteredPercent = (mastered / safeTotal * 100).toInt();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Chart Section
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The Chart
              CustomPaint(
                size: const Size(140, 140),
                painter: _DonutChartPainter(
                  mastered: mastered.toDouble(),
                  learning: learningCount.toDouble(),
                  notStarted: notStartedCount.toDouble(),
                  total: safeTotal.toDouble(),
                  themeStyle: themeStyle,
                ),
              ),
              // Center Text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$masteredPercent%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: ThemeManager.getTextColor(themeStyle),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '已掌握',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ThemeManager.getSecondaryTextColor(themeStyle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 32),

        // Legend Section
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem(
                label: '熟练掌握',
                value: '$mastered',
                color: ThemeManager.getCorrectColor(themeStyle),
                percentage: (mastered / safeTotal),
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                label: '正在学习',
                value: '$learningCount',
                color: ThemeManager.getPrimaryColor(themeStyle),
                percentage: (learningCount / safeTotal),
              ),
              const SizedBox(height: 12),
              _buildLegendItem(
                label: '尚未开始',
                value: '$notStartedCount',
                color: ThemeManager.isDarkTheme(themeStyle)
                    ? Colors.white24
                    : Colors.grey.shade300,
                percentage: (notStartedCount / safeTotal),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required String label,
    required String value,
    required Color color,
    required double percentage,
  }) {
    final textColor = ThemeManager.getTextColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);

    return Row(
      children: [
        // Color Indicator
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),

        // Label
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Value
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace', // Monospace for alignment
              ),
            ),
            // Optional: Show tiny percentage? Maybe too cluttered.
          ],
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double mastered;
  final double learning;
  final double notStarted;
  final double total;
  final ThemeStyle themeStyle;

  _DonutChartPainter({
    required this.mastered,
    required this.learning,
    required this.notStarted,
    required this.total,
    required this.themeStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Butt caps for seamless segments

    // 1. Draw Background Track (Not Started)
    // We draw the full circle as "track" first
    final trackColor = ThemeManager.isDarkTheme(themeStyle)
        ? Colors.white10
        : Colors.grey.shade100;

    paint.color = trackColor;
    canvas.drawCircle(center, radius - strokeWidth / 2, paint);

    // 2. Draw Segments
    // Order: Mastered, then Learning
    // We start from top (-pi/2)

    double startAngle = -pi / 2;
    final totalSweep = 2 * pi;

    final masteredSweep = (mastered / total) * totalSweep;
    final learningSweep = (learning / total) * totalSweep;
    // notStartedSweep is the rest

    // Optimization: If total is 0, don't draw
    if (total <= 0) return;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Draw Learning first (as base for mastered if we want stacking? No, side-by-side)
    // Actually, usually "Mastered" is the most prominent.
    // Let's draw Learning, then Mastered?
    // Let's draw them in order: Mastered -> Learning -> Not Started (which is background)

    // Mastered Segment
    if (mastered > 0) {
      paint.color = ThemeManager.getCorrectColor(themeStyle);
      paint.strokeCap =
          StrokeCap.round; // Rounded start/end if it's the only one

      // If we have other segments, we need to be careful with caps.
      // If full circle, no caps needed (but arc won't close perfectly with drawArc).

      // Visual trick: Draw with round caps.
      // If we have adjacent segments, round caps overlap.
      // Let's use butt caps for middle joins?
      // Too complex for simple canvas.
      // Solution: Use Round caps, but draw them carefully.

      canvas.drawArc(rect, startAngle, masteredSweep, false, paint);
    }

    // Learning Segment
    if (learning > 0) {
      paint.color = ThemeManager.getPrimaryColor(themeStyle);
      paint.strokeCap = StrokeCap.round;

      // Start where mastered ended
      // Note: If we use round caps, the start of this arc will rounded-overlap the end of previous.
      // This actually looks nice (organic).

      canvas.drawArc(
        rect,
        startAngle + masteredSweep,
        learningSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
