import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import 'app/app.dart';
import 'notifications/notifier.dart';
import 'offline/offline_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OttosLocalization.initialize();
  final store = await OfflineStore.open();
  final notifier = await LocalNotifier.create();
  runApp(
    CourierApp(
      config: AppConfig.fromEnvironment(client: AppClient.mobile),
      store: store,
      notifier: notifier,
    ),
  );
}
