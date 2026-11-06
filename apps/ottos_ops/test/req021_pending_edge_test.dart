import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/router.dart';
import 'package:ottos_ops/features/home/view/home_page.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockAuth extends Mock implements AuthRepository {}

/// A workflow with a third open status, to prove the figure and its list use the same statuses (BR-1, BR-8).
final _workflow = {
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'initial': true, 'position': 10},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
    {'code': 'POSTPONED', 'name': 'Pospuesta', 'position': 25},
    {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
    {'code': 'CANCELLED', 'name': 'Anulada', 'isFinal': true, 'position': 40},
  ],
};

/// REQ-021, tester: edge cases of the panel Home block, through the real RemittanceRepository on a stubbed API.
void main() {
  late _MockApi api;
  late List<Map<String, dynamic>> totalsQueries;
  late Map<String, dynamic> totals;

  setUpAll(() async {
    await OttosLocalization.initialize();
  });

  setUp(() {
    api = _MockApi();
    totalsQueries = [];
    totals = {
      'toDeliver': [
        {'currency': 'CUP', 'remittances': 1234, 'amount': 987654321.99},
        {'currency': 'USD', 'remittances': 3, 'amount': 450.5},
      ],
      'toCollect': [
        {'currency': 'USD', 'remittances': 1, 'amount': 200},
      ],
    };
    when(() => api.get<Map<String, dynamic>>('/remittance-workflow')).thenAnswer((_) async => _workflow);
    when(() => api.get<Map<String, dynamic>>('/remittances/summary')).thenAnswer(
      (_) async => {
        'openByStatus': [
          {'code': 'PAID', 'name': 'Pagada', 'count': 2},
          {'code': 'ASSIGNED', 'name': 'Asignada', 'count': 2},
          {'code': 'POSTPONED', 'name': 'Pospuesta', 'count': 2},
        ],
        'late': 0,
        'incident': 0,
        'review': 0,
      },
    );
    when(() => api.get<Map<String, dynamic>>('/remittances', query: any(named: 'query'))).thenAnswer((call) async {
      final query = call.namedArguments[#query] as Map<String, dynamic>;
      final asksTotals = query['totals'] == true;
      if (asksTotals) totalsQueries.add(query);
      return {'items': <Object>[], 'page': 0, 'size': 1, 'totalItems': 2, 'totals': asksTotals ? totals : null};
    });
  });

  Future<void> pump(WidgetTester tester, {required Size size, double textScale = 1}) async {
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
    await tester.binding.setSurfaceSize(size);
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('BR-8 (three open statuses): the list a tile opens has the statuses the figure was summed with', (
    tester,
  ) async {
    await pump(tester, size: const Size(1440, 1000));

    expect(totalsQueries, hasLength(1));
    expect(totalsQueries.single, containsPair('status', 'PAID,ASSIGNED,POSTPONED'));
    expect(totalsQueries.single, containsPair('voided', false));
    expect(totalsQueries.single, containsPair('size', 1));

    await tester.tap(find.text(CoreTexts.pendingToDeliver));
    await tester.pumpAndSettle();

    final shown = tester.widget<Text>(find.textContaining('list ')).data!;
    final link = Uri.parse(shown.substring('list '.length));
    final opened = filterFromQuery(link.queryParameters);
    expect(opened.status, totalsQueries.single['status']);
    expect(opened.voided, isFalse);
    expect(opened.type, RemittanceType.delivery);
  });

  testWidgets('AC-1.1 (phone width 390, large amounts, text at 200%): the block renders without overflow', (
    tester,
  ) async {
    await pump(tester, size: const Size(390, 1600), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text(Formatters.money(987654321.99, 'CUP')), findsOneWidget);
    expect(find.text('1234 remesas'), findsOneWidget);
    expect(find.text(Formatters.money(450.5, 'USD')), findsOneWidget);
  });

  testWidgets('AC-1.1 (desktop 1440): the Home with the block meets the tap target guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, size: const Size(1440, 1000));

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });

  // The Home's subtitle, older than REQ-021, fails contrast on its own; the tiles are checked alone.
  for (final (name, figures) in [
    ('with figures', const PendingTotals(toDeliver: [PendingAmount(currency: 'USD', remittances: 3, amount: 450)])),
    ('nothing pending', const PendingTotals()),
  ]) {
    testWidgets('AC-1.1 AC-1.5 (contrast, $name): the tiles text meets WCAG AA', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: OttosTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PendingTotalsTiles(totals: figures, onTap: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('AC-1.5 (only pickups pending): deliveries say nothing is pending, pickups show their figure', (
    tester,
  ) async {
    totals = {
      'toDeliver': <Object>[],
      'toCollect': [
        {'currency': 'USD', 'remittances': 1, 'amount': 200},
      ],
    };

    await pump(tester, size: const Size(1440, 1000));

    expect(find.text(CoreTexts.nothingPending), findsOneWidget);
    expect(find.text(Formatters.money(200, 'USD')), findsOneWidget);
  });
}
