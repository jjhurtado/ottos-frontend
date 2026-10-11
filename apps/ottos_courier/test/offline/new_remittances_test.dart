import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockSync extends Mock implements SyncRepository {}

Map<String, dynamic> _json(String id, {String? completedAt}) => {
  'id': id,
  'code': 'OT-$id',
  'type': 'DELIVERY',
  'status': completedAt == null ? 'ASSIGNED' : 'DELIVERED',
  'completedAt': completedAt,
};

void main() {
  late OfflineStore store;
  late _MockSync server;
  late List<List<String>> announced;
  late SyncCubit sync;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
    server = _MockSync();
    announced = [];
    sync = SyncCubit(
      store: store,
      sync: server,
      onNewRemittances: (remittances) => announced.add([for (final remittance in remittances) remittance.id]),
    );
  });

  tearDown(() async {
    await sync.close();
    await store.close();
  });

  void serverHas(SyncState state) =>
      when(() => server.state(since: any(named: 'since'))).thenAnswer((_) async => state);

  test('the first download announces nothing: it is what was already open', () async {
    serverHas(SyncState(serverTime: 't1', full: true, remittances: [_json('a'), _json('b')]));
    await sync.start('u1');
    expect(announced, isEmpty);
  });

  test('later downloads announce only the remittances the phone did not have', () async {
    serverHas(SyncState(serverTime: 't1', full: true, remittances: [_json('a')]));
    await sync.start('u1');

    // "a" changed (postponed, say) and "c" is new; "d" came already delivered.
    serverHas(
      SyncState(
        serverTime: 't2',
        full: false,
        remittances: [
          _json('a'),
          _json('c'),
          _json('d', completedAt: '2026-10-11T10:00:00Z'),
        ],
      ),
    );
    await sync.sync();
    expect(announced, [
      ['c'],
    ]);

    serverHas(const SyncState(serverTime: 't3', full: false));
    await sync.sync();
    expect(announced, hasLength(1));
  });
}
