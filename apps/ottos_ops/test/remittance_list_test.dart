import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/remittances/view/remittance_list_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

Remittance _remittance(String id, String code) => Remittance(
  id: id,
  code: code,
  type: RemittanceType.delivery,
  status: 'CREATED',
  statusName: 'Creada',
);

void main() {
  late _MockRemittances remittances;
  late List<Remittance> stored;

  setUpAll(() {
    OttosLocalization.initialize();
    registerFallbackValue(const RemittanceFilter());
  });

  setUp(() {
    remittances = _MockRemittances();
    stored = [_remittance('r1', 'OT-OLD1')];
    when(() => remittances.workflow()).thenAnswer((_) async => const Workflow(statuses: [], transitions: []));
    when(() => remittances.search(any(), page: any(named: 'page'), size: any(named: 'size'))).thenAnswer(
      (_) async => PageResult(items: List.of(stored), page: 0, size: 20, totalItems: stored.length),
    );
  });

  Future<GoRouter> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'u@ottos.test',
            name: 'U',
            type: '',
            roles: const [],
            permissions: const {Permissions.remittancesCreate},
          ),
        ),
      );
    addTearDown(authBloc.close);
    // Same shape as the app: the form and the detail are children of the
    // list, so the list stays mounted underneath them.
    final router = GoRouter(
      initialLocation: '/remittances',
      routes: [
        GoRoute(
          path: '/remittances',
          builder: (_, _) => const Scaffold(body: RemittanceListPage()),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => const Scaffold(body: Text('form'))),
            GoRoute(path: ':id', builder: (_, state) => Scaffold(body: Text('detail ${state.pathParameters['id']}'))),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: remittances,
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a remittance registered from the form shows up when going back to the list', (tester) async {
    final router = await pump(tester);
    expect(find.text('OT-OLD1'), findsOneWidget);

    router.go('/remittances/new');
    await tester.pumpAndSettle();
    // The form registers it and opens its detail, as the real page does.
    stored = [_remittance('r2', 'OT-NEW2'), ...stored];
    router.go('/remittances/r2');
    await tester.pumpAndSettle();
    expect(find.text('detail r2'), findsOneWidget);

    router.go('/remittances');
    await tester.pumpAndSettle();

    expect(find.text('OT-NEW2'), findsOneWidget);
    expect(find.text('OT-OLD1'), findsOneWidget);
  });

  testWidgets('a change made in the detail shows up when going back to the list', (tester) async {
    final router = await pump(tester);

    router.go('/remittances/r1');
    await tester.pumpAndSettle();
    stored = [
      const Remittance(id: 'r1', code: 'OT-OLD1', type: RemittanceType.delivery, status: 'VOIDED', statusName: 'Anulada'),
    ];
    router.go('/remittances');
    await tester.pumpAndSettle();

    verify(() => remittances.search(any(), page: 0, size: 20)).called(2);
  });

  testWidgets('the list loads once when it opens', (tester) async {
    await pump(tester);

    verify(() => remittances.search(any(), page: 0, size: 20)).called(1);
  });
}
