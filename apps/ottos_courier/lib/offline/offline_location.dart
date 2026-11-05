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
  } on PlatformException {
    return legacy;
  } on MissingPluginException {
    return legacy;
  }
  if (folder == null) return legacy;
  final path = p.join(folder, fileName);
  if (!File(path).existsSync() && File(legacy).existsSync()) {
    // With its journal, if one was left: actions not sent yet must not be lost.
    for (final suffix in const ['', '-journal', '-wal', '-shm']) {
      final file = File('$legacy$suffix');
      if (file.existsSync()) await file.rename('$path$suffix');
    }
  }
  return path;
}
