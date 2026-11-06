import 'dart:io';

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

Map<String, dynamic> _done(String id, DateTime completedAt) => {
  ..._remittance(id, status: 'DELIVERED'),
  'completedAt': completedAt.toUtc().toIso8601String(),
};

/// [count] completed ones, `d0` the newest.
List<Map<String, dynamic>> _doneList(int count) => [
  for (var i = 0; i < count; i++) _done('d$i', DateTime.utc(2026, 11, 5, 12).subtract(Duration(minutes: i))),
];

SyncAction _action(String remittanceId, {SyncActionType type = SyncActionType.deliver}) =>
    SyncAction(id: SyncRepository.newActionId(), type: type, remittanceId: remittanceId, occurredAt: DateTime.now());

void main() {
  late OfflineStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = await OfflineStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfiNoIsolate,
      now: () => DateTime.utc(2026, 11, 5, 13),
    );
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

  test('SEC-2: after logout the offline store keeps only the unsent actions', () async {
    await store.applyState(
      SyncState(
        serverTime: 't1',
        full: true,
        remittances: [_remittance('a')],
        cash: const {'cash': null, 'movements': []},
        workflow: const {},
      ),
    );
    await store.saveSetting('completedSince.u1', '2026-11-05');
    final unsent = _action('a');
    await store.enqueue(unsent);
    final refused = _action('a', type: SyncActionType.reportIncident);
    await store.enqueue(refused);
    await store.reject(refused.id, code: 'REMITTANCE_NOT_FOUND');

    await store.clearForLogout();

    expect(await store.remittances(), isEmpty);
    expect(await store.cash(), isNull);
    expect(await store.workflow(), isNull);
    expect(await store.serverTime(), isNull);
    expect(await store.lastSync(), isNull);
    expect(await store.setting('completedSince.u1'), isNull);
    expect(await store.rejected(), isEmpty);
    expect((await store.pending()).map((action) => action.id), [unsent.id]);

    // Still this user's: the same courier finds them; anyone else does not.
    await store.useFor('u1');
    expect(await store.pending(), hasLength(1));
    await store.useFor('u2');
    expect(await store.pending(), isEmpty);
  });

  group('REQ-017: the latest completed ones', () {
    test('AC-2.1: a download brings them, newest first, and a full one replaces them whole', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(3)));
      expect((await store.completed()).map((r) => r['id']), ['d0', 'd1', 'd2']);

      // A delta still carries the whole list: the copy is replaced, not added to.
      await store.applyState(
        SyncState(serverTime: 't2', full: false, completed: [_done('n', DateTime.utc(2026, 11, 6)), _doneList(2).last]),
      );
      expect((await store.completed()).map((r) => r['id']), ['n', 'd1']);

      await store.applyState(const SyncState(serverTime: 't3', full: false, completed: []));
      expect(await store.completed(), isEmpty);
    });

    test('an older backend sends none: the stored copy is left as it is', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(2)));

      await store.applyState(SyncState(serverTime: 't2', full: true, remittances: [_remittance('a')]));

      expect((await store.completed()).map((r) => r['id']), ['d0', 'd1']);
    });

    test('BR-1: at most 20 are kept, the newest, whatever order they come in', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(25).reversed.toList()));

      final kept = (await store.completed()).map((r) => r['id']).toList();
      expect(kept, [for (var i = 0; i < 20; i++) 'd$i']);
    });

    test('BR-1: one more just completed pushes the oldest out', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(20)));

      await store.putCompleted(_done('new', DateTime.utc(2026, 11, 5, 13)));

      final kept = (await store.completed()).map((r) => r['id']).toList();
      expect(kept, hasLength(20));
      expect(kept.first, 'new');
      expect(kept, isNot(contains('d19')));
      expect((await store.completedRemittance('d0'))!['code'], 'OT-d0');
      expect(await store.completedRemittance('d19'), isNull);
    });

    test('BR-4: logging out deletes them', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(2)));

      await store.clearForLogout();

      expect(await store.completed(), isEmpty);
    });

    test('AC-2.3: another courier on the phone does not find them; the same one does', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(2)));

      await store.useFor('u1');
      expect(await store.completed(), hasLength(2));

      await store.useFor('u2');
      expect(await store.completed(), isEmpty);
    });

    test('a phone with the first schema upgrades keeping its data, with no completed ones yet', () async {
      final dir = Directory.systemTemp.createTempSync('ottos_store_v1');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/offline.db';
      final old = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE remittances (id TEXT PRIMARY KEY, json TEXT NOT NULL)');
            await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await db.execute(
              'CREATE TABLE actions (seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE, '
              'remittance_id TEXT NOT NULL, json TEXT NOT NULL, rejected INTEGER NOT NULL DEFAULT 0, '
              'code TEXT, message TEXT)',
            );
            await db.insert('remittances', {'id': 'a', 'json': '{"id":"a","code":"OT-a","type":"DELIVERY"}'});
            await db.insert('settings', {'key': 'userId', 'value': 'u1'});
          },
        ),
      );
      await old.close();

      final upgraded = await OfflineStore.open(
        path: path,
        factory: databaseFactoryFfiNoIsolate,
        now: () => DateTime.utc(2026, 11, 5, 13),
      );
      addTearDown(upgraded.close);

      expect((await upgraded.remittances()).single['id'], 'a');
      expect(await upgraded.completed(), isEmpty);
      await upgraded.applyState(SyncState(serverTime: 't1', full: false, completed: _doneList(2)));
      expect(await upgraded.completed(), hasLength(2));
    });
  });

  group('REQ-017 SEC-32 SEC-33: stored completed ones expire after 7 days', () {
    final now = DateTime.utc(2026, 11, 5, 13);
    final cutoff = now.subtract(OfflineStore.maxCompletedAge);

    Future<OfflineStore> openAt(DateTime Function() clock) async {
      final other = await OfflineStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate,
        now: clock,
      );
      addTearDown(other.close);
      return other;
    }

    test('the age limit is 7 days', () => expect(OfflineStore.maxCompletedAge, const Duration(days: 7)));

    test('reading deletes the older ones, the list and one by id', () async {
      var clock = now;
      final aging = await openAt(() => clock);
      await aging.applyState(SyncState(serverTime: 't1', full: true, completed: [_done('x', now)]));
      expect(await aging.completedRemittance('x'), isNotNull);

      clock = now.add(const Duration(days: 7, seconds: 1));

      expect(await aging.completedRemittance('x'), isNull);
      expect(await aging.completed(), isEmpty);
    });

    test('exactly 7 days stays; one second more goes', () async {
      var clock = now;
      final aging = await openAt(() => clock);
      await aging.applyState(SyncState(serverTime: 't1', full: true, completed: [_done('x', now)]));

      clock = now.add(const Duration(days: 7));
      expect((await aging.completed()).map((r) => r['id']), ['x']);

      clock = now.add(const Duration(days: 7, seconds: 1));
      expect(await aging.completed(), isEmpty);
    });

    test('applyState drops the ones that arrive older than 7 days and keeps the rest', () async {
      await store.applyState(
        SyncState(
          serverTime: 't1',
          full: true,
          completed: [
            _done('old', cutoff.subtract(const Duration(seconds: 1))),
            _done('edge', cutoff),
            _done('recent', now.subtract(const Duration(days: 2))),
          ],
        ),
      );

      expect((await store.completed()).map((r) => r['id']), ['recent', 'edge']);
    });

    test('applyState without a completed list still expires the stored ones', () async {
      var clock = now;
      final aging = await openAt(() => clock);
      await aging.applyState(SyncState(serverTime: 't1', full: true, completed: [_done('x', now)]));

      clock = now.add(const Duration(days: 8));
      await aging.applyState(const SyncState(serverTime: 't2', full: false));

      expect(await aging.completed(), isEmpty);
    });

    test('putCompleted drops an old one, keeps a recent one', () async {
      await store.putCompleted(_done('old', now.subtract(const Duration(days: 8))));
      await store.putCompleted(_done('recent', now.subtract(const Duration(days: 6))));

      expect((await store.completed()).map((r) => r['id']), ['recent']);
    });

    test('one without a known completed date counts as old', () async {
      await store.putCompleted({..._remittance('none', status: 'DELIVERED')});
      await store.putCompleted({..._done('bad', now), 'completedAt': 'not a date'});

      expect(await store.completed(), isEmpty);
    });

    test('the cap of 20 still applies inside the 7 days', () async {
      await store.applyState(SyncState(serverTime: 't1', full: true, completed: _doneList(25)));

      expect(await store.completed(), hasLength(20));
    });

    test('open remittances and unsent actions are never touched', () async {
      var clock = now;
      final aging = await openAt(() => clock);
      await aging.useFor('u1');
      await aging.applyState(SyncState(serverTime: 't1', full: true, remittances: [_remittance('a')]));
      await aging.enqueue(_action('a'));

      clock = now.add(const Duration(days: 30));
      await aging.completed();
      await aging.applyState(const SyncState(serverTime: 't2', full: false));

      expect((await aging.remittances()).single['id'], 'a');
      expect(await aging.pending(), hasLength(1));
    });
  });
}
