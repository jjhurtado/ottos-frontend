import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import 'app/app.dart';
import 'notifications/notifier.dart';
import 'offline/offline_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OttosLocalization.initialize();
  final store = await OfflineStore.open();
  final notifier = await _notifier();
  runApp(
    CourierApp(
      config: AppConfig.fromEnvironment(client: AppClient.mobile),
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
