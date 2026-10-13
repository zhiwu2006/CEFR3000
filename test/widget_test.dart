// Basic Flutter widget test for VocabFlashTest app

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocab_flash_test/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: VocabFlashTestApp()));

    // Wait for the app to load
    await tester.pump();

    // Verify that the app renders without errors
    expect(find.byType(VocabFlashTestApp), findsOneWidget);
  });
}
