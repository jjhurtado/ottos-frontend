import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:sqflite/sqflite.dart';

import 'offline_location.dart';

/// An action that the server rejected; kept so the courier sees why.
class RejectedAction {
  const RejectedAction({required this.action, this.code, this.message});

  final SyncAction action;
  final String? code;
  final String? message;
}

/// What the courier needs to work without network, in SQLite on the phone:
/// the assigned remittances as the server sent them, the latest ones they
/// completed, the cash, the workflow, and the queue of actions waiting to be
/// sent.
class OfflineStore {
  OfflineStore._(this._db, this._now);

  final Database _db;
  final DateTime Function() _now;

  /// 2: the `completed` table (REQ-017).
  static const _version = 2;

  /// How many completed remittances the phone keeps (REQ-017 BR-1).
  static const maxCompleted = 20;

  /// How old a completed remittance may get on the phone: older ones are
  /// deleted when the app opens, when the list is read and when the phone syncs
  /// (REQ-017 BR-1).
  static const maxCompletedAge = Duration(days: 7);
  static const _fileName = 'ottos_offline.db';

  /// Opens the store of the app ([path] for tests, e.g. `inMemoryDatabasePath`).
  static Future<OfflineStore> open({String? path, DatabaseFactory? factory, DateTime Function()? now}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? await offlineDatabasePath(dbFactory, _fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: (db, _) => _create(db),
        // Empty until the next download fills it.
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createCompleted(db);
        },
      ),
    );
    final store = OfflineStore._(db, now ?? DateTime.now);
    // Before and independent of any sign-in: a phone whose session expired must
    // not keep completed ones past 7 days (REQ-017 SEC-33). Only `completed`
    // is touched. A failure here must never stop the app from opening.
    try {
      await db.transaction(store._expireCompleted);
    } on DatabaseException catch (error) {
      // Reads and syncs prune again. One line, no data: only the kind of error.
      debugPrint('Offline database: could not prune old completed ones (${error.runtimeType})');
    }
    return store;
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
    await _createCompleted(db);
  }

  /// The courier's latest completed remittances, as the server sent them;
  /// completed_at orders them, newest first.
  static Future<void> _createCompleted(DatabaseExecutor db) =>
      db.execute('CREATE TABLE completed (id TEXT PRIMARY KEY, completed_at TEXT NOT NULL, json TEXT NOT NULL)');

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
  /// updates [remittances] and drops [removedIds]. The completed list, when it
  /// comes, always replaces the copy whole.
  Future<void> applyState(SyncState state) => _db.transaction((txn) async {
    if (state.full) await txn.delete('remittances');
    for (final id in state.removedIds) {
      await txn.delete('remittances', where: 'id = ?', whereArgs: [id]);
    }
    for (final json in state.remittances) {
      await _put(txn, json);
    }
    if (state.completed case final completed?) {
      await txn.delete('completed');
      for (final json in completed) {
        await _putCompleted(txn, json);
      }
      await _trimCompleted(txn);
    }
    await _expireCompleted(txn);
    await _set(txn, _serverTime, state.serverTime);
    if (state.cash != null) await _set(txn, _cash, jsonEncode(state.cash));
    if (state.workflow != null) await _set(txn, _workflow, jsonEncode(state.workflow));
    if (state.businessTime != null) await _set(txn, _businessTime, jsonEncode(state.businessTime!.toJson()));
    await _set(txn, _lastSync, _now().toUtc().toIso8601String());
  });

  /// The remittance as the server returned it after an action.
  Future<void> putRemittance(Map<String, dynamic> json) => _put(_db, json);

  static Future<void> _put(DatabaseExecutor db, Map<String, dynamic> json) => db.insert('remittances', {
    'id': json['id'],
    'json': jsonEncode(json),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // Completed remittances (REQ-017)

  /// The latest completed ones, newest first; at most [maxCompleted].
  Future<List<Map<String, dynamic>>> completed() => _db.transaction((txn) async {
    await _expireCompleted(txn);
    return [
      for (final row in await txn.query('completed', orderBy: 'completed_at DESC, id', limit: maxCompleted))
        jsonDecode(row['json']! as String) as Map<String, dynamic>,
    ];
  });

  Future<Map<String, dynamic>?> completedRemittance(String id) => _db.transaction((txn) async {
    await _expireCompleted(txn);
    final rows = await txn.query('completed', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : jsonDecode(rows.single['json']! as String) as Map<String, dynamic>;
  });

  /// One just completed, as the server returned it, until the next download
  /// brings the whole list; the oldest beyond [maxCompleted] leave (BR-1).
  Future<void> putCompleted(Map<String, dynamic> json) => _db.transaction((txn) async {
    await _putCompleted(txn, json);
    await _trimCompleted(txn);
    await _expireCompleted(txn);
  });

  /// A remittance that was just completed leaves the open ones and, unless it is
  /// [voided], joins the completed ones, in one transaction: if the app dies in
  /// between, it is still in one of the two tables (REQ-017 CR-1).
  Future<void> completeRemittance(Map<String, dynamic> json, {required bool voided}) => _db.transaction((txn) async {
    await txn.delete('remittances', where: 'id = ?', whereArgs: [json['id']]);
    if (voided) return;
    await _putCompleted(txn, json);
    await _trimCompleted(txn);
    await _expireCompleted(txn);
  });

  /// Deletes the stored completed ones older than [maxCompletedAge]; one with
  /// no known completed_at counts as old. Unsent completions are not rows here.
  Future<void> _expireCompleted(DatabaseExecutor db) => db.delete(
    'completed',
    where: "completed_at = '' OR completed_at < ?",
    whereArgs: [_isoMillis(_now().subtract(maxCompletedAge))],
  );

  /// UTC ISO 8601 to the millisecond, so text order is time order.
  static String _isoMillis(DateTime at) =>
      DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch, isUtc: true).toIso8601String();

  /// Keeps only the [maxCompleted] most recent.
  static Future<void> _trimCompleted(DatabaseExecutor db) => db.rawDelete(
    'DELETE FROM completed WHERE id NOT IN (SELECT id FROM completed ORDER BY completed_at DESC, id LIMIT ?)',
    [maxCompleted],
  );

  /// completed_at in UTC ISO 8601, so text order is time order.
  static Future<void> _putCompleted(DatabaseExecutor db, Map<String, dynamic> json) => db.insert('completed', {
    'id': json['id'],
    'completed_at': switch (json['completedAt']) {
      final String at when DateTime.tryParse(at) != null => _isoMillis(DateTime.parse(at)),
      _ => '',
    },
    'json': jsonEncode(json),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  // Settings

  static const _serverTime = 'serverTime';
  static const _cash = 'cash';
  static const _workflow = 'workflow';
  static const _lastSync = 'lastSync';
  static const _userId = 'userId';
  static const _businessTime = 'businessTime';
  static const _clockOffset = 'server_clock_offset_ms';
  static const _clockOffsetSampledAt = 'server_clock_offset_sampled_at';

  /// The last business time zone the server sent (REQ-006, AC-2.4).
  Future<BusinessTimeZone?> businessTime() async {
    final raw = await _get(_businessTime);
    return raw == null ? null : BusinessTimeZone.fromJson(jsonDecode(raw));
  }

  /// Server minus phone clock at the last answer, for a start without network (AC-3.2).
  Future<Duration?> clockOffset() async {
    final raw = await _get(_clockOffset);
    final ms = raw == null ? null : int.tryParse(raw);
    return ms == null ? null : Duration(milliseconds: ms);
  }

  /// When [clockOffset] was measured, on the phone's clock (UTC).
  Future<DateTime?> clockOffsetSampledAt() async {
    final raw = await _get(_clockOffsetSampledAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveClockOffset(Duration offset, DateTime sampledAt) => _db.transaction((txn) async {
    await _set(txn, _clockOffset, '${offset.inMilliseconds}');
    await _set(txn, _clockOffsetSampledAt, sampledAt.toUtc().toIso8601String());
  });

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
    // An instant (UTC): shown in the business time zone, not the phone's (CR-3).
    return raw == null ? null : DateTime.parse(raw);
  }

  /// Empties the store when another user logs in on this phone. Their queue
  /// is kept only if it is the same user.
  Future<void> useFor(String userId) async {
    if (await _get(_userId) == userId) return;
    await _db.transaction((txn) async {
      await txn.delete('remittances');
      await txn.delete('completed');
      await txn.delete('settings');
      await txn.delete('actions');
      await _set(txn, _userId, userId);
    });
  }

  /// On an explicit logout (SEC-2): the remittances, the completed ones
  /// (REQ-017 BR-4), the cash, the settings and the rejected actions leave the
  /// phone. Only the actions not sent yet stay,
  /// with whose they are, so they go out when the same user logs in again;
  /// another user's login empties them too ([useFor]).
  Future<void> clearForLogout() => _db.transaction((txn) async {
    await txn.delete('remittances');
    await txn.delete('completed');
    await txn.delete('settings', where: 'key != ?', whereArgs: [_userId]);
    await txn.delete('actions', where: 'rejected = 1');
  });

  /// A value of this user's that is not part of the sync, e.g. where the
  /// completed remittances feed goes. Forgotten when another user logs in.
  Future<String?> setting(String key) => _get('app.$key');

  Future<void> saveSetting(String key, String value) => _set(_db, 'app.$key', value);

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
