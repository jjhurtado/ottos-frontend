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
    store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
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
          remittance: _json('a', status: 'DELIVERED', completedAt: '2026-10-10T10:00:00Z'),
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
            remittance: _json('b', status: 'DELIVERED', completedAt: '2026-10-10T10:00:00Z'),
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
            remittance: _json('a', status: 'DELIVERED', completedAt: '2026-10-10T10:00:00Z'),
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
            remittance: _json('a', status: 'DELIVERED', completedAt: '2026-10-10T10:00:00Z'),
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
  });
}
