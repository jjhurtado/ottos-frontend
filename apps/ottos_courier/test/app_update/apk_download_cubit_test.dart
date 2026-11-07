import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app_update/apk_download_cubit.dart';

class _MockInstaller extends Mock implements ApkInstaller {}

/// A file server like the panel's Caddy in front of the bucket, on a raw
/// socket so a connection can drop in the middle of the file: answers `Range`
/// with 206, unless [ranges] is off.
class _Server {
  _Server(this.body);

  final List<int> body;
  bool ranges = true;

  /// Requests that get cut after this many bytes (one drop per entry).
  final drops = <int>[];
  final rangeHeaders = <String?>[];
  final paths = <String>[];
  late final ServerSocket _server;

  Future<String> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_answer);
    return 'http://${_server.address.host}:${_server.port}';
  }

  Future<void> _answer(Socket socket) async {
    final head = StringBuffer();
    final reading = Completer<void>();
    socket.listen((chunk) {
      head.write(String.fromCharCodes(chunk));
      if (head.toString().contains('\r\n\r\n') && !reading.isCompleted) reading.complete();
    });
    await reading.future;
    final lines = head.toString().split('\r\n');
    final path = lines.first.split(' ')[1];
    final range = lines
        .where((line) => line.toLowerCase().startsWith('range:'))
        .map((line) => line.substring(6).trim())
        .firstOrNull;
    rangeHeaders.add(range);
    paths.add(path);
    if (path != '/descargas/ottos-6.apk') {
      socket.write('HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');
      await socket.close();
      return;
    }
    var from = 0;
    var status = '200 OK';
    var extra = '';
    if (range != null && ranges) {
      from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      status = '206 Partial Content';
      extra = 'Content-Range: bytes $from-${body.length - 1}/${body.length}\r\n';
    }
    socket.write('HTTP/1.1 $status\r\nContent-Length: ${body.length - from}\r\n${extra}Connection: close\r\n\r\n');
    if (drops.isNotEmpty) {
      // The connection drops in the middle of the file.
      socket.add(body.sublist(from, from + drops.removeAt(0)));
      await socket.flush();
      socket.destroy();
      return;
    }
    socket.add(body.sublist(from));
    await socket.close();
  }

  Future<void> stop() => _server.close();
}

void main() {
  late Directory folder;
  late _MockInstaller installer;
  late _Server server;
  late String host;
  final body = List<int>.generate(300000, (i) => i % 251);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ottos_update_');
    installer = _MockInstaller();
    when(() => installer.folder()).thenAnswer((_) async => folder.path);
    when(() => installer.canInstall()).thenAnswer((_) async => true);
    when(() => installer.install(any())).thenAnswer((_) async {});
    when(() => installer.openSettings()).thenAnswer((_) async {});
    server = _Server(body);
    host = await server.start();
  });

  tearDown(() async {
    await server.stop();
    await folder.delete(recursive: true);
  });

  AppVersion version([String path = '/descargas/ottos-6.apk']) =>
      AppVersion(latestBuild: 6, latestVersion: '1.0.1', downloadUrl: '$host$path');

  File apk() => File('${folder.path}/ottos-6.apk');

  test('AC-1.1, AC-1.2: downloads with progress, then opens the installer', () async {
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);
    final states = <ApkDownloadState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.start(version());
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.first, const ApkDownloadState(ApkDownloadStatus.downloading));
    expect(states[states.length - 2], const ApkDownloadState(ApkDownloadStatus.downloading, progress: 1));
    expect(states.last, const ApkDownloadState(ApkDownloadStatus.idle));
    expect(apk().readAsBytesSync(), body);
    verify(() => installer.install(apk().path)).called(1);
  });

  test('AC-1.4: a dropped connection fails, and the retry asks only for the rest', () async {
    server.drops.add(100000);
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.start(version());
    expect(cubit.state.status, ApkDownloadStatus.failed);
    expect(File('${apk().path}.part').lengthSync(), 100000);
    verifyNever(() => installer.install(any()));

    await cubit.start(version());
    expect(server.rangeHeaders.last, 'bytes=100000-');
    expect(apk().readAsBytesSync(), body);
    verify(() => installer.install(apk().path)).called(1);
  });

  test('AC-1.4: a server that ignores Range sends the whole file again', () async {
    server
      ..drops.add(100000)
      ..ranges = false;
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.start(version());
    await cubit.start(version());
    expect(apk().readAsBytesSync(), body);
  });

  test('AC-1.4: an error answer from the server fails without installing', () async {
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.start(version('/descargas/otra.apk'));
    expect(cubit.state.status, ApkDownloadStatus.failed);
    expect(folder.listSync(), isEmpty);
    verifyNever(() => installer.install(any()));
  });

  test('AC-1.3: without permission to install it asks for it, and goes on once allowed', () async {
    when(() => installer.canInstall()).thenAnswer((_) async => false);
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.start(version());
    expect(cubit.state.status, ApkDownloadStatus.needsPermission);
    await cubit.openSettings();
    verify(() => installer.openSettings()).called(1);

    // Back from the settings without allowing it: still asking.
    await cubit.continueInstall();
    expect(cubit.state.status, ApkDownloadStatus.needsPermission);

    when(() => installer.canInstall()).thenAnswer((_) async => true);
    await cubit.continueInstall();
    expect(cubit.state.status, ApkDownloadStatus.idle);
    verify(() => installer.install(apk().path)).called(1);
  });

  test('AC-1.5: cancel stops the download and keeps what arrived', () async {
    // A server that sends a little and then waits.
    final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => slow.close(force: true));
    final sent = Completer<void>();
    slow.listen((request) async {
      request.response.contentLength = body.length;
      request.response.add(body.sublist(0, 1000));
      await request.response.flush();
      sent.complete();
    });
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    final running = cubit.start(
      AppVersion(latestBuild: 6, downloadUrl: 'http://${slow.address.host}:${slow.port}/descargas/ottos-6.apk'),
    );
    await sent.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cubit.cancel();
    await running;

    expect(cubit.state.status, ApkDownloadStatus.idle);
    expect(apk().existsSync(), isFalse);
    expect(File('${apk().path}.part').existsSync(), isTrue);
    verifyNever(() => installer.install(any()));
  });

  test('an APK already downloaded opens the installer without downloading again', () async {
    apk().writeAsBytesSync(body);
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.start(version());
    expect(server.rangeHeaders, isEmpty);
    verify(() => installer.install(apk().path)).called(1);
  });

  test('old APKs are deleted once the new build runs', () async {
    for (final name in ['ottos-5.apk', 'ottos-6.apk', 'ottos-6.apk.part', 'ottos-7.apk.part']) {
      File('${folder.path}/$name').writeAsStringSync('x');
    }
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 5);
    addTearDown(cubit.close);

    await cubit.clean(6);
    expect(folder.listSync().map((f) => f.uri.pathSegments.last), ['ottos-7.apk.part']);
  });

  test('AC-1.1: the APK of the phone\'s ABI, from the installed versionCode', () {
    const url = 'https://panel.remesadeotto.com/descargas/ottos-1.0.1.apk';
    expect(apkUrlFor(url, 1015), 'https://panel.remesadeotto.com/descargas/ottos-1.0.1-armeabi-v7a.apk');
    expect(apkUrlFor(url, 2015), 'https://panel.remesadeotto.com/descargas/ottos-1.0.1-arm64-v8a.apk');
    expect(apkUrlFor(url, 4015), 'https://panel.remesadeotto.com/descargas/ottos-1.0.1-x86_64.apk');
    // A universal build, or a code without a known ABI, keeps the link.
    expect(apkUrlFor(url, 15), url);
    expect(apkUrlFor(url, 3015), url);
    expect(apkUrlFor('https://otra/ottos', 2015), 'https://otra/ottos');
  });

  test('AC-1.1: a per-ABI build downloads its own split', () async {
    final cubit = ApkDownloadCubit(installer: installer, versionCode: () async => 2005);
    addTearDown(cubit.close);

    await cubit.start(version('/descargas/ottos-6.apk'));
    // The fake server has only the universal name: the request went to the split.
    expect(cubit.state.status, ApkDownloadStatus.failed);
    expect(server.paths.single, '/descargas/ottos-6-arm64-v8a.apk');
  });
}
