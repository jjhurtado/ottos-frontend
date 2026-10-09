import 'package:flutter/foundation.dart';

/// Runtime configuration, set at build time with `--dart-define`.
///
/// `OTTOS_API_URL` is the backend origin, without `/api/v1`. Defaults point
/// to the local backend:
/// - web: same origin; the dev server proxies `/api` (see `web_dev_config.yaml`);
/// - Android emulator: `10.0.2.2` is the host machine;
/// - iOS simulator and desktop: `localhost`.
class AppConfig {
  const AppConfig({required this.apiUrl});

  factory AppConfig.fromEnvironment() {
    const fromDefine = String.fromEnvironment('OTTOS_API_URL');
    if (fromDefine.isNotEmpty) return const AppConfig(apiUrl: fromDefine);
    if (kIsWeb) return const AppConfig(apiUrl: '');
    return AppConfig(
      apiUrl: defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8080' : 'http://localhost:8080',
    );
  }

  final String apiUrl;

  String get apiBaseUrl => '$apiUrl/api/v1';
}
