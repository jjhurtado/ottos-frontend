import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/cubit/assigned_cubit.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockSource extends Mock implements RemittanceSource {}

class _FakeFilter extends Fake implements RemittanceFilter {}

Map<String, dynamic> _remittance(String id, {String name = 'Beneficiario', String status = 'DELIVERED'}) => {
  'id': id,
  'code': id,
  'type': 'DELIVERY',
  'status': status,
  'statusName': status,
  'beneficiaryName': name,
  'cashAmount': 100,
  'cashCurrency': 'USD',
};

PageResult<Remittance> _page(List<String> ids, {int page = 0, int total = 0}) => PageResult(
  items: [for (final id in ids) Remittance.fromJson(_remittance(id, name: 'José $id'))],
  page: page,
  size: 50,
  totalItems: total == 0 ? ids.length : total,
);

const _debounce = Duration(milliseconds: 400);

/// REQ-018 US-2: sales search by beneficiary in the app.
void main() {
  setUpAll(() => registerFallbackValue(_FakeFilter()));

  group('OnlineSource', () {
    test('AC-2.1: searches with the beneficiary filter, every status, pages of 50', () async {
      final repository = _MockRemittances();
      when(
        () => repository.search(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => _page(['OT-1']));

      final result = await OnlineSource(remittances: repository).search('jose', page: 2);

      expect(result.items.single.code, 'OT-1');
      final filter =
          verify(() => repository.search(captureAny(), page: 2, size: OnlineSource.searchPageSize)).captured.single
              as RemittanceFilter;
      expect(filter, const RemittanceFilter(beneficiaryQuery: 'jose'));
      expect(filter.status, isNull);
    });

    test('sales can search, the courier cannot', () {
      final repository = _MockRemittances();
      expect(OnlineSource(remittances: repository).canSearch, isTrue);
      expect(OnlineSource(remittances: repository, onlyMine: true).canSearch, isFalse);
    });
  });

  group('AssignedCubit', () {
    late _MockSource source;

    AssignedCubit makeCubit() => AssignedCubit(source: source, searchDelay: Duration.zero);

    setUp(() {
      source = _MockSource();
      when(() => source.canSearch).thenReturn(true);
      when(() => source.canShowCompleted).thenReturn(true);
      when(() => source.list()).thenAnswer((_) async => []);
      when(() => source.pendingIds()).thenAnswer((_) async => {});
      when(() => source.changes).thenAnswer((_) => const Stream.empty());
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    test('AC-2.1: typed text is searched on the server and the results kept in its order', () async {
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-2', 'OT-1']));
      final cubit = makeCubit();
      addTearDown(cubit.close);

      cubit.searchTyped('jose');
      await settle();

      expect(cubit.state.searching, isTrue);
      expect(cubit.state.status, AssignedStatus.success);
      expect([for (final r in cubit.state.results) r.code], ['OT-2', 'OT-1']);
    });

    test('text too short is not sent', () async {
      final cubit = makeCubit();
      addTearDown(cubit.close);

      cubit.searchTyped('j');
      await settle();
      cubit.searchTyped('123');
      await settle();

      expect(cubit.state.searching, isFalse);
      expect(cubit.state.searchTooShort, isTrue);
      verifyNever(() => source.search(any(), page: any(named: 'page')));
    });

    test('empty query goes back to the list', () async {
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-1']));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      cubit.searchTyped('jose');
      await settle();

      cubit.searchTyped('  ');
      await settle();

      expect(cubit.state.searching, isFalse);
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.searchTooShort, isFalse);
      verify(() => source.list()).called(greaterThan(0));
    });

    test('«Ver más» adds the next page without repeats', () async {
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-1', 'OT-2'], total: 100));
      when(() => source.search('jose', page: 1)).thenAnswer((_) async => _page(['OT-2', 'OT-3'], page: 1, total: 100));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      cubit.searchTyped('jose');
      await settle();
      expect(cubit.state.moreResults, isTrue);

      await cubit.moreSearch();

      expect([for (final r in cubit.state.results) r.code], ['OT-1', 'OT-2', 'OT-3']);
    });

    test('CR-9: «Ver más» asks only for the next page, without repeats', () async {
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-1', 'OT-2'], total: 100));
      when(() => source.search('jose', page: 1)).thenAnswer((_) async => _page(['OT-2', 'OT-3'], page: 1, total: 100));
      final cubit = makeCubit();
      addTearDown(cubit.close);
      cubit.searchTyped('jose');
      await settle();

      await cubit.moreSearch();

      verify(() => source.search('jose', page: 0)).called(1);
      verify(() => source.search('jose', page: 1)).called(1);
      expect([for (final r in cubit.state.results) r.code], ['OT-1', 'OT-2', 'OT-3']);
    });

    test('CR-8: clearing drops a search still in flight', () async {
      final answer = Completer<PageResult<Remittance>>();
      when(() => source.search('jose', page: 0)).thenAnswer((_) => answer.future);
      final cubit = makeCubit();
      addTearDown(cubit.close);
      cubit.searchTyped('jose');
      await settle();

      cubit.clearSearch();
      answer.complete(_page(['OT-1']));
      await settle();

      expect(cubit.state.searching, isFalse);
      expect(cubit.state.results, isEmpty);
    });

    test('AC-2.2: without connection the state says the search needs connection', () async {
      when(() => source.search(any(), page: any(named: 'page'))).thenThrow(const ApiException(CoreTexts.networkError));
      final cubit = makeCubit();
      addTearDown(cubit.close);

      cubit.searchTyped('jose');
      await settle();

      expect(cubit.state.status, AssignedStatus.failure);
      expect(cubit.state.searchOffline, isTrue);
      expect(cubit.state.error, CourierTexts.searchNeedsConnection);
    });

    test('a server error mid-search keeps the server message', () async {
      when(() => source.search(any(), page: any(named: 'page')))
          .thenThrow(const ApiException('Falló', statusCode: 500));
      final cubit = makeCubit();
      addTearDown(cubit.close);

      cubit.searchTyped('jose');
      await settle();

      expect(cubit.state.searchOffline, isFalse);
      expect(cubit.state.error, 'Falló');
    });
  });

  group('AssignedPage', () {
    late _MockSource source;

    Future<void> pump(WidgetTester tester, {bool canSearch = true}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      source = _MockSource();
      when(() => source.canSearch).thenReturn(canSearch);
      when(() => source.canShowCompleted).thenReturn(true);
      when(() => source.completedAreLatest).thenReturn(false);
      when(() => source.list())
          .thenAnswer((_) async => [Remittance.fromJson(_remittance('OT-OPEN', status: 'ASSIGNED'))]);
      when(() => source.completed(page: any(named: 'page'))).thenAnswer((_) async => _page([]));
      when(() => source.pendingIds()).thenAnswer((_) async => {});
      when(() => source.changes).thenAnswer((_) => const Stream.empty());
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
        ..add(
          const AuthLoggedIn(
            CurrentUser(
              id: 's1',
              email: 's@ottos.test',
              name: 'Ventas',
              type: 'SALES',
              roles: [],
              permissions: {Permissions.remittancesRead},
            ),
          ),
        );
      addTearDown(authBloc.close);
      await OttosLocalization.initialize();
      // Sales also see the business's money pending above the list (REQ-021).
      final repository = _MockRemittances();
      when(repository.pendingTotals).thenAnswer((_) async => const PendingTotals());
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<RemittanceSource>.value(value: source),
            RepositoryProvider<RemittanceRepository>.value(value: repository),
          ],
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: AssignedPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(_debounce);
      await tester.pumpAndSettle();
    }

    testWidgets('AC-2.1: results replace the list and the toggles are hidden', (tester) async {
      await pump(tester);
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-5', 'OT-6']));
      expect(find.byType(ChoiceChip), findsWidgets);

      await type(tester, 'jose');

      expect(find.text('José OT-5'), findsOneWidget);
      expect(find.text('José OT-6'), findsOneWidget);
      expect(find.text('OT-OPEN'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('no results says so', (tester) async {
      await pump(tester);
      when(() => source.search('zzz', page: 0)).thenAnswer((_) async => _page([]));

      await type(tester, 'zzz');

      expect(find.text(CourierTexts.noRemittancesSearch), findsOneWidget);
    });

    testWidgets('AC-2.2: without connection it says the search needs connection', (tester) async {
      await pump(tester);
      when(() => source.search(any(), page: any(named: 'page'))).thenThrow(const ApiException(CoreTexts.networkError));

      await type(tester, 'jose');

      expect(find.text(CourierTexts.searchNeedsConnection), findsOneWidget);
      expect(find.text(CoreTexts.retry), findsOneWidget);
    });

    testWidgets('empty or short text sends nothing; clearing returns to the list', (tester) async {
      await pump(tester);
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-5']));

      await type(tester, 'j');
      expect(find.text(CourierTexts.searchTooShort), findsOneWidget);
      verifyNever(() => source.search(any(), page: any(named: 'page')));

      await type(tester, 'jose');
      expect(find.text('OT-OPEN'), findsNothing);

      await tester.tap(find.byTooltip(CourierTexts.clearSearch));
      await tester.pumpAndSettle();
      expect(find.text('OT-OPEN'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('after a failed search, editing the text does not crash and searches again', (tester) async {
      await pump(tester);
      when(() => source.search('jose', page: 0)).thenThrow(const ApiException('Falló', statusCode: 500));
      await type(tester, 'jose');
      expect(find.text('Falló'), findsOneWidget);

      when(() => source.search('jose perez', page: 0)).thenAnswer((_) async => _page(['OT-9']));
      await tester.enterText(find.byType(TextField), 'jose perez');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(_debounce);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('José OT-9'), findsOneWidget);
    });

    testWidgets('SEC-34: the search field has no suggestions or autocorrect', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
    });

    testWidgets('CR-11: Enter searches at once, without waiting', (tester) async {
      await pump(tester);
      when(() => source.search('jose', page: 0)).thenAnswer((_) async => _page(['OT-5']));

      await tester.enterText(find.byType(TextField), 'jose');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      // Well under the 400 ms delay.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      verify(() => source.search('jose', page: 0)).called(1);
      expect(find.text('José OT-5'), findsOneWidget);
    });

    testWidgets('a source that cannot search (courier) shows no search field', (tester) async {
      await pump(tester, canSearch: false);

      expect(find.byType(TextField), findsNothing);
    });
  });
}
