import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The iOS side (`AppDelegate.swift`) answers with a folder in
/// `Library/Application Support` marked `NSURLIsExcludedFromBackupKey`.
const _channel = MethodChannel('ottos/storage');

/// Where the offline database lives. On iOS it stays out of iCloud and computer
/// backups (SEC-2): sqflite's default folder is `Documents`, which is backed up,
/// so a database already there is moved. Android keeps sqflite's folder; the
/// manifest excludes it from backups.
Future<String> offlineDatabasePath(DatabaseFactory factory, String fileName) async {
  final legacy = p.join(await factory.getDatabasesPath(), fileName);
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return legacy;
  final String? folder;
  try {
    folder = await _channel.invokeMethod<String>('offlineDirectory');
  } on PlatformException catch (error) {
    debugPrint('Offline database: no backup-excluded folder (${error.code}); using the default one');
    return legacy;
  } on MissingPluginException {
    debugPrint('Offline database: no backup-excluded folder; using the default one');
    return legacy;
  }
  if (folder == null) return legacy;
  final path = p.join(folder, fileName);
  if (File(path).existsSync() || !File(legacy).existsSync()) return path;
  // Best effort: a failed move never stops the app from starting.
  return _move(legacy, path);
}

/// Moves the database with its journal, if one was left: actions not sent yet
/// must not be lost. On failure, what was moved goes back and the old path stays.
Future<String> _move(String from, String to) async {
  const suffixes = ['', '-journal', '-wal', '-shm'];
  final moved = <String>[];
  try {
    for (final suffix in suffixes) {
      final file = File('$from$suffix');
      if (!file.existsSync()) continue;
      await file.rename('$to$suffix');
      moved.add(suffix);
    }
    return to;
  } on FileSystemException catch (error) {
    debugPrint('Offline database: move failed (${error.osError?.errorCode}); keeping the default folder');
    for (final suffix in moved) {
      try {
        await File('$to$suffix').rename('$from$suffix');
      } on FileSystemException {
        // Nothing else to do: the next start tries again.
      }
    }
    return from;
  }
}
