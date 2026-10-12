import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/notifications/completed_watcher.dart';
import 'package:ottos_courier/notifications/notices.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

Remittance _remittance(String id, {String type = 'DELIVERY', String? courierId = 'c1'}) => Remittance.fromJson({
  'id': id,
  'code': 'OT-$id',
  'type': type,
  'status': 'DELIVERED',
  'beneficiaryName': 'Rosa',
  'municipalityName': 'Boyeros',
  'courierId': courierId,
  'courierName': 'Luis',
});

void main() {
  group('notices', () {
    test('one per new remittance, saying what and where', () {
      final notices = newRemittanceNotices([_remittance('a'), _remittance('b', type: 'PICKUP')]);
      expect(notices.map((notice) => notice.title), ['Nueva entrega asignada', 'Nueva recogida asignada']);
      expect(notices.first.body, 'OT-a · Rosa · Boyeros');
      expect(notices.first.remittanceId, 'a');
      expect(notices.first.id, isNot(notices.last.id));
    });

    test('many at once become one', () {
      final notices = completedNotices([
        for (final id in ['a', 'b', 'c', 'd']) _remittance(id),
      ]);
      expect(notices, hasLength(1));
      expect(notices.single.title, '4 remesas completadas');
      expect(notices.single.body, 'OT-a, OT-b, OT-c, OT-d');
      expect(notices.single.remittanceId, isNull);
    });

    test('a completed one says who did it', () {
      final notice = completedNotices([_remittance('a')]).single;
      expect(notice.title, 'Remesa entregada');
      expect(notice.body, 'OT-a · Rosa · Luis');
      expect(completedNotices([_remittance('b', type: 'PICKUP')]).single.title, 'Recogida completada');
    });
  });

  group('completed watcher', () {
    late _MockRemittances remittances;
    late List<List<String>> announced;
    String? saved;

    setUp(() {
      remittances = _MockRemittances();
      announced = [];
      saved = null;
    });

    CompletedWatcher watcher({String? since}) => CompletedWatcher(
      remittances: remittances,
      userId: 'me',
      onCompleted: (list) => announced.add([for (final remittance in list) remittance.id]),
      readSince: () async => saved ?? since,
      saveSince: (value) async => saved = value,
    );

    test('the first check only marks where to start', () async {
      when(() => remittances.completed()).thenAnswer((_) async => const CompletedFeed(serverTime: 't1'));
      await watcher().check();
      expect(saved, 't1');
      expect(announced, isEmpty);
    });

    test('follows the pages and skips your own deliveries', () async {
      when(() => remittances.completed(since: 't1'))
          .thenAnswer((_) async => CompletedFeed(serverTime: 't2', hasMore: true, remittances: [_remittance('a')]));
      when(() => remittances.completed(since: 't2')).thenAnswer(
        (_) async => CompletedFeed(
          serverTime: 't3',
          remittances: [
            _remittance('b', courierId: 'me'),
            _remittance('c'),
          ],
        ),
      );
      final check = watcher(since: 't1');
      await check.check();
      expect(announced, [
        ['a', 'c'],
      ]);
      expect(saved, 't3');
    });

    test('without network it keeps its place and tries again', () async {
      when(() => remittances.completed(since: 't1')).thenThrow(const ApiException(CoreTexts.networkError));
      await watcher(since: 't1').check();
      expect(announced, isEmpty);
      expect(saved, isNull);
    });
  });
}
