import 'package:flutter/foundation.dart';

/// Runtime configuration, set at build time with `--dart-define`.
///
/// `OTTOS_API_URL` is the backend origin, without `/api/v1`. Defaults point
/// to the local backend:
/// - web: same origin; the dev server proxies `/api` (see `web_dev_config.yaml`);
/// - Android emulator: `10.0.2.2` is the host machine;
/// - iOS simulator and desktop: `localhost`.
class AppConfig {
  const AppConfig({required this.apiUrl, this.client = AppClient.web, this.app});

  factory AppConfig.fromEnvironment({AppClient client = AppClient.web, AppIdentity? app}) {
    const fromDefine = String.fromEnvironment('OTTOS_API_URL');
    if (fromDefine.isNotEmpty) return AppConfig(apiUrl: fromDefine, client: client, app: app);
    if (kIsWeb) return AppConfig(apiUrl: '', client: client, app: app);
    return AppConfig(
      apiUrl: defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8080' : 'http://localhost:8080',
      client: client,
      app: app,
    );
  }

  final String apiUrl;

  /// The installed mobile app, sent on every request so the backend can
  /// refuse a build that is too old. Null in the panel.
  final AppIdentity? app;

  /// Sent on login: a mobile session lasts the whole working day.
  final AppClient client;

  String get apiBaseUrl => '$apiUrl/api/v1';
}

/// Which app opens a session (`client` on login).
enum AppClient {
  /// The panel: short sessions (15 min, refreshed).
  web('WEB'),

  /// The mobile app: a session lasts the working day (14 h), to sync at night.
  mobile('MOBILE');

  const AppClient(this.code);

  final String code;
}

/// Which mobile app and build is talking to the backend.
class AppIdentity {
  const AppIdentity({required this.platform, required this.build});

  /// `ANDROID` or `IOS`.
  final String platform;

  /// versionCode on Android, CFBundleVersion on iOS.
  final int build;
}
