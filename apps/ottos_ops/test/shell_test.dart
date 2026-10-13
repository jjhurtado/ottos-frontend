import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/shell/ops_shell.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _admin = CurrentUser(id: 'a1', email: 'admin@ottos.test', name: 'Admin', type: '', roles: [], permissions: {});

void main() {
  testWidgets('the user menu ends with the running version', (tester) async {
    final authRepository = _MockAuthRepository();
    when(() => authRepository.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: authRepository, accessPolicy: (_) => true)
      ..add(const AuthLoggedIn(_admin));
    addTearDown(authBloc.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepositoryProvider.value(
        value: const AppConfig(apiUrl: '', version: '1.0.0-rc.3'),
        child: BlocProvider.value(
          value: authBloc,
          child: const MaterialApp(
            home: OpsShell(location: '/', child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Admin'));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.logout), findsOneWidget);
    expect(find.text(OpsTexts.version('1.0.0-rc.3')), findsOneWidget);
  });
}
