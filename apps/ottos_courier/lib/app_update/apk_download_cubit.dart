import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

/// The Android side, answered by `MainActivity.kt` on `ottos/update`.
class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('ottos/update');

  /// A folder in the app's cache that the installer can read (FileProvider).
  Future<String> folder() async => (await _channel.invokeMethod<String>('folder'))!;

  /// Whether this app may install apps (Android 8+ asks once per app).
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// The system setting that allows this app to install apps.
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  /// Opens the Android installer with the downloaded APK.
  Future<void> install(String path) => _channel.invokeMethod<void>('install', path);
}

/// Release APKs are split per ABI (`--split-per-abi`), and Flutter gives each
/// split the versionCode `1000 × ABI + build`.
const _abis = {1: 'armeabi-v7a', 2: 'arm64-v8a', 4: 'x86_64'};

/// The APK for the phone's ABI: `ottos-1.0.1.apk` becomes `ottos-1.0.1-arm64-v8a.apk`
/// when the installed [versionCode] is `2000 + build`. A universal build (below
/// 1000) keeps the backend's link.
@visibleForTesting
String apkUrlFor(String url, int versionCode) {
  final abi = _abis[versionCode ~/ 1000];
  if (abi == null || !url.endsWith('.apk')) return url;
  return '${url.substring(0, url.length - '.apk'.length)}-$abi.apk';
}

Future<int> _installedVersionCode() async => int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

enum ApkDownloadStatus { idle, downloading, failed, needsPermission }

class ApkDownloadState extends Equatable {
  const ApkDownloadState(this.status, {this.progress});

  final ApkDownloadStatus status;

  /// From 0 to 1 in steps of 1 %; null while the size is not known.
  final double? progress;

  @override
  List<Object?> get props => [status, progress];
}

/// Downloads the new APK into the app's cache and opens the Android installer
/// (REQ-023). The connection in Cuba is slow: a failed download keeps what
/// arrived and the retry asks only for the rest (`Range`) when the server
/// allows it.
class ApkDownloadCubit extends Cubit<ApkDownloadState> {
  ApkDownloadCubit({
    this._installer = const ApkInstaller(),
    HttpClient Function()? http,
    this._versionCode = _installedVersionCode,
    this._httpsOnly = kReleaseMode,
  }) : _http = http ?? HttpClient.new,
       super(const ApkDownloadState(ApkDownloadStatus.idle));

  final ApkInstaller _installer;
  final HttpClient Function() _http;

  /// The installed versionCode, which carries the phone's ABI.
  final Future<int> Function() _versionCode;

  /// Release builds download only over HTTPS (SEC-2); tests use a local http server.
  final bool _httpsOnly;

  /// A stall this long with nothing received counts as a failed download.
  static const _stall = Duration(seconds: 60);

  HttpClient? _client;
  String? _apk;

  /// The last run; a new one waits for it so two never write the same file.
  Future<void>? _busy;

  /// Raised by [cancel]: whatever was running stops without changing the state.
  int _run = 0;

  static String _fileName(int build) => 'ottos-$build.apk';

  /// Downloads [version] if it is not already here, then installs it.
  Future<void> start(AppVersion version) async {
    final url = version.downloadUrl;
    if (url == null || state.status == ApkDownloadStatus.downloading) return;
    final run = ++_run;
    emit(const ApkDownloadState(ApkDownloadStatus.downloading));
    final previous = _busy;
    final done = Completer<void>();
    _busy = done.future;
    try {
      await previous;
      final apk = File(p.join(await _installer.folder(), _fileName(version.latestBuild)));
      if (!apk.existsSync()) await _download(Uri.parse(apkUrlFor(url, await _versionCode())), apk, run);
      if (run != _run || isClosed) return;
      _apk = apk.path;
      await _install();
    } on PlatformException catch (error) {
      await _forgetRejected(error);
      if (run == _run && !isClosed) emit(const ApkDownloadState(ApkDownloadStatus.failed));
    } on Exception {
      if (run == _run && !isClosed) emit(const ApkDownloadState(ApkDownloadStatus.failed));
    } finally {
      done.complete();
    }
  }

  Future<void> _download(Uri url, File apk, int run) async {
    if (_httpsOnly && url.scheme != 'https') throw HttpException('Not HTTPS', uri: url);
    final part = File('${apk.path}.part');
    final have = part.existsSync() ? part.lengthSync() : 0;
    // Cancelled while getting ready (CR-1): no request at all.
    if (run != _run) throw const HttpException('Cancelled');
    final client = _client = _http()..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(url);
      // A redirect counts as a failed download (SEC-2): the file comes only from the link.
      request.followRedirects = false;
      if (have > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      final response = await request.close();
      final resumed = have > 0 && response.statusCode == HttpStatus.partialContent;
      if (!resumed && response.statusCode != HttpStatus.ok) {
        // 416: what is here does not fit the file on the server; start over next time.
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) await part.delete();
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      final start = resumed ? have : 0;
      final total = response.contentLength < 0 ? null : start + response.contentLength;
      var received = start;
      final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      try {
        await for (final chunk in response.timeout(_stall)) {
          if (run != _run) throw const HttpException('Cancelled');
          sink.add(chunk);
          received += chunk.length;
          if (total != null && run == _run && !isClosed) {
            emit(ApkDownloadState(ApkDownloadStatus.downloading, progress: (received * 100 ~/ total) / 100));
          }
        }
      } finally {
        await sink.close();
      }
      if (total != null && received != total) throw HttpException('Incomplete download', uri: url);
      await part.rename(apk.path);
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  Future<void> _install() async {
    if (!await _installer.canInstall()) {
      if (!isClosed) emit(const ApkDownloadState(ApkDownloadStatus.needsPermission));
      return;
    }
    await _installer.install(_apk!);
    // If the user backs out of the installer, «Actualizar» opens it again without downloading.
    if (!isClosed) emit(const ApkDownloadState(ApkDownloadStatus.idle));
  }

  /// The Android side refuses an APK that is not a newer build of this app signed
  /// with its key (SEC-1); that file is deleted, so the retry downloads it again (DEF-1).
  Future<void> _forgetRejected(PlatformException error) async {
    final apk = _apk;
    if (error.code != 'rejected' || apk == null) return;
    _apk = null;
    try {
      await File(apk).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Stops the download; what arrived stays for the next try.
  void cancel() {
    _run++;
    _client?.close(force: true);
    emit(const ApkDownloadState(ApkDownloadStatus.idle));
  }

  Future<void> openSettings() async {
    try {
      await _installer.openSettings();
    } on PlatformException {
      if (!isClosed) emit(const ApkDownloadState(ApkDownloadStatus.failed));
    }
  }

  /// Back in the app after the settings: the installation goes on if it is now allowed.
  Future<void> continueInstall() async {
    if (state.status != ApkDownloadStatus.needsPermission || _apk == null) return;
    try {
      await _install();
    } on PlatformException catch (error) {
      await _forgetRejected(error);
      if (!isClosed) emit(const ApkDownloadState(ApkDownloadStatus.failed));
    } on Exception {
      if (!isClosed) emit(const ApkDownloadState(ApkDownloadStatus.failed));
    }
  }

  /// Deletes the APKs of builds up to [installed]: they are already on the phone.
  Future<void> clean(int installed) async {
    try {
      final folder = Directory(await _installer.folder());
      await for (final file in folder.list()) {
        final build = RegExp(r'^ottos-(\d+)\.apk(\.part)?$').firstMatch(p.basename(file.path))?.group(1);
        if (build == null || int.parse(build) <= installed) await file.delete();
      }
    } on Exception {
      // Best effort: the cache is the system's to clear anyway.
    }
  }

  @override
  Future<void> close() {
    _run++;
    _client?.close(force: true);
    return super.close();
  }
}
