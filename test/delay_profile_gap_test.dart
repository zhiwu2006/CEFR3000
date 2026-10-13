import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/models/app_settings.dart';
import 'package:vocab_flash_test/session/delayed_replay_manager.dart';

void main() {
  test('every delay profile respects the minimum retry gap', () {
    for (final profile in DelayProfile.values) {
      final settings = AppSettings.defaultSettings.copyWith(
        delayProfile: profile,
      );
      final delay = settings.delayConfig;
      expect(
        delay.wrongDelay,
        greaterThanOrEqualTo(DelayedReplayManager.minRetryGap),
        reason: '$profile wrongDelay would be silently clamped',
      );
      expect(delay.slowDelay, greaterThanOrEqualTo(delay.wrongDelay));
    }
  });
}
