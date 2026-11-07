// REQ-023 acceptance and edge-case tests of SCR-18 and the new-version notice, written by the
// tester. Expected results come from 01-user-stories.md (AC-1.1..AC-1.5) and 02-design.md.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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

void main() {
  group('REQ-023 QA · SCR-18 and the new-version notice', () {
    late _MockVersions versions;
    late StreamController<AppVersion> refused;
    late _MockDownload download;
    const app = AppIdentity(platform: 'ANDROID', build: 4);
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

    setUpAll(() => registerFallbackValue(const AppVersion()));

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      versions = _MockVersions();
      refused = StreamController<AppVersion>.broadcast();
      download = _MockDownload();
      when(() => download.clean(any())).thenAnswer((_) async {});
      when(() => download.continueInstall()).thenAnswer((_) async {});
      when(() => download.start(any())).thenAnswer((_) async {});
      when(() => download.openSettings()).thenAnswer((_) async {});
    });

    tearDown(() => refused.close());

    Future<void> pump(WidgetTester tester, AppVersion version, ApkDownloadState state, {double textScale = 1}) async {
      when(() => versions.current('ANDROID')).thenAnswer((_) async => version);
      when(() => download.state).thenReturn(state);
      final cubit = AppUpdateCubit(repository: versions, app: app, refused: refused.stream);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: OttosTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider<ApkDownloadCubit>.value(value: download),
            ],
            child: const UpdateGate(child: Scaffold(body: Text('la app'))),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    void onPhone(WidgetTester tester, Size size) {
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    const states = {
      'idle': ApkDownloadState(ApkDownloadStatus.idle),
      'downloading': ApkDownloadState(ApkDownloadStatus.downloading, progress: 0.45),
      'downloading, size unknown': ApkDownloadState(ApkDownloadStatus.downloading),
      'failed': ApkDownloadState(ApkDownloadStatus.failed),
      'needs permission': ApkDownloadState(ApkDownloadStatus.needsPermission),
    };

    testWidgets('AC-1.1 (size unknown): the notice shows «Descargando…» and a moving bar', (tester) async {
      await pump(tester, optional, const ApkDownloadState(ApkDownloadStatus.downloading));

      expect(find.text('Descargando…'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);
      expect(find.text(CoreTexts.cancel), findsOneWidget);
    });

    testWidgets('AC-1.5: while downloading, the notice has «Cancelar» instead of «Más tarde» and «Actualizar»', (
      tester,
    ) async {
      await pump(tester, optional, const ApkDownloadState(ApkDownloadStatus.downloading, progress: 0.2));

      expect(find.text(CoreTexts.cancel), findsOneWidget);
      expect(find.text(CoreTexts.later), findsNothing);
      expect(find.text(CoreTexts.update), findsNothing);
      expect(find.text('la app'), findsOneWidget);
    });

    testWidgets('AC-1.3 on SCR-18: explains the permission and opens the setting, with no way to close it', (
      tester,
    ) async {
      await pump(tester, mandatory, const ApkDownloadState(ApkDownloadStatus.needsPermission));

      expect(find.text(CoreTexts.updateRequiredTitle), findsOneWidget);
      expect(find.text('Para actualizar, permite que Ottos instale apps'), findsOneWidget);
      expect(find.text(CoreTexts.later), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Abrir ajustes'));
      verify(() => download.openSettings()).called(1);
    });

    testWidgets('AC-1.4: the failure on the notice keeps «Más tarde» and retries the same version', (tester) async {
      await pump(tester, optional, const ApkDownloadState(ApkDownloadStatus.failed));

      expect(find.text('No se pudo descargar la actualización'), findsOneWidget);
      expect(find.text(CoreTexts.later), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
      verify(() => download.start(optional)).called(1);
    });

    // Phones in logical pixels and the system text sizes they can have.
    const phones = {
      'medium phone 412×915, text 200 %': (Size(412, 915), 2.0),
      'medium phone 412×915, text 130 %': (Size(412, 915), 1.3),
      'small phone 360×640, text 130 %': (Size(360, 640), 1.3),
    };

    for (final entry in states.entries) {
      for (final screen in {'notice': optional, 'SCR-18': mandatory}.entries) {
        for (final phone in phones.entries) {
          // DEF-2 (04-test-report.md): SCR-18 overflows with the new message in these states;
          // remove the skip with the fix.
          final def2 =
              screen.key == 'SCR-18' &&
              (entry.key == 'failed' || entry.key == 'needs permission') &&
              phone.key != 'medium phone 412×915, text 130 %';
          testWidgets('AC-1.1..AC-1.4 (${screen.key}, ${entry.key}, ${phone.key}): nothing is cut', (tester) async {
            onPhone(tester, phone.value.$1);
            await pump(tester, screen.value, entry.value, textScale: phone.value.$2);

            expect(tester.takeException(), isNull);
          }, skip: def2);
        }

        testWidgets('AC-1.1..AC-1.4 (${screen.key}, ${entry.key}): accessibility guidelines', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, screen.value, entry.value);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  });
}
