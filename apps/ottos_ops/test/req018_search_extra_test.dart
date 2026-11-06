import 'dart:async';

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

  testWidgets('AC-1.2: a phone of 4 or more digits is sent as typed', (tester) async {
    await pump(tester);

    await typeAndWait(tester, '5123 4567');

    expect(searches.single.$1.toQuery()['beneficiary'], '5123 4567');
  });

  testWidgets('AC-1.6: accents and capitals are sent as typed (matching is the backend\'s)', (tester) async {
    await pump(tester);

    await typeAndWait(tester, 'JOSÉ Martínez');
    await typeAndWait(tester, 'jose martinez');
    await typeAndWait(tester, 'Peña');

    expect(searches.map((s) => s.$1.beneficiaryQuery), ['JOSÉ Martínez', 'jose martinez', 'Peña']);
  });

  testWidgets('AC-1.1 (every status): the search sets no status or voided filter', (tester) async {
    await pump(tester);

    await typeAndWait(tester, 'jose');

    final query = searches.single.$1.toQuery();
    expect(query['beneficiary'], 'jose');
    expect(query['status'], isNull);
    expect(query['voided'], isNull);
  });

  testWidgets('AC-1.3 (filter after search): changing another filter goes back to page 1', (tester) async {
    answer = (filter, page) =>
        PageResult(items: [_remittance('r$page', 'OT-$page')], page: page, size: 1, totalItems: 3);
    await pump(tester);
    await typeAndWait(tester, 'jose');
    await tester.tap(find.byTooltip(OpsTexts.nextPage));
    await tester.pumpAndSettle();
    expect(searches.last.$2, 1);

    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pumpAndSettle();

    expect(searches.last.$2, 0);
    expect(searches.last.$1.late, isTrue);
    expect(searches.last.$1.beneficiaryQuery, 'jose');
  });

  testWidgets('AC-1.3 (clear text): other filters stay when the text is cleared', (tester) async {
    await pump(tester);
    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pumpAndSettle();
    await typeAndWait(tester, 'jose');

    await typeAndWait(tester, '');

    expect(searches.last.$1.beneficiaryQuery, isNull);
    expect(searches.last.$1.late, isTrue);
  });

  testWidgets('AC-1.4 (filters only): no search text shows the usual empty text, not the search one', (tester) async {
    answer = (filter, page) => PageResult(items: const [], page: 0, size: 20, totalItems: 0);
    await pump(tester);
    await typeAndWait(tester, 'zzz');
    expect(find.text(OpsTexts.noRemittancesSearch), findsOneWidget);

    await typeAndWait(tester, '');

    expect(find.text(OpsTexts.noRemittancesSearch), findsNothing);
    expect(find.text(OpsTexts.noRemittances), findsOneWidget);
  });

  testWidgets('CR-3: a 400 shows the server message, offers no «Reintentar» and keeps the field', (tester) async {
    answer = (filter, page) {
      if (filter.beneficiaryQuery != null) {
        throw const ApiException('El texto de búsqueda no es válido.', statusCode: 400, code: 'VALIDATION_FAILED');
      }
      return PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    };
    await pump(tester);

    await typeAndWait(tester, 'jose');

    expect(find.text('El texto de búsqueda no es válido.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing, reason: 'the same text would be refused again');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'jose');
    expect(searches.length, 1);
  });

  testWidgets('CR-3: after a network failure «Reintentar» repeats the same search', (tester) async {
    var fail = true;
    answer = (filter, page) {
      if (filter.beneficiaryQuery != null && fail) throw const ApiException(CoreTexts.networkError);
      return PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    };
    await pump(tester);
    await typeAndWait(tester, 'jose');
    expect(find.text(CoreTexts.networkError), findsOneWidget);

    fail = false;
    searches.clear();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(searches.single.$1.beneficiaryQuery, 'jose');
    expect(find.text('OT-1'), findsOneWidget);
  });

  testWidgets('a 400 is cleared by correcting the text', (tester) async {
    answer = (filter, page) {
      if (filter.beneficiaryQuery == 'jo') {
        throw const ApiException('El texto de búsqueda no es válido.', statusCode: 400);
      }
      return PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    };
    await pump(tester);
    await typeAndWait(tester, 'jo');
    expect(find.text('El texto de búsqueda no es válido.'), findsOneWidget);

    await typeAndWait(tester, 'jose');

    expect(find.text('El texto de búsqueda no es válido.'), findsNothing);
    expect(find.text('OT-1'), findsOneWidget);
  });

  testWidgets('blank text (only spaces) sends no search and shows no hint', (tester) async {
    await pump(tester);

    await typeAndWait(tester, '    ');

    expect(searches, isEmpty);
    expect(find.text(OpsTexts.searchTooShort), findsNothing);
  });

  testWidgets('the same text typed again sends nothing new', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose');
    searches.clear();

    await typeAndWait(tester, 'jose ');

    expect(searches, isEmpty);
  });

  testWidgets('typing while a page loads does not cancel it, and the search then applies', (tester) async {
    final slow = Completer<PageResult<Remittance>>();
    await pump(tester);
    answer = (filter, page) => PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    when(
      () => remittances.search(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((call) {
      final filter = call.positionalArguments.first as RemittanceFilter;
      searches.add((filter, call.namedArguments[#page] as int));
      if (filter.beneficiaryQuery == null && filter.late == true) return slow.future;
      return Future.value(answer(filter, call.namedArguments[#page] as int));
    });

    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pump();
    await typeAndWait(tester, 'jose');
    slow.complete(PageResult(items: [_remittance('r9', 'OT-9')], page: 0, size: 20, totalItems: 1));
    await tester.pumpAndSettle();

    expect(searches.last.$1.beneficiaryQuery, 'jose');
    expect(searches.last.$1.late, isTrue);
    expect(find.text('OT-1'), findsOneWidget);
    expect(find.text('OT-9'), findsNothing);
  });

  testWidgets('a text of 100 characters is accepted and the field stops at 100', (tester) async {
    await pump(tester);

    await typeAndWait(tester, 'a' * 120);

    final text = tester.widget<TextField>(find.byType(TextField)).controller!.text;
    expect(text.length, 100);
    expect(searches.single.$1.beneficiaryQuery, 'a' * 100);
  });

  testWidgets('a short text after a search keeps the last results and shows the hint', (tester) async {
    await pump(tester);
    await typeAndWait(tester, 'jose');
    searches.clear();

    await typeAndWait(tester, 'j');

    expect(searches, isEmpty);
    expect(find.text(OpsTexts.searchTooShort), findsOneWidget);
    expect(find.text('OT-1'), findsOneWidget);
  });

  testWidgets('the field has an accessible name and the hint is text, not only colour', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await type(tester, 'j');

    expect(find.bySemanticsLabel(RegExp('Beneficiario')), findsWidgets);
    expect(find.text(OpsTexts.searchTooShort), findsOneWidget);
    handle.dispose();
  });

  testWidgets('narrow screen (phone width): the beneficiary field is there and the search works', (tester) async {
    await pump(tester);
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await typeAndWait(tester, 'jose');
    expect(searches.single.$1.beneficiaryQuery, 'jose');
    expect(tester.takeException(), isNull);
  });

  testWidgets('DEF-1: after a network failure, typing does not crash the results area', (tester) async {
    answer = (filter, page) {
      if (filter.beneficiaryQuery != null) throw const ApiException(CoreTexts.networkError);
      return PageResult(items: [_remittance('r1', 'OT-1')], page: page, size: 20, totalItems: 1);
    };
    await pump(tester);
    await typeAndWait(tester, 'jose');
    expect(find.text(CoreTexts.networkError), findsOneWidget);

    await type(tester, 'josep');

    expect(tester.takeException(), isNull);
    expect(find.text(CoreTexts.networkError), findsOneWidget);
  });

  testWidgets('CR-2: «Quitar filtros» empties a text that is too short, and its hint', (tester) async {
    await pump(tester);
    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pumpAndSettle();
    await typeAndWait(tester, 'j');
    expect(find.text(OpsTexts.searchTooShort), findsOneWidget);

    await tester.tap(find.text(OpsTexts.clearFilters));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text(OpsTexts.searchTooShort), findsNothing);
  });

  testWidgets('CR-2: «Quitar filtros» drops a search still waiting for its pause', (tester) async {
    await pump(tester);
    await tester.tap(find.text(OpsTexts.onlyLate));
    await tester.pumpAndSettle();
    searches.clear();
    await type(tester, 'jose'); // the 400 ms pause has not ended

    await tester.tap(find.text(OpsTexts.clearFilters));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(searches.every((search) => search.$1.beneficiaryQuery == null), isTrue);
    expect(searches.last.$1.isEmpty, isTrue);
  });

  testWidgets('CR-4: Enter searches at once, without the pause', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await type(tester, 'jose');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(searches.single.$1.beneficiaryQuery, 'jose');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(searches.length, 1, reason: 'the pause that was running sends nothing more');
  });

  testWidgets('CR-4: Enter with a text that is too short sends nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await type(tester, 'j');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(searches, isEmpty);
    expect(find.text(OpsTexts.searchTooShort), findsOneWidget);
  });

  testWidgets('CR-5: the hint is a live region, so a screen reader announces it', (tester) async {
    await pump(tester);
    await type(tester, 'j');

    final liveRegion = find.ancestor(
      of: find.text(OpsTexts.searchTooShort),
      matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.liveRegion == true),
    );
    expect(liveRegion, findsOneWidget);
  });

  testWidgets('CR-5: the clear button shows only with text, empties the field and removes the search at once', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byTooltip(OpsTexts.clearSearch), findsNothing);
    await typeAndWait(tester, 'jose');
    expect(find.byTooltip(OpsTexts.clearSearch), findsOneWidget);
    searches.clear();

    await tester.tap(find.byTooltip(OpsTexts.clearSearch));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(searches.single.$1.beneficiaryQuery, isNull);
    expect(find.byTooltip(OpsTexts.clearSearch), findsNothing);
  });
}
