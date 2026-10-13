import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_flash_test/features/sync/presentation/sync_status_badge.dart';

void main() {
  final now = DateTime(2026, 10, 13, 15);
  String describe(DateTime at) =>
      SyncStatusBadge.describeSyncTime(at, now: now);

  test('sync time reads as today, yesterday or a date', () {
    expect(describe(DateTime(2026, 10, 13, 9, 5)), '今天 09:05');
    expect(describe(DateTime(2026, 10, 12, 23, 59)), '昨天 23:59');
    expect(describe(DateTime(2026, 10, 1, 8)), '10月1日');
  });
}
