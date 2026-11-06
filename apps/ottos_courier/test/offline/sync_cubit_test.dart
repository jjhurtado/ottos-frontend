import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockSync extends Mock implements SyncRepository {}

const _offline = ApiException(CoreTexts.networkError);

Map<String, dynamic> _json(String id, {String status = 'ASSIGNED', String? completedAt, String type = 'DELIVERY'}) => {
  'id': id,
  'code': 'OT-$id',
  'type': type,
  'status': status,
  'completedAt': completedAt,
  'cashAmount': 100,
  'cashCurrency': 'USD',
};

Map<String, dynamic> _cash(double usd) => {
  'cash': {
    'courierId': 'u1',
    'name': 'Luis',
    'balances': [
      {'currency': 'USD', 'amount': usd},
    ],
  },
  'movements': [],
};

Remittance _remittance(String id) => Remittance.fromJson(_json(id));

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
    when(() => server.state(since: any(named: 'since'))).thenAnswer(
      (_) async => SyncState(
        serverTime: 't1',
        full: true,
        remittances: [
          _json('a'),
          _json('b', type: 'PICKUP'),
        ],
        cash: _cash(500),
      ),
    );
    sync = SyncCubit(store: store, sync: server);
    source = OfflineSource(sync: sync);
    await sync.start('u1');
  });

  tearDown(() async {
    await sync.close();
    await store.close();
  });

  SyncResponse answer(List<SyncAction> actions, SyncResult Function(SyncAction action) result) =>
      SyncResponse(serverTime: 't2', results: [for (final action in actions) result(action)]);

  group('business time (REQ-006)', () {
    tearDown(BusinessTime.reset);

    test('AC-2.4 AC-3.1: a sync keeps the zone and the clock difference on the phone', () async {
      BusinessTime.setForTest(deviceClock: () => DateTime.utc(2026, 11, 5, 18));
      when(() => server.state(since: any(named: 'since'))).thenAnswer(
        (_) async => const SyncState(
          serverTime: '2026-11-05T18:10:00Z',
          full: false,
          businessTime: BusinessTimeZone(timeZone: 'UTC-05:00', offsetMinutes: -300),
        ),
      );

      await sync.sync();

      expect(BusinessTime.zone.offsetMinutes, -300);
      expect((await store.businessTime())?.offsetMinutes, -300);
      expect(await store.clockOffset(), const Duration(minutes: 10));
    });

    test('AC-3.1: an action done offline takes the server time, not the phone time', () async {
      var elapsed = Duration.zero;
      BusinessTime.setForTest(deviceClock: () => DateTime.utc(2026, 11, 5, 18), elapsed: () => elapsed);
      when(() => server.state(since: any(named: 'since')))
          .thenAnswer((_) async => const SyncState(serverTime: '2026-11-05T18:10:00Z', full: false));
      await sync.sync();
      when(() => server.send(any())).thenThrow(_offline);
      elapsed = const Duration(minutes: 2);

      await source.deliver(_remittance('a'), pin: '123456');

      expect((await store.pending()).single.occurredAt, DateTime.utc(2026, 11, 5, 18, 12));
    });
  });

  test('starts with the remittances downloaded', () async {
    expect((await source.list()).map((r) => r.id), unorderedEquals(['a', 'b']));
    expect(sync.state.lastSync, isNotNull);
  });

  test('with network a delivery goes straight to the server, checking the PIN strictly', () async {
    late List<SyncAction> sent;
    when(() => server.send(any())).thenAnswer((invocation) async {
      sent = invocation.positionalArguments.first as List<SyncAction>;
      return answer(
        sent,
        (action) => SyncResult(
          id: action.id,
          status: SyncResultStatus.applied,
          remittance: _json('a', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
        ),
      );
    });

    final outcome = await source.deliver(_remittance('a'), pin: '123456');

    expect(outcome, isA<Applied>());
    expect(sent.single.payload, {'pin': '123456', 'strictPin': true});
    expect((await source.list()).map((r) => r.id), ['b'], reason: 'completed, it leaves the phone');
    expect(sync.state.pending, 0);
  });

  test('a wrong PIN with network is rejected on the spot and not queued', () async {
    when(() => server.send(any())).thenAnswer(
      (invocation) async => answer(
        invocation.positionalArguments.first as List<SyncAction>,
        (action) => SyncResult(id: action.id, status: SyncResultStatus.rejected, code: 'INCORRECT_PIN'),
      ),
    );

    final outcome = await source.deliver(_remittance('a'), pin: '000000');

    expect((outcome as Rejected).message, CoreTexts.errorCodes['INCORRECT_PIN']);
    expect(sync.state.pending, 0);
    expect((await source.list()).map((r) => r.id), contains('a'));
  });

  test('without network the action waits on the phone, without the strict PIN', () async {
    when(() => server.send(any())).thenThrow(_offline);

    final outcome = await source.deliver(_remittance('a'), pin: '123456');

    expect(outcome, isA<Queued>());
    expect(sync.state.pending, 1);
    expect(sync.state.offline, isTrue);
    expect((await store.pending()).single.payload, {'pin': '123456'});
    expect((await source.list()).map((r) => r.id), ['b'], reason: 'done for the courier, even unsent');
    expect(await source.pendingIds(), {'a'});
  });

  test('when the network comes back the queue goes in order and the rejected stay to be read', () async {
    when(() => server.send(any())).thenThrow(_offline);
    await source.reportIncident(_remittance('a'), reason: IncidentReason.notHome);
    await source.deliver(_remittance('b'));
    expect(sync.state.pending, 2);

    late List<SyncAction> sent;
    when(() => server.send(any())).thenAnswer((invocation) async {
      sent = invocation.positionalArguments.first as List<SyncAction>;
      return SyncResponse(
        serverTime: 't2',
        results: [
          SyncResult(id: sent[0].id, status: SyncResultStatus.rejected, code: 'REMITTANCE_NOT_FOUND'),
          SyncResult(
            id: sent[1].id,
            status: SyncResultStatus.applied,
            remittance: _json('b', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
          ),
        ],
      );
    });
    when(() => server.state(since: 't1'))
        .thenAnswer((_) async => const SyncState(serverTime: 't3', full: false, removedIds: ['b']));

    await sync.sync();

    expect(sent.map((action) => action.type), [SyncActionType.reportIncident, SyncActionType.deliver]);
    expect(sync.state.pending, 0);
    expect(sync.state.offline, isFalse);
    expect(sync.state.rejected.single.message, CoreTexts.errorCodes['REMITTANCE_NOT_FOUND']);
    expect(await store.serverTime(), 't3');

    await sync.dismiss(sync.state.rejected.single.action.id);
    expect(sync.state.rejected, isEmpty);
  });

  test('a concurrent update stays queued to be sent again', () async {
    when(() => server.send(any())).thenThrow(_offline);
    await source.postpone(_remittance('a'), newDate: DateTime(2026, 10, 20), reason: 'No estaba');
    when(() => server.send(any())).thenAnswer(
      (invocation) async => answer(
        invocation.positionalArguments.first as List<SyncAction>,
        (action) => SyncResult(id: action.id, status: SyncResultStatus.rejected, code: 'CONCURRENT_UPDATE'),
      ),
    );

    await sync.sync();

    expect(sync.state.pending, 1);
    expect(sync.state.rejected, isEmpty);
    expect((await store.pending()).single.payload, {'newDate': '2026-10-20', 'reason': 'No estaba'});
  });

  group('cash', () {
    double usd(CourierStatement? statement) =>
        statement!.cash.balances.singleWhere((balance) => balance.currency == 'USD').amount;

    test('a delivery or pickup done offline already moves the balance, marked unsent', () async {
      when(() => server.send(any())).thenThrow(_offline);
      expect(usd(await sync.cash()), 500);

      await source.deliver(_remittance('a'));
      final afterDelivery = await sync.cash();
      expect(usd(afterDelivery), 400, reason: 'the courier paid out 100 USD');
      expect(SyncCubit.isUnsent(afterDelivery!.movements.first), isTrue);
      expect(afterDelivery.movements.first.note, 'OT-a');

      await source.deliver(Remittance.fromJson(_json('b', type: 'PICKUP')));
      expect(usd(await sync.cash()), 500, reason: 'and collected 100 USD on the pickup');
    });

    test('once sent, the balance is the server one, without double counting', () async {
      when(() => server.send(any())).thenThrow(_offline);
      await source.deliver(_remittance('a'));
      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) => SyncResult(
            id: action.id,
            status: SyncResultStatus.applied,
            remittance: _json('a', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
          ),
        ),
      );
      when(() => server.state(since: 't1'))
          .thenAnswer((_) async => SyncState(serverTime: 't2', full: false, removedIds: const ['a'], cash: _cash(400)));

      await sync.sync();

      final cash = await sync.cash();
      expect(usd(cash), 400);
      expect(cash!.movements.where(SyncCubit.isUnsent), isEmpty);
    });

    test('with network, an applied delivery brings the new balance right away', () async {
      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) => SyncResult(
            id: action.id,
            status: SyncResultStatus.applied,
            remittance: _json('a', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
          ),
        ),
      );
      when(() => server.state(since: 't1'))
          .thenAnswer((_) async => SyncState(serverTime: 't2', full: false, removedIds: const ['a'], cash: _cash(400)));

      await source.deliver(_remittance('a'));
      await sync.sync();

      expect(usd(await sync.cash()), 400);
      verify(() => server.state(since: 't1')).called(greaterThanOrEqualTo(1));
    });

    test('an exchange done offline moves both currencies at once', () async {
      when(() => server.send(any())).thenThrow(_offline);

      final outcome = await sync.exchange(
        const ExchangeInput(fromCurrency: 'USD', fromAmount: 100, toCurrency: 'CUP', rate: 480, note: 'Agro'),
      );

      expect(outcome, isA<Queued>());
      final cash = await sync.cash();
      expect(usd(cash), 400);
      expect(cash!.cash.balances.singleWhere((b) => b.currency == 'CUP').amount, 48000);
      final legs = cash.movements.where(SyncCubit.isUnsent).toList();
      expect(legs.map((m) => m.type), [CashMovementType.courierExchangeIn, CashMovementType.courierExchangeOut]);
      expect(legs.every((m) => m.rate == 480 && m.note == 'Agro'), isTrue);
      final queued = (await store.pending()).single;
      expect(queued.type, SyncActionType.cashExchange);
      expect(queued.remittanceId, isNull);
    });

    test('with network an exchange goes straight to the server and may be flagged', () async {
      late List<SyncAction> sent;
      when(() => server.send(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as List<SyncAction>;
        return answer(
          sent,
          (action) => SyncResult(id: action.id, status: SyncResultStatus.applied, flaggedForReview: true),
        );
      });

      final outcome = await sync.exchange(
        const ExchangeInput(fromCurrency: 'CUP', fromAmount: 1000, toCurrency: 'USD', rate: 2000),
      );

      expect((outcome as Applied).flaggedForReview, isTrue);
      expect(sent.single.payload, {
        'fromCurrency': 'CUP',
        'fromAmount': 1000.0,
        'toCurrency': 'USD',
        'rate': 2000.0,
        'note': null,
      });
      expect(sync.state.pending, 0);
    });
  });

  test('SEC-2: the actions kept at logout are sent when the same courier logs in again', () async {
    when(() => server.send(any())).thenThrow(_offline);
    final action = SyncAction(
      id: SyncRepository.newActionId(),
      type: SyncActionType.deliver,
      remittanceId: 'a',
      occurredAt: DateTime.now(),
    );
    expect(await sync.perform(action), isA<Queued>());

    await sync.clearForLogout();
    await sync.close();
    expect(await store.remittances(), isEmpty);

    // Logs in again, now with network.
    late List<SyncAction> sent;
    when(() => server.send(any())).thenAnswer((invocation) async {
      sent = invocation.positionalArguments.single as List<SyncAction>;
      return answer(sent, (action) => SyncResult(id: action.id, status: SyncResultStatus.applied));
    });
    sync = SyncCubit(store: store, sync: server);
    await sync.start('u1');

    expect(sent.map((sentAction) => sentAction.id), [action.id]);
    expect(await store.pending(), isEmpty);
    expect(sync.state.pending, 0);
  });

  test('SEC-12: logout completes when clearing fails in a running sync', () async {
    when(() => server.state(since: any(named: 'since'))).thenThrow(const FormatException('bad answer'));
    final running = sync.sync().catchError((Object _) {});

    await sync.clearForLogout();
    await running;

    expect(await store.remittances(), isEmpty);
    expect(await store.serverTime(), isNull);
  });

  group('REQ-017: the latest completed ones', () {
    Map<String, dynamic> done(String id, int minutesAgo, {String type = 'DELIVERY'}) => _json(
      id,
      status: 'DELIVERED',
      type: type,
      completedAt: DateTime.utc(2026, 11, 5, 12).subtract(Duration(minutes: minutesAgo)).toIso8601String(),
    );

    Future<void> storeCompleted(List<Map<String, dynamic>> list) =>
        store.applyState(SyncState(serverTime: 't1', full: false, completed: list));

    test('a delivery sent with network leaves the open ones and goes to the completed ones', () async {
      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) => SyncResult(
            id: action.id,
            status: SyncResultStatus.applied,
            remittance: _json('a', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
          ),
        ),
      );

      await source.deliver(_remittance('a'));

      expect((await source.list()).map((r) => r.id), ['b']);
      expect((await store.completed()).map((r) => r['id']), ['a']);
      expect((await source.completed()).items.single.id, 'a');
    });

    test('a voided one is not kept as completed', () async {
      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) => SyncResult(
            id: action.id,
            status: SyncResultStatus.applied,
            remittance: {
              ..._json('a', status: 'DELIVERED', completedAt: '2026-11-05T10:00:00Z'),
              'voided': {'reason': 'Error'},
            },
          ),
        ),
      );

      await source.deliver(_remittance('a'));

      expect(await store.completed(), isEmpty);
    });

    test('AC-2.2: a delivery made offline shows first, completed now, and never also as open', () async {
      await storeCompleted([done('x', 5), done('y', 10)]);
      when(() => server.send(any())).thenThrow(_offline);

      await source.deliver(_remittance('a'));
      final action = (await store.pending()).single;

      expect((await source.list()).map((r) => r.id), ['b']);
      final page = await source.completed();
      expect(page.items.map((r) => r.id), ['a', 'x', 'y']);
      final unsent = page.items.first;
      expect(unsent.isCompleted, isTrue);
      expect(unsent.status, 'DELIVERED');
      expect(unsent.statusName, 'Entregada');
      expect(unsent.completedAt, action.occurredAt);
      expect(await source.pendingIds(), {'a'});
    });

    test('a pickup made offline is marked as collected', () async {
      when(() => server.send(any())).thenThrow(_offline);

      await source.deliver(Remittance.fromJson(_json('b', type: 'PICKUP')));

      expect((await source.completed()).items.single.statusName, 'Recogida');
    });

    test('the same remittance in the queue and in the stored copy shows once, the unsent one', () async {
      await storeCompleted([done('a', 60), done('x', 5)]);
      when(() => server.send(any())).thenThrow(_offline);

      await source.deliver(_remittance('a'));

      final items = (await source.completed()).items;
      expect(items.map((r) => r.id), ['a', 'x']);
      expect(items.first.completedAt, isNot(done('a', 60)['completedAt']));
    });

    test('BR-1: at most 20, one page, so there is no «Ver más»', () async {
      await storeCompleted([for (var i = 0; i < 25; i++) done('d$i', i + 1)]);
      when(() => server.send(any())).thenThrow(_offline);
      await source.deliver(_remittance('a'));

      final page = await source.completed();

      expect(page.items, hasLength(20));
      expect(page.items.first.id, 'a');
      expect(page.items.last.id, 'd18');
      expect(page.totalPages, 1);
    });

    test('AC-1.6: the completed ones open from the phone; the unsent one opens completed, read-only', () async {
      await storeCompleted([done('x', 5)]);
      when(() => server.send(any())).thenThrow(_offline);
      await source.deliver(_remittance('a'));

      expect((await source.get('x')).isCompleted, isTrue);
      expect((await source.get('a')).isCompleted, isTrue, reason: 'queued: completed for the courier');
      expect((await source.get('b')).isCompleted, isFalse);
      await expectLater(source.get('zzz'), throwsA(isA<ApiException>()));
    });

    test('a rejected completing action puts the card back in the open list', () async {
      when(() => server.send(any())).thenThrow(_offline);
      await source.deliver(_remittance('a'));
      expect((await source.completed()).items.map((r) => r.id), ['a']);

      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) =>
              SyncResult(id: action.id, status: SyncResultStatus.rejected, code: 'REMITTANCE_ALREADY_COMPLETED'),
        ),
      );
      await sync.sync();

      expect((await source.list()).map((r) => r.id), contains('a'));
      expect((await source.completed()).items, isEmpty);
      expect(sync.state.rejected, hasLength(1));
    });

    test('a download with the whole list replaces the copy kept after a delivery', () async {
      when(() => server.send(any())).thenAnswer(
        (invocation) async => answer(
          invocation.positionalArguments.first as List<SyncAction>,
          (action) => SyncResult(id: action.id, status: SyncResultStatus.applied, remittance: done('a', 0)),
        ),
      );
      await source.deliver(_remittance('a'));
      when(() => server.state(since: any(named: 'since')))
          .thenAnswer((_) async => SyncState(serverTime: 't3', full: false, completed: [done('x', 5)]));

      await sync.sync();

      expect((await store.completed()).map((r) => r['id']), ['x']);
    });
  });
}
