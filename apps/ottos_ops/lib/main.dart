import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OttosLocalization.initialize();
  // On the web this reads version.json, published with each build.
  final info = await PackageInfo.fromPlatform();
  runApp(OpsApp(config: AppConfig.fromEnvironment(version: info.version)));
}
