import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/theme/theme_style.dart';
import 'package:vocab_flash_test/theme/theme_manager.dart';
import 'package:vocab_flash_test/theme/fono_theme.dart';
import 'package:vocab_flash_test/utils/theme_utils.dart';

void main() {
  group('Aeonik Fono (ThemeStyle.fono) Theme Tests', () {
    test('ThemeStyle string parsing and serialization works for fono', () {
      expect(ThemeStyle.fromString('fono'), ThemeStyle.fono);
      expect(ThemeStyle.fromString('aeonik'), ThemeStyle.fono);
      expect(ThemeStyle.fromString('aeonikFono'), ThemeStyle.fono);
      expect(ThemeUtils.parseThemeStyle('fono'), ThemeStyle.fono);
      expect(ThemeUtils.themeStyleToString(ThemeStyle.fono), 'fono');

      expect(availableThemes.any((t) => t.style == ThemeStyle.fono), isTrue);
      final fonoInfo = availableThemes.firstWhere(
        (t) => t.style == ThemeStyle.fono,
      );
      expect(fonoInfo.name, 'Aeonik Fono');
    });

    test('ThemeManager returns proper engineering properties for fono', () {
      expect(
        ThemeManager.getBackgroundColor(ThemeStyle.fono),
        FonoTheme.background,
      );
      expect(ThemeManager.getSurfaceColor(ThemeStyle.fono), FonoTheme.surface);
      expect(ThemeManager.getTextColor(ThemeStyle.fono), FonoTheme.textPrimary);
      expect(
        ThemeManager.getHeaderTextColor(ThemeStyle.fono),
        FonoTheme.textPrimary,
      );
      expect(ThemeManager.getBorderColor(ThemeStyle.fono), FonoTheme.border);
      expect(
        ThemeManager.getBorderWidth(ThemeStyle.fono),
        FonoTheme.borderWidth,
      );
      expect(
        ThemeManager.getBorderRadius(ThemeStyle.fono),
        FonoTheme.cardRadius,
      );
      expect(ThemeManager.getCardShadow(ThemeStyle.fono), isEmpty);
      expect(ThemeManager.needsBorder(ThemeStyle.fono), isTrue);
      expect(
        ThemeManager.getStatusBarBrightness(ThemeStyle.fono),
        Brightness.dark,
      );
      expect(ThemeManager.isDarkTheme(ThemeStyle.fono), isFalse);
    });

    test('FonoTheme ThemeData build matches engineering specifications', () {
      final themeData = FonoTheme.getTheme(null);
      expect(themeData.scaffoldBackgroundColor, FonoTheme.background);
      expect(themeData.colorScheme.primary, FonoTheme.textPrimary);
      expect(themeData.colorScheme.surface, FonoTheme.surface);
      expect(themeData.colorScheme.outline, FonoTheme.border);
    });

    testWidgets('Fono technical widgets render without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FonoGridBackground(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    FonoRadiatorWidget(width: 50, height: 60),
                    SizedBox(width: 20),
                    FonoSolarPanelWidget(width: 60, height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FonoGridBackground), findsOneWidget);
      expect(find.byType(FonoRadiatorWidget), findsOneWidget);
      expect(find.byType(FonoSolarPanelWidget), findsOneWidget);
    });
  });
}
