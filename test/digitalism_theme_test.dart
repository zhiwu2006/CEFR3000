import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/theme/theme_style.dart';
import 'package:vocab_flash_test/theme/theme_manager.dart';
import 'package:vocab_flash_test/theme/digitalism_theme.dart';
import 'package:vocab_flash_test/utils/theme_utils.dart';

void main() {
  group('Digitalism (ThemeStyle.digitalism) Theme Tests', () {
    test(
      'ThemeStyle string parsing and serialization works for digitalism',
      () {
        expect(ThemeStyle.fromString('digitalism'), ThemeStyle.digitalism);
        expect(ThemeStyle.fromString('digital'), ThemeStyle.digitalism);
        expect(ThemeUtils.parseThemeStyle('digitalism'), ThemeStyle.digitalism);
        expect(
          ThemeUtils.themeStyleToString(ThemeStyle.digitalism),
          'digitalism',
        );

        expect(
          availableThemes.any((t) => t.style == ThemeStyle.digitalism),
          isTrue,
        );
        final info = availableThemes.firstWhere(
          (t) => t.style == ThemeStyle.digitalism,
        );
        expect(info.name, 'Digitalism');
        expect(info.icon, '🪟');
      },
    );

    test(
      'ThemeManager returns proper neo-brutalist properties for digitalism',
      () {
        expect(
          ThemeManager.getBackgroundColor(ThemeStyle.digitalism),
          DigitalismTheme.background,
        );
        expect(
          ThemeManager.getSurfaceColor(ThemeStyle.digitalism),
          DigitalismTheme.surface,
        );
        expect(
          ThemeManager.getTextColor(ThemeStyle.digitalism),
          DigitalismTheme.textPrimary,
        );
        expect(
          ThemeManager.getHeaderTextColor(ThemeStyle.digitalism),
          DigitalismTheme.textPrimary,
        );
        expect(
          ThemeManager.getBorderColor(ThemeStyle.digitalism),
          DigitalismTheme.border,
        );
        expect(ThemeManager.getBorderWidth(ThemeStyle.digitalism), 2.5);
        expect(ThemeManager.getBorderRadius(ThemeStyle.digitalism), 12.0);
        expect(ThemeManager.needsBorder(ThemeStyle.digitalism), isTrue);
        expect(
          ThemeManager.getStatusBarBrightness(ThemeStyle.digitalism),
          Brightness.dark,
        );
        expect(ThemeManager.isDarkTheme(ThemeStyle.digitalism), isFalse);

        final shadows = ThemeManager.getCardShadow(ThemeStyle.digitalism);
        expect(shadows.isNotEmpty, isTrue);
        expect(shadows.first.blurRadius, 0.0); // 零弥散硬阴影
        expect(shadows.first.offset, const Offset(4.0, 4.0));
        expect(shadows.first.color, DigitalismTheme.textPrimary);
      },
    );

    test('DigitalismTheme ThemeData matches design specifications', () {
      final themeData = DigitalismTheme.getTheme(null);
      expect(themeData.scaffoldBackgroundColor, DigitalismTheme.background);
      expect(themeData.colorScheme.primary, DigitalismTheme.textPrimary);
      expect(themeData.colorScheme.surface, DigitalismTheme.surface);
      expect(themeData.colorScheme.secondary, DigitalismTheme.accentPeach);
      expect(themeData.colorScheme.outline, DigitalismTheme.border);
    });

    testWidgets(
      'Digitalism widgets (WindowHeader, Card, Banner, Button) render properly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const DigitalismWindowHeader(title: '01/01/2026'),
                    const SizedBox(height: 10),
                    const DigitalismBanner(
                      title: 'MY NEW YEAR RESOLUTIONS',
                      subtitle: 'BE MORE PRODUCTIVE',
                    ),
                    const SizedBox(height: 10),
                    DigitalismCard(
                      windowTitle: 'NEW YEAR',
                      child: Column(
                        children: const [
                          DigitalismConcentricRadio(isSelected: true),
                          SizedBox(height: 10),
                          DigitalismButton(text: 'PARTY!'),
                          SizedBox(height: 10),
                          DigitalismButton(text: 'NAH.', isInverse: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('01/01/2026'), findsOneWidget);
        expect(find.text('MY NEW YEAR RESOLUTIONS'), findsOneWidget);
        expect(find.text('NEW YEAR'), findsOneWidget);
        expect(find.text('PARTY!'), findsOneWidget);
        expect(find.text('NAH.'), findsOneWidget);
      },
    );

    testWidgets('DigitalismWindowHeader defaults to current date dynamically', (tester) async {
      final now = DateTime.now();
      final expectedDate = '${now.year.toString().padLeft(4, '0')}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DigitalismWindowHeader(),
          ),
        ),
      );
      expect(find.text(expectedDate), findsOneWidget);
    });
  });
}
