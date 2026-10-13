import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 应用图标生成器
class AppIconGenerator {
  /// 生成应用图标
  static Future<Uint8List> generateIcon({
    double size = 512,
    Color primaryColor = const Color(0xFF2196F3),
    Color secondaryColor = const Color(0xFF1976D2),
    Color accentColor = const Color(0xFFFFEB3B),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    // 背景渐变
    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(size, size),
      [primaryColor, secondaryColor],
    );

    paint.shader = gradient;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size, size),
        Radius.circular(size * 0.2),
      ),
      paint,
    );

    // 绘制闪卡
    _drawFlashCard(canvas, size, Colors.white);

    // 绘制文字元素
    _drawTextElements(canvas, size, primaryColor, accentColor);

    // 绘制装饰元素
    _drawDecorations(canvas, size, accentColor);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 绘制闪卡
  static void _drawFlashCard(Canvas canvas, double size, Color cardColor) {
    final paint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;

    // 主卡片
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size * 0.5, size * 0.5),
        width: size * 0.6,
        height: size * 0.4,
      ),
      Radius.circular(size * 0.05),
    );

    // 添加阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      cardRect.shift(Offset(size * 0.02, size * 0.02)),
      shadowPaint,
    );

    canvas.drawRRect(cardRect, paint);

    // 背景卡片（营造层叠效果）
    final bgCardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size * 0.52, size * 0.48),
        width: size * 0.58,
        height: size * 0.38,
      ),
      Radius.circular(size * 0.05),
    );

    final bgPaint = Paint()..color = cardColor.withValues(alpha: 0.8);

    canvas.drawRRect(bgCardRect, bgPaint);
  }

  /// 绘制文字元素
  static void _drawTextElements(
    Canvas canvas,
    double size,
    Color primaryColor,
    Color accentColor,
  ) {
    // 绘制字母 "A"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          fontSize: size * 0.15,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(size * 0.42, size * 0.42));

    // 绘制小装饰点
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size * 0.58, size * 0.45), size * 0.015, dotPaint);

    canvas.drawCircle(Offset(size * 0.58, size * 0.52), size * 0.012, dotPaint);

    canvas.drawCircle(Offset(size * 0.58, size * 0.58), size * 0.01, dotPaint);
  }

  /// 绘制装饰元素
  static void _drawDecorations(Canvas canvas, double size, Color accentColor) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // 左上角装饰
    canvas.drawCircle(Offset(size * 0.15, size * 0.15), size * 0.03, paint);

    // 右下角装饰
    canvas.drawCircle(Offset(size * 0.85, size * 0.85), size * 0.025, paint);

    // 添加一些小星星装饰
    _drawStar(canvas, Offset(size * 0.8, size * 0.2), size * 0.02, accentColor);
    _drawStar(
      canvas,
      Offset(size * 0.2, size * 0.8),
      size * 0.015,
      accentColor,
    );
  }

  /// 绘制星星
  static void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final path = Path();
    const int points = 5;
    const double angle = (2 * math.pi) / points;

    for (int i = 0; i < points; i++) {
      if (i == 0) {
        path.moveTo(center.dx, center.dy - radius);
      } else {
        final double currentAngle = angle * i - math.pi / 2;
        final double currentRadius = i % 2 == 0 ? radius : radius * 0.4;
        path.lineTo(
          center.dx + currentRadius * math.cos(currentAngle),
          center.dy + currentRadius * math.sin(currentAngle),
        );
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
