import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/app/router.dart';
import 'package:ottos_ops/features/home/cubit/home_cubit.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

final _summaryJson = {
  'openByStatus': [
    {'code': 'PAID', 'name': 'Pagada', 'count': 7},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'count': 0},
  ],
  'late': 3,
  'incident': 4,
  'review': 5,
};

/// REQ-022 batch 2 (OPT-F4): the Home counters come from one `GET /remittances/summary`.
void main() {
  late _MockApi api;
  late List<String> calls;

  setUpAll(() async {
    await OttosLocalization.initialize();
  });

  setUp(() {
    api = _MockApi();
    calls = [];
    when(() => api.get<Map<String, dynamic>>(any(), query: any(named: 'query'))).thenAnswer((call) async {
      final path = call.positionalArguments.first as String;
      final query = call.namedArguments[#query] as Map<String, dynamic>?;
      calls.add(query == null ? path : '$path ${query['totals'] == true ? 'totals' : 'list'}');
      return switch (path) {
        '/remittances/summary' => _summaryJson,
        '/remittance-workflow' => {
          'statuses': [
            {'code': 'PAID', 'name': 'Pagada', 'position': 10},
            {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
            {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
          ],
        },
        _ => {'items': <Object>[], 'page': 0, 'size': 1, 'totalItems': 0, 'totals': <String, Object>{}},
      };
    });
  });

  Future<void> pump(WidgetTester tester) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        const AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'ventas@ottos.test',
            name: 'Ventas',
            type: '',
            roles: [],
            permissions: {Permissions.remittancesRead},
          ),
        ),
      );
    addTearDown(authBloc.close);
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomePage()),
        ),
        GoRoute(
          path: '/remittances',
          builder: (_, state) => Scaffold(body: Text('list ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: RemittanceRepository(api: api),
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
  }

  Future<RemittanceFilter> tapAndRead(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    final shown = tester.widget<Text>(find.textContaining('list ')).data!;
    return filterFromQuery(Uri.parse(shown.substring('list '.length)).queryParameters);
  }

  testWidgets('OPT-F4: one summary call for every counter, no list asked per tile', (tester) async {
    await pump(tester);

    expect(calls.where((call) => call == '/remittances/summary'), hasLength(1));
    expect(calls.where((call) => call == '/remittances list'), isEmpty);
    // The money pending keeps its own call (REQ-021 AC-1.8).
    expect(calls.where((call) => call == '/remittances totals'), hasLength(1));
  });

  testWidgets('OPT-F4: the tiles show the summary, a status with 0 included, in its order', (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Pagada'), findsOneWidget);
    expect(find.text('Asignada'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pagada')).dx, lessThan(tester.getTopLeft(find.text('Asignada')).dx));
  });

  for (final (label, expected) in [
    ('Pagada', const RemittanceFilter(status: 'PAID', voided: false)),
    (OpsTexts.lateRemittances, const RemittanceFilter(late: true)),
    (OpsTexts.incidentRemittances, const RemittanceFilter(incident: true)),
    (OpsTexts.reviewRemittances, const RemittanceFilter(review: true)),
  ]) {
    testWidgets('OPT-F4: the «$label» tile opens the same list as before', (tester) async {
      await pump(tester);

      expect(await tapAndRead(tester, label), expected);
    });
  }

  testWidgets('OPT-F4 BR-8 (REQ-021): a money tile opens the open statuses of the summary', (tester) async {
    await pump(tester);

    expect(
      await tapAndRead(tester, CoreTexts.pendingToDeliver),
      const RemittanceFilter(status: 'PAID,ASSIGNED', voided: false, type: RemittanceType.delivery),
    );
  });

  test('OPT-F4: a failed summary fails the Home, as a failed counter did', () async {
    final remittances = _MockRemittances();
    when(() => remittances.summary()).thenAnswer((_) async => throw const ApiException('Sin conexión'));
    when(() => remittances.pendingTotals()).thenAnswer((_) async => const PendingTotals());
    final cubit = HomeCubit(remittances: remittances);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, HomeStatus.failure);
    expect(cubit.state.error, 'Sin conexión');
  });
}
