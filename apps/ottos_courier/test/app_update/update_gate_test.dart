import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app_update/apk_download_cubit.dart';
import 'package:ottos_courier/app_update/app_update_cubit.dart';
import 'package:ottos_courier/app_update/update_gate.dart';

class _MockVersions extends Mock implements AppVersionRepository {}

class _MockDownload extends MockCubit<ApkDownloadState> implements ApkDownloadCubit {}

const _app = AppIdentity(platform: 'ANDROID', build: 4);

void main() {
  late _MockVersions versions;
  late StreamController<AppVersion> refused;
  late _MockDownload download;

  setUpAll(() => registerFallbackValue(const AppVersion()));

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    versions = _MockVersions();
    refused = StreamController<AppVersion>.broadcast();
    download = _MockDownload();
    when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.idle));
    when(() => download.clean(any())).thenAnswer((_) async {});
    when(() => download.continueInstall()).thenAnswer((_) async {});
    when(() => download.start(any())).thenAnswer((_) async {});
    when(() => download.openSettings()).thenAnswer((_) async {});
  });

  tearDown(() => refused.close());

  Future<AppUpdateCubit> pump(WidgetTester tester) async {
    final cubit = AppUpdateCubit(repository: versions, app: _app, refused: refused.stream);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider<ApkDownloadCubit>.value(value: download),
          ],
          child: const UpdateGate(child: Scaffold(body: Text('la app'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('a newer version shows a notice that can be closed', (tester) async {
    when(() => versions.current('ANDROID')).thenAnswer(
      (_) async => const AppVersion(latestBuild: 5, latestVersion: '1.0.1', downloadUrl: 'https://descargas/ottos.apk'),
    );
    await pump(tester);

    expect(find.text(CoreTexts.updateAvailable), findsOneWidget);
    expect(find.text('la app'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, CoreTexts.update), findsOneWidget);
    await tester.tap(find.text(CoreTexts.later));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.updateAvailable), findsNothing);
  });

  testWidgets('a refused build gets the screen that cannot be closed', (tester) async {
    when(() => versions.current('ANDROID')).thenAnswer((_) async => const AppVersion());
    await pump(tester);
    expect(find.text(CoreTexts.updateRequiredTitle), findsNothing);

    refused.add(const AppVersion(minimumBuild: 5, latestBuild: 5, latestVersion: '1.0.1'));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.updateRequiredTitle), findsOneWidget);
    // No link configured yet: the button still opens the store.
    expect(find.widgetWithText(FilledButton, CoreTexts.update), findsOneWidget);
    expect(find.text(CoreTexts.later), findsNothing);
  });

  testWidgets('a 426 body without notes shows the screen without them', (tester) async {
    when(() => versions.current('ANDROID')).thenAnswer((_) async => const AppVersion());
    await pump(tester);

    refused.add(
      AppVersion.fromJson(const {'status': 426, 'code': 'APP_UPDATE_REQUIRED', 'minimumBuild': 5, 'latestBuild': 5}),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(CoreTexts.updateRequiredTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, CoreTexts.update), findsOneWidget);
  });

  testWidgets('without network it keeps to the last answer', (tester) async {
    when(() => versions.current('ANDROID')).thenAnswer((_) async => const AppVersion(minimumBuild: 5, latestBuild: 5));
    await pump(tester);
    expect(find.text(CoreTexts.updateRequiredTitle), findsOneWidget);

    when(() => versions.current('ANDROID')).thenThrow(const ApiException(CoreTexts.networkError));
    final again = AppUpdateCubit(repository: versions, app: _app, refused: refused.stream);
    addTearDown(again.close);
    await again.check();
    expect(again.update, AppUpdate.required);
  });

  test('without a link from the backend, update opens the store', () {
    const none = AppVersion(minimumBuild: 5, latestBuild: 5);
    expect(
      updateUrl(none, platform: TargetPlatform.android),
      'https://play.google.com/store/apps/details?id=com.remesadeotto.ottos',
    );
    expect(updateUrl(none, platform: TargetPlatform.iOS), 'itms-beta://');
    expect(
      updateUrl(const AppVersion(downloadUrl: 'https://otra/ottos'), platform: TargetPlatform.android),
      'https://otra/ottos',
    );
  });

  group('REQ-023: Android downloads the update in the app', () {
    const optional = AppVersion(
      latestBuild: 5,
      latestVersion: '1.0.1',
      downloadUrl: 'https://panel/descargas/ottos-1.0.1.apk',
    );
    const mandatory = AppVersion(
      minimumBuild: 5,
      latestBuild: 5,
      latestVersion: '1.0.1',
      downloadUrl: 'https://panel/descargas/ottos-1.0.1.apk',
    );

    testWidgets('AC-1.1: «Actualizar» starts the download in the app, and old APKs are cleaned on start', (
      tester,
    ) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => optional);
      await pump(tester);
      verify(() => download.clean(4)).called(1);

      await tester.tap(find.widgetWithText(FilledButton, CoreTexts.update));
      verify(() => download.start(optional)).called(1);
    });

    testWidgets('AC-1.1, AC-1.5: the notice shows the progress, and «Cancelar» stops it and closes the notice', (
      tester,
    ) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => optional);
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.downloading, progress: 0.45));
      await pump(tester);

      expect(find.text(CoreTexts.downloadingUpdate(0.45)), findsOneWidget);
      expect(find.text('Descargando… 45 %'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.45);
      expect(find.text(CoreTexts.update), findsNothing);

      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();
      verify(() => download.cancel()).called(1);
      expect(find.text(CoreTexts.updateAvailable), findsNothing);
      expect(find.text('la app'), findsOneWidget);
    });

    testWidgets('AC-1.5: on SCR-18 the download cannot be cancelled', (tester) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => mandatory);
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.downloading, progress: 0.1));
      await pump(tester);

      expect(find.text(CoreTexts.updateRequiredTitle), findsOneWidget);
      expect(find.text('Descargando… 10 %'), findsOneWidget);
      expect(find.text(CoreTexts.cancel), findsNothing);
    });

    testWidgets('AC-1.4: a failed download offers «Reintentar»', (tester) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => mandatory);
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.failed));
      await pump(tester);

      expect(find.text(CoreTexts.updateDownloadFailed), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, CoreTexts.retry));
      verify(() => download.start(mandatory)).called(1);
    });

    testWidgets('AC-1.3: without permission it explains why and opens the setting; coming back goes on', (
      tester,
    ) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => optional);
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.needsPermission));
      await pump(tester);

      expect(find.text(CoreTexts.installPermission), findsOneWidget);
      expect(find.text(CoreTexts.later), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, CoreTexts.openSettings));
      verify(() => download.openSettings()).called(1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      verify(() => download.continueInstall()).called(1);
    });

    testWidgets('AC-1.6: on iOS «Actualizar» does not download in the app', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      when(() => versions.current('ANDROID')).thenAnswer((_) async => mandatory);
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.downloading));
      await pump(tester);

      expect(find.widgetWithText(FilledButton, CoreTexts.update), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      verifyNever(() => download.clean(any()));
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('AC-1.6: without a link «Actualizar» does not download in the app', (tester) async {
      when(() => versions.current('ANDROID'))
          .thenAnswer((_) async => const AppVersion(minimumBuild: 5, latestBuild: 5));
      when(() => download.state).thenReturn(const ApkDownloadState(ApkDownloadStatus.downloading));
      await pump(tester);

      expect(find.widgetWithText(FilledButton, CoreTexts.update), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
