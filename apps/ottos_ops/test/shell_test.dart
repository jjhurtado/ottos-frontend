import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/business_time/business_time_cubit.dart';
import 'package:ottos_ops/shell/ops_shell.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockRates extends Mock implements RateRepository {}

const _admin = CurrentUser(id: 'a1', email: 'admin@ottos.test', name: 'Admin', type: '', roles: [], permissions: {});

void main() {
  late _MockRates rates;

  setUp(() {
    rates = _MockRates();
    when(() => rates.businessTime()).thenAnswer((_) async => null);
  });

  Widget shell(AuthBloc authBloc, String location) => RepositoryProvider.value(
    value: const AppConfig(apiUrl: '', version: '1.0.0-rc.3'),
    child: BlocProvider.value(
      value: authBloc,
      child: BlocProvider(
        create: (_) => BusinessTimeCubit(rates: rates),
        child: MaterialApp(
          home: OpsShell(location: location, child: const SizedBox()),
        ),
      ),
    ),
  );

  testWidgets('the user menu ends with the running version', (tester) async {
    final authRepository = _MockAuthRepository();
    when(() => authRepository.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: authRepository, accessPolicy: (_) => true)
      ..add(const AuthLoggedIn(_admin));
    addTearDown(authBloc.close);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(shell(authBloc, '/'));
    await tester.pump();
    await tester.tap(find.byTooltip('Admin'));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.logout), findsOneWidget);
    expect(find.text(OpsTexts.version('1.0.0-rc.3')), findsOneWidget);
  });

  testWidgets('AC-2.3: the business time zone is asked at start, on another section and when the tab comes back', (
    tester,
  ) async {
    final authRepository = _MockAuthRepository();
    when(() => authRepository.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: authRepository, accessPolicy: (_) => true)
      ..add(const AuthLoggedIn(_admin));
    addTearDown(authBloc.close);
    final cubit = BusinessTimeCubit(rates: rates);
    addTearDown(cubit.close);
    Widget page(String location) => RepositoryProvider.value(
      value: const AppConfig(apiUrl: ''),
      child: BlocProvider.value(
        value: authBloc,
        child: BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: OpsShell(location: location, child: const SizedBox()),
          ),
        ),
      ),
    );

    await tester.pumpWidget(page('/'));
    await tester.pump();
    verify(() => rates.businessTime()).called(1);

    await tester.pumpWidget(page('/remittances'));
    await tester.pump();
    verify(() => rates.businessTime()).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(() => rates.businessTime()).called(1);
  });
}
