import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/remittances/view/remittance_list_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

Remittance _remittance(String id, String code) =>
    Remittance(id: id, code: code, type: RemittanceType.delivery, status: 'CREATED', statusName: 'Creada');

void main() {
  late _MockRemittances remittances;
  late GoRouter router;
  final searches = <(RemittanceFilter, int)>[];
  late PageResult<Remittance> Function(RemittanceFilter filter, int page) answer;

  setUpAll(() {
    OttosLocalization.initialize();
    registerFallbackValue(const RemittanceFilter());
  });

  setUp(() {
    searches.clear();
    remittances = _MockRemittances();
    answer = (filter, page) => PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    when(() => remittances.workflow()).thenAnswer((_) async => const Workflow(statuses: [], transitions: []));
    when(
      () => remittances.search(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((call) async {
      final filter = call.positionalArguments.first as RemittanceFilter;
      final page = call.namedArguments[#page] as int;
      searches.add((filter, page));
      return answer(filter, page);
    });
  });

  Future<void> pump(WidgetTester tester) async {
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
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: RemittanceListPage()),
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
    searches.clear();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<void> typeAndWait(WidgetTester tester, String text) async {
    await type(tester, text);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('the «Código» search is gone; only the beneficiary field is there', (tester) async {
    await pump(tester);

    expect(find.text(OpsTexts.searchByBeneficiary), findsOneWidget);
    expect(find.text('Buscar por código'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AC-1.1: sends the text trimmed, as typed, after 400 ms without typing', (tester) async {
    await pump(tester);

    await type(tester, '  José ');
    await tester.pump(const Duration(milliseconds: 399));
    expect(searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(searches, hasLength(1));
    expect(searches.single.$1.toQuery()['beneficiary'], 'José');
    expect(searches.single.$2, 0);
  });

  testWidgets('typing again restarts the wait: only the last text is sent', (tester) async {
    await pump(tester);

    await type(tester, 'jo');
    await tester.pump(const Duration(milliseconds: 300));
    await type(tester, 'jose');
    await tester.pump(const Duration(milliseconds: 300));
    expect(searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(searches.map((s) => s.$1.beneficiaryQuery), ['jose']);
  });

  testWidgets('below 2 letters or 4 digits nothing is sent and the hint shows', (tester) async {
    await pump(tester);

    for (final text in ['j', '123', '1 2 3', '--']) {
      await typeAndWait(tester, text);
      expect(find.text(OpsTexts.searchTooShort), findsOneWidget, reason: text);
    }
    expect(searches, isEmpty);

    for (final text in ['jo', '1234']) {
      await typeAndWait(tester, text);
      expect(find.text(OpsTexts.searchTooShort), findsNothing, reason: text);
    }
    expect(searches.map((s) => s.$1.beneficiaryQuery), ['jo', '1234']);
  });

  testWidgets('AC-1.3: the search is combined with the other filters, and they keep it', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose');
    searches.clear();

    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pumpAndSettle();

    expect(searches.single.$1.late, isTrue);
    expect(searches.single.$1.beneficiaryQuery, 'jose');
  });

  testWidgets('a new search goes back to page 1', (tester) async {
    answer = (filter, page) =>
        PageResult(items: [_remittance('r$page', 'OT-$page')], page: page, size: 1, totalItems: 3);
    await pump(tester);
    await tester.tap(find.byTooltip(OpsTexts.nextPage));
    await tester.pumpAndSettle();
    expect(searches.last.$2, 1);

    await typeAndWait(tester, 'jose');

    expect(searches.last.$2, 0);
    expect(searches.last.$1.beneficiaryQuery, 'jose');
  });

  testWidgets('clearing the text removes the search', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose');

    await typeAndWait(tester, '');

    expect(searches.last.$1.beneficiaryQuery, isNull);
  });

  testWidgets('«Quitar filtros» also empties the field', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose');

    await tester.tap(find.text(OpsTexts.clearFilters));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(searches.last.$1.beneficiaryQuery, isNull);
  });

  testWidgets('AC-1.4: no results says so; without a search the filters text stays', (tester) async {
    answer = (filter, page) => PageResult(items: const [], page: 0, size: 20, totalItems: 0);
    await pump(tester);
    expect(find.text(OpsTexts.noRemittances), findsOneWidget);

    await typeAndWait(tester, 'zzz');

    expect(find.text('No hay remesas con esa búsqueda.'), findsOneWidget);
  });

  testWidgets('AC-1.5: drops repeats across pages, shows the server total, page 1 stays whole', (tester) async {
    answer = (filter, page) => switch (page) {
      0 => PageResult(items: [_remittance('a', 'OT-A'), _remittance('b', 'OT-B')], page: 0, size: 2, totalItems: 4),
      _ => PageResult(items: [_remittance('b', 'OT-B'), _remittance('c', 'OT-C')], page: 1, size: 2, totalItems: 4),
    };
    await pump(tester);
    await typeAndWait(tester, 'jose');
    expect(find.text('OT-B'), findsOneWidget);

    await tester.tap(find.byTooltip(OpsTexts.nextPage));
    await tester.pumpAndSettle();

    expect(find.text('OT-B'), findsNothing);
    expect(find.text('OT-C'), findsOneWidget);
    expect(find.textContaining('de 4'), findsOneWidget);

    await tester.tap(find.byTooltip(OpsTexts.previousPage));
    await tester.pumpAndSettle();

    expect(find.text('OT-A'), findsOneWidget);
    expect(find.text('OT-B'), findsOneWidget);
  });

  testWidgets('the search text never goes into the panel URL', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose martinez');

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.toString(), isNot(contains('jose')));
    expect(uri.toString(), isNot(contains('beneficiary')));
    expect(uri.queryParameters, isEmpty);
  });
}
