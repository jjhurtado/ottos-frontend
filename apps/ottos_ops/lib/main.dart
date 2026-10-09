import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OttosLocalization.initialize();
  runApp(OpsApp(config: AppConfig.fromEnvironment()));
}
