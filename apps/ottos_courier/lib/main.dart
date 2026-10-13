import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ottos_core/ottos_core.dart';

import 'app/app.dart';
import 'notifications/notifier.dart';
import 'offline/offline_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OttosLocalization.initialize();
  final store = await OfflineStore.open();
  final info = await PackageInfo.fromPlatform();
  final notifier = await _notifier();
  runApp(
    CourierApp(
      config: AppConfig.fromEnvironment(
        client: AppClient.mobile,
        app: AppIdentity(platform: Platform.isIOS ? 'IOS' : 'ANDROID', build: _build(info.buildNumber)),
        version: '${info.version} (${_build(info.buildNumber)})',
      ),
      store: store,
      notifier: notifier,
    ),
  );
}

/// Notifications are a help, not a requirement: if the system refuses them
/// the app still opens, without them.
Future<LocalNotifier?> _notifier() async {
  try {
    return await LocalNotifier.create();
  } catch (error) {
    debugPrint('Notifications unavailable: $error');
    return null;
  }
}

/// The pubspec build number. APKs split per ABI report `abi * 1000 + build`.
int _build(String buildNumber) {
  final code = int.tryParse(buildNumber) ?? 0;
  return Platform.isAndroid ? code % 1000 : code;
}
