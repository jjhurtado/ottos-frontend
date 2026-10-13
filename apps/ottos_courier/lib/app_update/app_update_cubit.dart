import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ottos_core/ottos_core.dart';

/// What the backend says about this build, and whether the user closed the
/// "new version" notice.
class AppUpdateState {
  const AppUpdateState({this.version, this.dismissed = false});

  final AppVersion? version;
  final bool dismissed;
}

/// Keeps track of the published versions: asks on start and on coming back
/// to the app, remembers the last answer for when there is no network, and
/// hears the backend refuse this build (426).
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit({
    required this._repository,
    required this._app,
    required Stream<AppVersion> refused,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       super(const AppUpdateState()) {
    _refused = refused.listen((version) => emit(AppUpdateState(version: version)));
  }

  final AppVersionRepository _repository;
  final AppIdentity _app;
  final FlutterSecureStorage _storage;
  late final StreamSubscription<AppVersion> _refused;

  static const _cacheKey = 'ottos.app.version';

  AppUpdate get update => state.version?.updateFor(_app.build) ?? AppUpdate.none;

  Future<void> check() async {
    try {
      final version = await _repository.current(_app.platform);
      await _storage.write(key: _cacheKey, value: jsonEncode(version.toJson()));
      if (!isClosed) emit(AppUpdateState(version: version, dismissed: state.dismissed));
    } on ApiException {
      // No network: the last answer still says whether this build is too old.
      if (state.version != null) return;
      final cached = await _storage.read(key: _cacheKey);
      if (cached == null || isClosed) return;
      emit(AppUpdateState(version: AppVersion.fromJson(jsonDecode(cached) as Map<String, dynamic>)));
    }
  }

  /// Closes the "new version" notice until the app starts again.
  void dismiss() => emit(AppUpdateState(version: state.version, dismissed: true));

  @override
  Future<void> close() async {
    await _refused.cancel();
    return super.close();
  }
}
