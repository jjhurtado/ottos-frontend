// REQ-023 acceptance and edge-case tests of the download, written by the tester. Expected results
// come from 01-user-stories.md (AC-1.1..AC-1.5, BR-2, BR-3) and 02-design.md. Plain tests (no
// testWidgets): the widget binding would replace the real HttpClient the local file server needs.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app_update/apk_download_cubit.dart';

class _MockInstaller extends Mock implements ApkInstaller {}

/// A file server for the APK. Records each request's headers; answers `Range`
/// with 206, or 416 when the range starts past the end of the file.
class _ApkServer {
  _ApkServer(this.body);

  final List<int> body;

  /// Without a Content-Length (chunked), so the size is not known.
  bool chunked = false;
  final requests = <HttpHeaders>[];
  late final HttpServer _server;

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      requests.add(request.headers);
      final response = request.response;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      var from = 0;
      if (range != null) {
        from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        if (from >= body.length) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await response.close();
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $from-${body.length - 1}/${body.length}');
      }
      if (!chunked) response.contentLength = body.length - from;
      // In a few pieces, so the progress moves.
      for (var at = from; at < body.length; at += 50000) {
        response.add(body.sublist(at, at + 50000 > body.length ? body.length : at + 50000));
        await response.flush();
      }
      await response.close();
    });
    return 'http://${_server.address.host}:${_server.port}';
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  group('REQ-023 · ApkDownloadCubit edge cases', () {
    late Directory folder;
    late _MockInstaller installer;
    late _ApkServer server;
    late String host;
    final body = List<int>.generate(300000, (i) => (i * 7) % 256);

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('ottos_req023_qa_');
      installer = _MockInstaller();
      when(() => installer.folder()).thenAnswer((_) async => folder.path);
      when(() => installer.canInstall()).thenAnswer((_) async => true);
      when(() => installer.install(any())).thenAnswer((_) async {});
      when(() => installer.openSettings()).thenAnswer((_) async {});
      server = _ApkServer(body);
      host = await server.start();
    });

    tearDown(() async {
      await server.stop();
      await folder.delete(recursive: true);
    });

    AppVersion version() =>
        AppVersion(latestBuild: 6, latestVersion: '1.0.1', downloadUrl: '$host/descargas/ottos-1.0.1.apk');
    File apk() => File('${folder.path}/ottos-6.apk');
    File part() => File('${apk().path}.part');
    ApkDownloadCubit cubit() {
      final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
      addTearDown(cubit.close);
      return cubit;
    }

    test('AC-1.1 (no session on the file server): the download sends no Authorization or Cookie', () async {
      await cubit().start(version());

      expect(server.requests, hasLength(1));
      expect(server.requests.single.value(HttpHeaders.authorizationHeader), isNull);
      expect(server.requests.single.value(HttpHeaders.cookieHeader), isNull);
      expect(apk().readAsBytesSync(), body);
    });

    test('AC-1.1 (double tap): a second «Actualizar» while downloading does not start a second download', () async {
      final download = cubit();

      final first = download.start(version());
      final second = download.start(version());
      await Future.wait([first, second]);

      expect(server.requests, hasLength(1));
      verify(() => installer.install(apk().path)).called(1);
    });

    test('AC-1.1 (no link): without a downloadUrl nothing is downloaded', () async {
      final download = cubit();

      await download.start(const AppVersion(latestBuild: 6, latestVersion: '1.0.1'));

      expect(download.state, const ApkDownloadState(ApkDownloadStatus.idle));
      expect(server.requests, isEmpty);
    });

    test('AC-1.1 (progress): the percentage only grows, from 0 to 100 %', () async {
      final download = cubit();
      final progress = <double>[];
      final sub = download.stream.listen((s) {
        if (s.progress != null) progress.add(s.progress!);
      });

      await download.start(version());
      await sub.cancel();

      expect(progress, isNotEmpty);
      expect(progress.last, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
    });

    test('AC-1.1 (size unknown): without Content-Length it downloads without a percentage and installs', () async {
      server.chunked = true;
      final download = cubit();
      final states = <ApkDownloadState>[];
      final sub = download.stream.listen(states.add);

      await download.start(version());
      await sub.cancel();

      expect(states.where((s) => s.status == ApkDownloadStatus.downloading).map((s) => s.progress).toSet(), {null});
      expect(apk().readAsBytesSync(), body);
      verify(() => installer.install(apk().path)).called(1);
    });

    test('AC-1.4 (retry shows the progress already made): a resumed download starts its % where it stopped', () async {
      part().writeAsBytesSync(body.sublist(0, 150000));
      final download = cubit();
      final progress = <double>[];
      final sub = download.stream.listen((s) {
        if (s.progress != null) progress.add(s.progress!);
      });

      await download.start(version());
      await sub.cancel();

      expect(server.requests.single.value(HttpHeaders.rangeHeader), 'bytes=150000-');
      expect(progress.first, greaterThanOrEqualTo(0.5));
      expect(apk().readAsBytesSync(), body);
    });

    test('AC-1.4 (after a restart): a new app run resumes the partial file left by the previous one', () async {
      part().writeAsBytesSync(body.sublist(0, 120000));

      // A new cubit is what a restarted app has.
      await cubit().start(version());

      expect(server.requests.single.value(HttpHeaders.rangeHeader), 'bytes=120000-');
      expect(apk().readAsBytesSync(), body);
      expect(part().existsSync(), isFalse);
    });

    test('AC-1.4 (partial does not fit the file on the server, 416): fails, and the retry starts over', () async {
      // A partial file longer than the APK on the server (another upload under the same build).
      part().writeAsBytesSync(List<int>.filled(body.length + 10, 1));
      final download = cubit();

      await download.start(version());
      expect(download.state.status, ApkDownloadStatus.failed);
      expect(part().existsSync(), isFalse);
      verifyNever(() => installer.install(any()));

      await download.start(version());
      expect(server.requests.last.value(HttpHeaders.rangeHeader), isNull);
      expect(apk().readAsBytesSync(), body);
      verify(() => installer.install(apk().path)).called(1);
    });

    test('AC-1.4 (server unreachable): a refused connection fails with «Reintentar» and keeps nothing', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final download = cubit();

      await download.start(AppVersion(latestBuild: 6, downloadUrl: 'http://127.0.0.1:$port/descargas/ottos-1.0.1.apk'));

      expect(download.state.status, ApkDownloadStatus.failed);
      expect(apk().existsSync(), isFalse);
      verifyNever(() => installer.install(any()));
    });

    test('AC-1.5 (cancel, then «Actualizar» again): the next try asks only for the rest', () async {
      // A server that sends part of the file and then waits, like a slow line.
      final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => slow.close(force: true));
      final sent = Completer<void>();
      final ranges = <String?>[];
      slow.listen((request) async {
        ranges.add(request.headers.value(HttpHeaders.rangeHeader));
        final response = request.response;
        if (ranges.length == 1) {
          response.contentLength = body.length;
          response.add(body.sublist(0, 40000));
          await response.flush();
          sent.complete();
          return; // never finishes
        }
        final from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(ranges.last!)!.group(1)!);
        response
          ..statusCode = HttpStatus.partialContent
          ..contentLength = body.length - from
          ..add(body.sublist(from));
        await response.close();
      });
      final at = AppVersion(latestBuild: 6, downloadUrl: 'http://127.0.0.1:${slow.port}/descargas/ottos-1.0.1.apk');
      final download = cubit();

      final running = download.start(at);
      await sent.future;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      download.cancel();
      await running;
      expect(download.state.status, ApkDownloadStatus.idle);
      final kept = part().lengthSync();
      expect(kept, greaterThan(0));

      await download.start(at);
      expect(ranges.last, 'bytes=$kept-');
      expect(apk().readAsBytesSync(), body);
      verify(() => installer.install(apk().path)).called(1);
    });

    test('AC-1.2 (installer cannot open): shows the error, and the retry opens it again without downloading', () async {
      var calls = 0;
      when(() => installer.install(any())).thenAnswer((_) async {
        if (calls++ == 0) throw PlatformException(code: 'update', message: 'ActivityNotFoundException');
      });
      final download = cubit();

      await download.start(version());
      expect(download.state.status, ApkDownloadStatus.failed);
      expect(apk().readAsBytesSync(), body);

      await download.start(version());
      expect(server.requests, hasLength(1));
      expect(download.state.status, ApkDownloadStatus.idle);
      verify(() => installer.install(apk().path)).called(2);
    });

    test('AC-1.3 (the setting cannot open): shows the error with «Reintentar»', () async {
      when(() => installer.canInstall()).thenAnswer((_) async => false);
      when(() => installer.openSettings()).thenThrow(PlatformException(code: 'update'));
      final download = cubit();

      await download.start(version());
      expect(download.state.status, ApkDownloadStatus.needsPermission);
      await download.openSettings();
      expect(download.state.status, ApkDownloadStatus.failed);
    });

    test('AC-1.3 (coming back with nothing pending): resuming the app does nothing', () async {
      final download = cubit();

      await download.continueInstall();

      expect(download.state, const ApkDownloadState(ApkDownloadStatus.idle));
      verifyNever(() => installer.canInstall());
      verifyNever(() => installer.install(any()));
    });
  });
}
