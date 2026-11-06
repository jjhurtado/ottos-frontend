import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// REQ-017 · QA tests added by the tester: edge cases of the courier's completed
// list over the real SQLite store (in memory) and a stubbed server.

class _MockSync extends Mock implements SyncRepository {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockSource extends Mock implements RemittanceSource {}

const _offline = ApiException(CoreTexts.networkError);

final _now = DateTime.utc(2026, 11, 5, 12);

Map<String, dynamic> _open(String id, {String type = 'DELIVERY'}) => {
  'id': id,
  'code': 'OT-$id',
  'type': type,
  'status': 'ASSIGNED',
  'cashAmount': 100,
  'cashCurrency': 'USD',
};

Map<String, dynamic> _done(String id, int minutesAgo, {String type = 'DELIVERY'}) => {
  ..._open(id, type: type),
  'status': type == 'PICKUP' ? 'COLLECTED' : 'DELIVERED',
  'completedAt': _now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
};

/// [count] completed ones from `d<from>`, `d0` the newest.
List<Map<String, dynamic>> _doneList(int count, {int from = 0}) => [
  for (var i = from; i < from + count; i++) _done('d$i', i),
];

void main() {
  late OfflineStore store;
  late _MockSync server;
  late SyncCubit sync;
  late OfflineSource source;

  setUpAll(() {
    sqfliteFfiInit();
    registerFallbackValue(<SyncAction>[]);
  });

  setUp(() async {
    store = await OfflineStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      now: () => DateTime.utc(2026, 11, 5, 13),
    );
    server = _MockSync();
    sync = SyncCubit(store: store, sync: server);
    source = OfflineSource(sync: sync);
  });

  tearDown(() async {
    await sync.close();
    await store.close();
  });

  Future<void> start({required List<Map<String, dynamic>> open, required List<Map<String, dynamic>> completed}) async {
    when(() => server.state(since: any(named: 'since')))
        .thenAnswer((_) async => SyncState(serverTime: 't1', full: true, remittances: open, completed: completed));
    await sync.start('u1');
  }

  test('AC-1.3 BR-1 (unsent count in the 20): 2 unsent + 25 stored show 20, the unsent first', () async {
    await start(open: [_open('a'), _open('b')], completed: _doneList(25));
    when(() => server.send(any())).thenThrow(_offline);

    await source.deliver(Remittance.fromJson(_open('a')));
    await source.deliver(Remittance.fromJson(_open('b')));
    final page = await source.completed();

    expect(page.items, hasLength(20));
    expect(page.items.take(2).map((r) => r.id), unorderedEquals(['a', 'b']));
    expect(page.items.skip(2).map((r) => r.id), [for (var i = 0; i < 18; i++) 'd$i'], reason: 'newest stored');
    expect(page.page, 0);
    expect(page.items.map((r) => r.id).toSet(), hasLength(20), reason: 'no repeats');
  });

  test(
    'SEC-32: stored ones older than 7 days are gone from the list and from get; an unsent one shows at any age',
    () async {
      await start(
        open: [_open('a')],
        completed: [_done('fresh', 60), _done('stale', 8 * 24 * 60), _done('edge', 7 * 24 * 60 - 60)],
      );
      await store.enqueue(
        SyncAction(
          id: 'act-a',
          type: SyncActionType.deliver,
          remittanceId: 'a',
          occurredAt: _now.subtract(const Duration(days: 30)),
        ),
      );

      final page = await source.completed();

      expect(page.items.map((r) => r.id), ['a', 'fresh', 'edge']);
      await expectLater(source.get('stale'), throwsA(isA<ApiException>()));
      expect((await source.get('a')).id, 'a');
      expect((await source.list()), isEmpty, reason: 'the open one is completed on the phone');
    },
  );

  test('AC-2.1: offline, the list is what the last sync left, newest first', () async {
    await start(open: [_open('a')], completed: [_done('x', 30), _done('y', 5), _done('z', 10)]);
    when(() => server.state(since: any(named: 'since'))).thenThrow(_offline);

    await sync.sync();

    expect(sync.state.offline, isTrue);
    expect((await source.completed()).items.map((r) => r.id), ['y', 'z', 'x']);
    expect((await source.get('y')).isCompleted, isTrue, reason: 'opens from the phone');
  });

  test('AC-1.7: delivered, the next download puts it on top and the oldest of 20 leaves', () async {
    await start(open: [_open('a')], completed: _doneList(20, from: 1));
    expect((await source.completed()).items, hasLength(20));
    expect((await source.completed()).items.last.id, 'd20');

    when(() => server.send(any())).thenThrow(_offline);
    await source.deliver(Remittance.fromJson(_open('a')));
    when(() => server.send(any())).thenAnswer(
      (invocation) async => SyncResponse(
        serverTime: 't2',
        results: [
          for (final action in invocation.positionalArguments.first as List<SyncAction>)
            SyncResult(id: action.id, status: SyncResultStatus.applied, remittance: _done('a', 0)),
        ],
      ),
    );
    when(() => server.state(since: any(named: 'since'))).thenAnswer(
      (_) async => SyncState(
        serverTime: 't3',
        full: false,
        removedIds: const ['a'],
        completed: [_done('a', 0), ..._doneList(19, from: 1)],
      ),
    );
    await sync.sync();

    final ids = (await source.completed()).items.map((r) => r.id).toList();
    expect(ids, hasLength(20));
    expect(ids.first, 'a');
    expect(ids, isNot(contains('d20')), reason: 'the oldest left');
    expect((await source.list()).map((r) => r.id), isNot(contains('a')), reason: 'no longer open');
    expect(await source.pendingIds(), isEmpty);
  });

  test('AC-1.5: only what the server sends is on the phone; another courier\'s remittance is not found', () async {
    await start(open: [_open('a')], completed: [_done('mine', 5)]);

    expect((await source.completed()).items.map((r) => r.id), ['mine']);
    await expectLater(source.get('theirs'), throwsA(isA<ApiException>()));
  });

  test('AC-2.2: a pickup made offline is first in the completed ones and opens as a completed pickup', () async {
    await start(
      open: [_open('p', type: 'PICKUP')],
      completed: [_done('x', 5)],
    );
    when(() => server.send(any())).thenThrow(_offline);

    await source.deliver(Remittance.fromJson(_open('p', type: 'PICKUP')));

    final first = (await source.completed()).items.first;
    expect(first.id, 'p');
    expect(first.isPickup, isTrue);
    expect(first.isCompleted, isTrue);
    expect((await source.get('p')).isCompleted, isTrue);
    expect((await source.list()).map((r) => r.id), isNot(contains('p')));
  });

  test('AC-2.3: after a logout and another courier signing in, the previous completed list is gone', () async {
    await start(open: [_open('a')], completed: [_done('x', 5)]);
    expect((await source.completed()).items, hasLength(1));

    await store.clearForLogout();
    await store.useFor('u2');

    expect((await source.completed()).items, isEmpty);
    await expectLater(source.get('x'), throwsA(isA<ApiException>()));
  });

  group('detail', () {
    Future<void> pumpDetail(WidgetTester tester, Remittance remittance) async {
      final stub = _MockSource();
      when(() => stub.get(remittance.id)).thenAnswer((_) async => remittance);
      await OttosLocalization.initialize();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RemittanceSource>.value(value: stub),
            RepositoryProvider<RemittanceRepository>.value(value: _MockRemittances()),
          ],
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: RemittancePage(remittanceId: remittance.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('AC-1.2 AC-1.6: a completed delivery says so and offers no action', (tester) async {
      await pumpDetail(tester, Remittance.fromJson(_done('d', 5)));

      expect(find.textContaining('Entregada el'), findsOneWidget);
      expect(find.text('OT-d'), findsWidgets);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(BottomAppBar), findsNothing);
    });

    testWidgets('AC-1.2 AC-1.6: a completed pickup says «Recogida» and offers no action', (tester) async {
      await pumpDetail(tester, Remittance.fromJson(_done('p', 5, type: 'PICKUP')));

      expect(find.textContaining('Recogida el'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
