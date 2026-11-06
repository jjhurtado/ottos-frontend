// REQ-022 batch 2, OPT-F4 (tester): the panel Home after the summary call.
// Every HTTP call the Home makes is recorded at the ApiClient, so the counts
// include the workflow, the exchanges and the money pending.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/destinations.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockAuth extends Mock implements AuthRepository {}

const _summary = {
  'openByStatus': [
    {'code': 'PAID', 'name': 'Pagada', 'count': 12},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'count': 0},
  ],
  'late': 6,
  'incident': 2,
  'review': 1,
};

void main() {
  late _MockApi api;
  late List<String> calls;
  late Object? summaryFailure;
  late Map<String, dynamic>? totalsQuery;

  setUpAll(() async {
    await OttosLocalization.initialize();
  });

  setUp(() {
    api = _MockApi();
    calls = [];
    summaryFailure = null;
    totalsQuery = null;
    when(() => api.get<Map<String, dynamic>>(any(), query: any(named: 'query'))).thenAnswer((call) async {
      final path = call.positionalArguments.first as String;
      final query = call.namedArguments[#query] as Map<String, dynamic>?;
      calls.add(path == '/remittances' ? '$path ${query?['totals'] == true ? 'totals' : 'list'}' : path);
      if (path == '/remittances' && query?['totals'] == true) totalsQuery = query;
      if (path == '/remittances/summary' && summaryFailure != null) throw summaryFailure!;
      return switch (path) {
        '/remittances/summary' => _summary,
        '/remittance-workflow' => {
          'statuses': [
            {'code': 'PAID', 'name': 'Pagada', 'position': 10},
            {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
            {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
          ],
        },
        '/cash/exchanges' => {'items': <Object>[], 'page': 0, 'size': 1, 'totalItems': 4},
        _ => {
          'items': <Object>[],
          'page': 0,
          'size': 1,
          'totalItems': 0,
          'totals': {'toDeliver': <Object>[], 'toCollect': <Object>[]},
        },
      };
    });
  });

  Future<GoRouter> pump(WidgetTester tester, {required bool cashRead}) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'admin@ottos.test',
            name: 'Administración',
            type: '',
            roles: const [],
            permissions: {Permissions.remittancesRead, if (cashRead) Permissions.cashRead},
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
        GoRoute(
          path: '/cash',
          builder: (_, state) => Scaffold(body: Text('cash ${state.uri}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: RemittanceRepository(api: api)),
          RepositoryProvider<CashRepository>.value(value: CashRepository(api: api)),
        ],
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

  Future<String> tapAndRead(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    return tester.widget<Text>(find.textContaining(RegExp('^(list|cash) '))).data!;
  }

  group('OPT-F4 (calls)', () {
    testWidgets('with cash:read: summary, exchanges and money pending; the workflow once per session', (tester) async {
      final router = await pump(tester, cashRead: true);

      expect(calls.where((c) => c != '/remittance-workflow').toList()..sort(), [
        '/cash/exchanges',
        '/remittances totals',
        '/remittances/summary',
      ]);
      expect(calls.where((c) => c == '/remittance-workflow'), hasLength(1));
      expect(calls.where((c) => c == '/remittances list'), isEmpty, reason: 'no list per tile');

      // Coming back to Home in the same session: 3 calls, no workflow.
      calls.clear();
      router.go('/cash');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(calls..sort(), ['/cash/exchanges', '/remittances totals', '/remittances/summary']);
    });

    testWidgets('without cash:read: summary and money pending only', (tester) async {
      final router = await pump(tester, cashRead: false);

      expect(calls.where((c) => c != '/remittance-workflow').toList()..sort(), [
        '/remittances totals',
        '/remittances/summary',
      ]);
      expect(find.text(OpsTexts.exchangesToReview), findsNothing);

      calls.clear();
      router.go('/cash');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(calls..sort(), ['/remittances totals', '/remittances/summary']);
    });
  });

  group('OPT-F4 (tiles)', () {
    testWidgets('every tile, its number and its order, with cash:read', (tester) async {
      await pump(tester, cashRead: true);

      final labels = [
        'Pagada',
        'Asignada',
        OpsTexts.lateRemittances,
        OpsTexts.incidentRemittances,
        OpsTexts.reviewRemittances,
        OpsTexts.exchangesToReview,
      ];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final number in ['12', '0', '6', '2', '1', '4']) {
        expect(find.text(number), findsOneWidget, reason: number);
      }
      // Tiles flow left to right, then down (Wrap): reading order equals the list above
      final positions = [for (final label in labels) tester.getTopLeft(find.text(label))];
      for (var i = 1; i < positions.length; i++) {
        final before = positions[i - 1];
        final after = positions[i];
        expect(after.dy > before.dy || (after.dy == before.dy && after.dx > before.dx), isTrue, reason: labels[i]);
      }
    });

    final links = <(String, String)>[
      ('Pagada', 'list /remittances?status=PAID&voided=false'),
      ('Asignada', 'list /remittances?status=ASSIGNED&voided=false'),
      (OpsTexts.lateRemittances, 'list /remittances?late=true'),
      (OpsTexts.incidentRemittances, 'list /remittances?incident=true'),
      (OpsTexts.reviewRemittances, 'list /remittances?review=true'),
      (OpsTexts.exchangesToReview, 'cash ${Destinations.cash.path}'),
    ];
    for (final (label, target) in links) {
      testWidgets('the «$label» tile opens $target, as at rc.12', (tester) async {
        await pump(tester, cashRead: true);

        expect(await tapAndRead(tester, label), target);
      });
    }
  });

  testWidgets('CR-7: a money tile opens the same open filter the totals were asked with', (tester) async {
    await pump(tester, cashRead: true);
    final asked = totalsQuery!;

    final shown = Uri.parse((await tapAndRead(tester, CoreTexts.pendingToDeliver)).substring('list '.length));

    expect(shown.queryParameters['status'], asked['status']);
    expect(shown.queryParameters['status'], 'PAID,ASSIGNED');
    expect(shown.queryParameters['voided'], '${asked['voided']}');
    expect(shown.queryParameters['type'], RemittanceType.delivery.code);
  });

  group('OPT-F4 (error)', () {
    testWidgets('a failed summary shows the error with «Reintentar», and retrying loads the tiles', (tester) async {
      summaryFailure = const ApiException('No se pudo cargar', statusCode: 500);
      await pump(tester, cashRead: true);

      expect(find.text('No se pudo cargar'), findsOneWidget);
      expect(find.text(CoreTexts.retry), findsOneWidget);
      expect(find.text(OpsTexts.lateRemittances), findsNothing);

      summaryFailure = null;
      await tester.tap(find.text(CoreTexts.retry));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.retry), findsNothing);
      expect(find.text(OpsTexts.lateRemittances), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('against a backend without the endpoint (404) the Home shows «Reintentar», no crash', (tester) async {
      summaryFailure = const ApiException('Recurso no encontrado', statusCode: 404, code: 'NOT_FOUND');
      await pump(tester, cashRead: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Recurso no encontrado'), findsOneWidget);
      expect(find.text(CoreTexts.retry), findsOneWidget);
    });
  });
}
