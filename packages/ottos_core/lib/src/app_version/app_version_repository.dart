import '../api/api_client.dart';
import '../models/app_version.dart';

/// The published versions of the mobile app. Public: it works before login.
class AppVersionRepository {
  AppVersionRepository({required this._api});

  final ApiClient _api;

  /// [platform] is `ANDROID` or `IOS`.
  Future<AppVersion> current(String platform) async =>
      AppVersion.fromJson(await _api.get<Map<String, dynamic>>('/app/version', query: {'platform': platform}));
}
