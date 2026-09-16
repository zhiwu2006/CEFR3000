import 'dart:math';

import 'package:flutter/material.dart';
import '../../theme/theme_manager.dart';
import '../../theme/theme_style.dart';

class ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;
  final ThemeStyle themeStyle;

  const ActivityChart({
    super.key,
    required this.dailyStats,
    required this.themeStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: ThemeManager.getSecondaryTextColor(
                themeStyle,
              ).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '暂无学习数据',
              style: TextStyle(
                color: ThemeManager.getSecondaryTextColor(themeStyle),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ActivityChartPainter(
            dailyStats: dailyStats,
            themeStyle: themeStyle,
          ),
        );
      },
    );
  }
}

class _ActivityChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> dailyStats;
  final ThemeStyle themeStyle;

  _ActivityChartPainter({required this.dailyStats, required this.themeStyle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Setup layout constants
    final double bottomLabelHeight = 24.0;
    final double topPadding = 16.0;
    final double chartHeight = size.height - bottomLabelHeight - topPadding;

    // Determine bar width and spacing
    // We want bars to be dynamic but max out at a certain width
    final int count = dailyStats.length;
    final double totalAvailableWidth = size.width;
    // Minimum padding between bars
    final double minSpacing = 4.0;
    // Desired max bar width
    final double maxBarWidth = 16.0;

    // Calculate optimal bar width
    // totalWidth = count * barWidth + (count - 1) * spacing
    // If we assume spacing = barWidth * 0.5 (for example)

    double barWidth = (totalAvailableWidth - (count + 1) * minSpacing) / count;
    barWidth = min(barWidth, maxBarWidth);

    // Recalculate spacing based on fixed bar width to center everything
    final double totalBarContentWidth =
        count * barWidth + (count - 1) * minSpacing;
    final double startX = (totalAvailableWidth - totalBarContentWidth) / 2;
    final double spacing = minSpacing;

    // 2. Determine Scale (Max attempts)
    int maxAttempts = 0;
    for (var stat in dailyStats) {
      final attempts = stat['totalAttempts'] as int? ?? 0;
      if (attempts > maxAttempts) maxAttempts = attempts;
    }
    // Add some headroom, min 10
    final int roundedMax = _ceilToNiceNumber(max(maxAttempts, 10));

    // 3. Colors
    final primaryColor = ThemeManager.getPrimaryColor(themeStyle);
    final secondaryTextColor = ThemeManager.getSecondaryTextColor(themeStyle);
    final correctColor = ThemeManager.getCorrectColor(themeStyle);
    final gridColor = ThemeManager.isDarkTheme(themeStyle)
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    // 4. Draw Grid Lines (0%, 50%, 100%)
    paint.strokeWidth = 1;
    paint.style = PaintingStyle.stroke;
    paint.color = gridColor;

    // Bottom line
    canvas.drawLine(
      Offset(0, size.height - bottomLabelHeight),
      Offset(size.width, size.height - bottomLabelHeight),
      paint,
    );

    // Middle line
    final double midY = topPadding + chartHeight / 2;
    // Dashed line for middle
    _drawDashedLine(canvas, Offset(0, midY), Offset(size.width, midY), paint);

    // Top line (dashed)
    // _drawDashedLine(canvas, Offset(0, topPadding), Offset(size.width, topPadding), paint);

    // 5. Draw Bars and Collect Points for Line Chart
    List<Offset> accuracyPoints = [];

    double currentX = startX;

    for (var i = 0; i < count; i++) {
      final stat = dailyStats[i];
      final attempts = stat['totalAttempts'] as int? ?? 0;
      final accuracy = stat['accuracy'] as double? ?? 0.0;
      final date = stat['date'] is DateTime
          ? stat['date'] as DateTime
          : DateTime.tryParse(stat['date'].toString()) ?? DateTime.now();

      final isToday = i == count - 1;

      // --- Bar Drawing ---
      final double barHeightRatio = attempts / roundedMax;
      final double barHeight = barHeightRatio * chartHeight;
      final double barTop = size.height - bottomLabelHeight - barHeight;

      // Bar Rect
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(currentX, barTop, barWidth, barHeight),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );

      // Gradient fill
      final barGradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withValues(alpha: 0.3),
          primaryColor.withValues(alpha: 0.8),
        ],
      );

      paint.shader = barGradient.createShader(rect.outerRect);
      paint.style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
      paint.shader = null;

      // --- Accuracy Point Calculation ---
      // Only plot point if there was activity
      if (attempts > 0) {
        final pointY = topPadding + chartHeight * (1 - accuracy);
        final pointX = currentX + barWidth / 2;
        accuracyPoints.add(Offset(pointX, pointY));
      } else {
        // If no attempts, break the line? Or treat as 0?
        // Better to break the line to indicate no data for accuracy
        accuracyPoints.add(Offset.infinite); // Marker for break
      }

      // --- Date Label ---
      // Show label if:
      // 1. It's the first or last
      // 2. It's a Monday (start of week)
      // 3. Or if we have few items
      bool showLabel = false;
      if (count <= 7) {
        showLabel = true;
      } else if (i == 0 || i == count - 1) {
        showLabel = true;
      } else if (i % 5 == 0) {
        // Every 5 days roughly
        showLabel = true;
      }

      if (showLabel) {
        final textSpan = TextSpan(
          text: isToday ? '今' : '${date.day}',
          style: TextStyle(
            color: isToday ? primaryColor : secondaryTextColor,
            fontSize: 10,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout(minWidth: barWidth + spacing);

        textPainter.paint(
          canvas,
          Offset(
            currentX - spacing / 2, // center within the slot
            size.height - bottomLabelHeight + 6,
          ),
        );
      }

      currentX += barWidth + spacing;
    }

    // 6. Draw Accuracy Line
    if (accuracyPoints.isNotEmpty) {
      final linePaint = Paint()
        ..color = correctColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      bool isPathStarted = false;

      for (var point in accuracyPoints) {
        if (point == Offset.infinite) {
          isPathStarted = false;
          continue;
        }

        if (!isPathStarted) {
          path.moveTo(point.dx, point.dy);
          isPathStarted = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }

      // Draw smooth shadow/glow if desired
      canvas.drawPath(path, linePaint);

      // Draw Dots
      final dotPaint = Paint()
        ..color = correctColor
        ..style = PaintingStyle.fill;

      final bgDotPaint = Paint()
        ..color = ThemeManager.getSurfaceColor(themeStyle)
        ..style = PaintingStyle.fill;

      for (var point in accuracyPoints) {
        if (point == Offset.infinite) continue;

        // Draw small white circle behind to clear bar
        canvas.drawCircle(point, 3, bgDotPaint);
        // Draw colored dot
        canvas.drawCircle(point, 2, dotPaint);
      }
    }
  }

  int _ceilToNiceNumber(int number) {
    if (number <= 10) return 10;
    if (number <= 50) return (number / 10).ceil() * 10;
    if (number <= 100) return (number / 20).ceil() * 20;
    return (number / 50).ceil() * 50;
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 4;
    const double dashSpace = 4;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(min(startX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
