import 'dart:convert';

import 'package:ottos_core/ottos_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// An action that the server rejected; kept so the courier sees why.
class RejectedAction {
  const RejectedAction({required this.action, this.code, this.message});

  final SyncAction action;
  final String? code;
  final String? message;
}

/// What the courier needs to work without network, in SQLite on the phone:
/// the assigned remittances as the server sent them, the cash, the workflow,
/// and the queue of actions waiting to be sent.
class OfflineStore {
  OfflineStore._(this._db);

  final Database _db;

  static const _version = 1;

  /// Opens the store of the app ([path] for tests, e.g. `inMemoryDatabasePath`).
  static Future<OfflineStore> open({String? path, DatabaseFactory? factory}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'ottos_offline.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: _version, onCreate: (db, _) => _create(db)),
    );
    return OfflineStore._(db);
  }

  static Future<void> _create(Database db) async {
    await db.execute('CREATE TABLE remittances (id TEXT PRIMARY KEY, json TEXT NOT NULL)');
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    // seq keeps the order the actions happened in; they are sent in that order.
    await db.execute('''
      CREATE TABLE actions (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        id TEXT NOT NULL UNIQUE,
        remittance_id TEXT NOT NULL,
        json TEXT NOT NULL,
        rejected INTEGER NOT NULL DEFAULT 0,
        code TEXT,
        message TEXT
      )
    ''');
  }

  Future<void> close() => _db.close();

  // Remittances

  Future<List<Map<String, dynamic>>> remittances() async => [
    for (final row in await _db.query('remittances')) jsonDecode(row['json']! as String) as Map<String, dynamic>,
  ];

  Future<Map<String, dynamic>?> remittance(String id) async {
    final rows = await _db.query('remittances', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : jsonDecode(rows.single['json']! as String) as Map<String, dynamic>;
  }

  /// Applies a download: replaces everything when [full], otherwise adds or
  /// updates [remittances] and drops [removedIds].
  Future<void> applyState(SyncState state) => _db.transaction((txn) async {
    if (state.full) await txn.delete('remittances');
    for (final id in state.removedIds) {
      await txn.delete('remittances', where: 'id = ?', whereArgs: [id]);
    }
    for (final json in state.remittances) {
      await _put(txn, json);
    }
    await _set(txn, _serverTime, state.serverTime);
    if (state.cash != null) await _set(txn, _cash, jsonEncode(state.cash));
    if (state.workflow != null) await _set(txn, _workflow, jsonEncode(state.workflow));
    await _set(txn, _lastSync, DateTime.now().toUtc().toIso8601String());
  });

  /// The remittance as the server returned it after an action.
  Future<void> putRemittance(Map<String, dynamic> json) => _put(_db, json);

  Future<void> removeRemittance(String id) => _db.delete('remittances', where: 'id = ?', whereArgs: [id]);

  static Future<void> _put(DatabaseExecutor db, Map<String, dynamic> json) => db.insert('remittances', {
    'id': json['id'],
    'json': jsonEncode(json),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // Settings

  static const _serverTime = 'serverTime';
  static const _cash = 'cash';
  static const _workflow = 'workflow';
  static const _lastSync = 'lastSync';
  static const _userId = 'userId';

  /// The `since` of the next download.
  Future<String?> serverTime() => _get(_serverTime);

  Future<CourierStatement?> cash() async {
    final raw = await _get(_cash);
    return raw == null ? null : CourierStatement.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<Workflow?> workflow() async {
    final raw = await _get(_workflow);
    return raw == null ? null : Workflow.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// When the last download finished, on this phone's clock.
  Future<DateTime?> lastSync() async {
    final raw = await _get(_lastSync);
    return raw == null ? null : DateTime.parse(raw).toLocal();
  }

  /// Empties the store when another user logs in on this phone. Their queue
  /// is kept only if it is the same user.
  Future<void> useFor(String userId) async {
    if (await _get(_userId) == userId) return;
    await _db.transaction((txn) async {
      await txn.delete('remittances');
      await txn.delete('settings');
      await txn.delete('actions');
      await _set(txn, _userId, userId);
    });
  }

  Future<String?> _get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  static Future<void> _set(DatabaseExecutor db, String key, String value) =>
      db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  // Actions

  Future<void> enqueue(SyncAction action) => _db.insert('actions', {
    'id': action.id,
    // An exchange has no remittance.
    'remittance_id': action.remittanceId ?? '',
    'json': jsonEncode(action.toJson()),
  });

  /// Waiting to be sent, oldest first.
  Future<List<SyncAction>> pending() async => [
    for (final row in await _db.query('actions', where: 'rejected = 0', orderBy: 'seq'))
      SyncAction.fromJson(jsonDecode(row['json']! as String) as Map<String, dynamic>),
  ];

  Future<List<RejectedAction>> rejected() async => [
    for (final row in await _db.query('actions', where: 'rejected = 1', orderBy: 'seq'))
      RejectedAction(
        action: SyncAction.fromJson(jsonDecode(row['json']! as String) as Map<String, dynamic>),
        code: row['code'] as String?,
        message: row['message'] as String?,
      ),
  ];

  /// The server applied it (or had already): it leaves the queue.
  Future<void> done(String actionId) => _db.delete('actions', where: 'id = ?', whereArgs: [actionId]);

  Future<void> reject(String actionId, {String? code, String? message}) =>
      _db.update('actions', {'rejected': 1, 'code': code, 'message': message}, where: 'id = ?', whereArgs: [actionId]);

  /// The courier read why it was rejected and dismisses it.
  Future<void> dismiss(String actionId) => done(actionId);
}
