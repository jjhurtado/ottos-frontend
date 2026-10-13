import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app_update/app_update_cubit.dart';
import 'package:ottos_courier/app_update/update_gate.dart';

class _MockVersions extends Mock implements AppVersionRepository {}

const _app = AppIdentity(platform: 'ANDROID', build: 4);

void main() {
  late _MockVersions versions;
  late StreamController<AppVersion> refused;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    versions = _MockVersions();
    refused = StreamController<AppVersion>.broadcast();
  });

  tearDown(() => refused.close());

  Future<AppUpdateCubit> pump(WidgetTester tester) async {
    final cubit = AppUpdateCubit(repository: versions, app: _app, refused: refused.stream);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
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
    expect(find.text(CoreTexts.noDownloadLink), findsOneWidget, reason: 'no link configured yet');
    expect(find.text(CoreTexts.later), findsNothing);
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
}
