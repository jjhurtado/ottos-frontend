import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';

void main() {
  setUpAll(OttosLocalization.initialize);
  tearDown(BusinessTime.reset);

  test('CR-3 AC-2.1: «Sincronizado a las…» is in the business time zone, not the phone\'s', () {
    BusinessTime.setZone(BusinessTimeZone.ofMinutes(-300));
    final lastSync = DateTime.utc(2026, 11, 5, 18, 32);

    final text = CourierTexts.syncSummary(SyncStatus(lastSync: lastSync), now: lastSync.add(const Duration(hours: 2)));

    expect(text, 'Sincronizado a las 13:32');
  });
}
