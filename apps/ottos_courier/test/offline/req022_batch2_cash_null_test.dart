// REQ-022 batch 2, OPT-B10 (tester): from rc.13 the backend sends `"cash": null`
// in GET /sync/state with since when the statement did not change. The phone must
// keep the copy it has. The answers are parsed from JSON with SyncState.fromJson,
// as they come from the server, not built as objects.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockSync extends Mock implements SyncRepository {}

const _offline = ApiException(CoreTexts.networkError);

const _workflow = '''
{"statuses": [
  {"code": "PAID", "name": "Pagada", "position": 10, "initial": true, "requiresCourier": false, "isFinal": false},
  {"code": "ASSIGNED", "name": "Asignada", "position": 20, "initial": false, "requiresCourier": true, "isFinal": false},
  {"code": "DELIVERED", "name": "Entregada", "position": 30, "initial": false, "requiresCourier": false, "isFinal": true}
 ], "transitions": []}''';

const _businessTime = '{"timeZone": "UTC-04:00", "offsetMinutes": -240}';

String _remittance(String id) =>
    '{"id": "$id", "code": "OT-$id", "type": "DELIVERY", "status": "ASSIGNED", "cashAmount": 100, '
    '"cashCurrency": "USD"}';

String _statement(double usd, {int movements = 1}) =>
    '''
{"cash": {"courierId": "u1", "name": "Mensajero Prueba", "balances": [{"currency": "USD", "amount": $usd}],
  "negative": false},
 "movements": [${List.generate(movements, (i) => '{"id": "m$i", "type": "COURIER_FUNDING", "fromType": "BUSINESS", '
        '"toType": "COURIER", "toOwnerId": "u1", "amount": 10, "currency": "USD", "signedAmount": 10, '
        '"actorId": "x", "occurredAt": "2026-11-0${i + 1}T12:00:00Z"}').join(', ')}]}''';

/// A GET /sync/state body as rc.13 sends it. [cash] is raw JSON, `null`, or
/// leaves the key out when [omitKey].
SyncState _answer({
  required String serverTime,
  required bool full,
  String remittances = '',
  String cash = 'null',
  bool omitKey = false,
}) {
  final cashPart = omitKey ? '' : '"cash": $cash, ';
  return SyncState.fromJson(
    jsonDecode(
      '{"serverTime": "$serverTime", "full": $full, "remittances": [$remittances], "removedIds": [], '
      '$cashPart"workflow": $_workflow, "businessTime": $_businessTime, "completed": []}',
    ) as Map<String, dynamic>,
  );
}

void main() {
  late OfflineStore store;
  late _MockSync server;
  late SyncCubit sync;
  final sinces = <String?>[];

  double usd(CourierStatement? statement) =>
      statement!.cash.balances.singleWhere((balance) => balance.currency == 'USD').amount;

  setUpAll(() {
    sqfliteFfiInit();
    registerFallbackValue(<SyncAction>[]);
  });

  setUp(() async {
    sinces.clear();
    store = await OfflineStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      now: () => DateTime.utc(2026, 11, 6, 13),
    );
    server = _MockSync();
    when(() => server.state(since: any(named: 'since'))).thenAnswer((invocation) async {
      final since = invocation.namedArguments[#since] as String?;
      sinces.add(since);
      return since == null
          ? _answer(serverTime: 't1', full: true, remittances: _remittance('a'), cash: _statement(500, movements: 3))
          : _answer(serverTime: 't${sinces.length}', full: false);
    });
    sync = SyncCubit(store: store, sync: server);
    await sync.start('u1');
  });

  tearDown(() async {
    await sync.close();
    await store.close();
  });

  test('OPT-B10 (cash null): the phone keeps its balance and movements after a delta with "cash": null', () async {
    expect(usd(await sync.cash()), 500);

    await sync.sync();
    await sync.sync();

    expect(sinces, [null, 't1', 't2'], reason: 'each download sends the serverTime of the previous one');
    final cash = await sync.cash();
    expect(usd(cash), 500);
    expect(cash!.movements, hasLength(3));
    expect(cash.cash.name, 'Mensajero Prueba');
    expect((await store.cash())!.movements, hasLength(3), reason: 'the stored copy itself is kept');
    expect(await store.serverTime(), 't3');
    expect((await store.workflow())!.statuses, hasLength(3));
  });

  test('OPT-B10 (cash key absent): a body without the cash key is read the same as null', () async {
    when(() => server.state(since: 't1'))
        .thenAnswer((_) async => _answer(serverTime: 't2', full: false, omitKey: true));

    await sync.sync();

    expect(usd(await sync.cash()), 500);
  });

  test('OPT-B10 (cash null, then changed): a later statement replaces the kept copy', () async {
    await sync.sync();
    when(() => server.state(since: 't2'))
        .thenAnswer((_) async => _answer(serverTime: 't3', full: false, cash: _statement(420, movements: 4)));

    await sync.sync();

    final cash = await sync.cash();
    expect(usd(cash), 420);
    expect(cash!.movements, hasLength(4));
  });

  test('OPT-B10 (cash null, queued delivery): the unsent payout still applies on top of the kept copy', () async {
    when(() => server.send(any())).thenThrow(_offline);
    await OfflineSource(sync: sync).deliver(Remittance.fromJson(jsonDecode(_remittance('a')) as Map<String, dynamic>));
    when(() => server.send(any())).thenThrow(_offline);

    await sync.sync(); // the send fails offline, so no download either
    expect(usd(await sync.cash()), 400);

    reset(server);
    when(() => server.send(any())).thenAnswer(
      (invocation) async => SyncResponse(
        serverTime: 't5',
        results: [
          for (final action in invocation.positionalArguments.first as List<SyncAction>)
            SyncResult(id: action.id, status: SyncResultStatus.rejected, code: 'INVALID_TRANSITION'),
        ],
      ),
    );
    when(() => server.state(since: any(named: 'since')))
        .thenAnswer((_) async => _answer(serverTime: 't6', full: false));

    await sync.sync();

    // Rejected, so no movement on the server and cash comes null: the copy is the server's last one, untouched
    final cash = await sync.cash();
    expect(usd(cash), 500);
    expect(cash!.movements.where(SyncCubit.isUnsent), isEmpty);
  });

  test('OPT-B10 (logout): after logout the phone has no copy and no since, so the next download is full', () async {
    await sync.sync();
    await sync.clearForLogout();

    expect(await store.cash(), isNull);
    expect(await store.serverTime(), isNull);
  });
}
