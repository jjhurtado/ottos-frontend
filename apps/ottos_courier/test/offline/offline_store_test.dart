import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _remittance(String id, {String status = 'ASSIGNED'}) => {
  'id': id,
  'code': 'OT-$id',
  'type': 'DELIVERY',
  'status': status,
};

SyncAction _action(String remittanceId, {SyncActionType type = SyncActionType.deliver}) =>
    SyncAction(id: SyncRepository.newActionId(), type: type, remittanceId: remittanceId, occurredAt: DateTime.now());

void main() {
  late OfflineStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    await store.useFor('u1');
  });

  tearDown(() => store.close());

  test('a full download replaces the remittances; a partial one adds and removes', () async {
    await store.applyState(SyncState(serverTime: 't1', full: true, remittances: [_remittance('a'), _remittance('b')]));
    expect((await store.remittances()).map((r) => r['id']), unorderedEquals(['a', 'b']));

    await store.applyState(
      SyncState(serverTime: 't2', full: false, remittances: [_remittance('c')], removedIds: const ['a']),
    );
    expect((await store.remittances()).map((r) => r['id']), unorderedEquals(['b', 'c']));
    expect(await store.serverTime(), 't2');
    expect(await store.lastSync(), isNotNull);

    await store.applyState(SyncState(serverTime: 't3', full: true, remittances: [_remittance('d')]));
    expect((await store.remittances()).map((r) => r['id']), ['d']);
  });

  test('keeps the cash and the workflow', () async {
    await store.applyState(
      const SyncState(
        serverTime: 't1',
        full: true,
        cash: {
          'cash': {
            'courierId': 'u1',
            'name': 'Luis',
            'balances': [
              {'currency': 'USD', 'amount': 20},
            ],
          },
          'movements': [],
        },
        workflow: {'statuses': [], 'transitions': []},
      ),
    );

    expect((await store.cash())!.cash.balances.single.amount, 20);
    expect(await store.workflow(), isNotNull);
  });

  test('the queue keeps its order; done actions leave it and rejected ones are set aside', () async {
    final first = _action('a');
    final second = _action('b', type: SyncActionType.postpone);
    final third = _action('c');
    for (final action in [first, second, third]) {
      await store.enqueue(action);
    }

    await store.done(first.id);
    await store.reject(second.id, code: 'REMITTANCE_NOT_FOUND', message: 'Not found');

    expect(await store.pending(), [third]);
    final rejected = await store.rejected();
    expect(rejected.single.action, second);
    expect(rejected.single.code, 'REMITTANCE_NOT_FOUND');

    await store.dismiss(second.id);
    expect(await store.rejected(), isEmpty);
  });

  test('another user on the phone starts empty; the same user keeps everything', () async {
    await store.applyState(SyncState(serverTime: 't1', full: true, remittances: [_remittance('a')]));
    await store.enqueue(_action('a'));

    await store.useFor('u1');
    expect(await store.pending(), hasLength(1));

    await store.useFor('u2');
    expect(await store.remittances(), isEmpty);
    expect(await store.pending(), isEmpty);
    expect(await store.serverTime(), isNull);
  });
}
