import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/cash/view/courier_cash_page.dart';
import 'package:ottos_ops/features/cash/view/exchanges_to_review.dart';

class _MockCash extends Mock implements CashRepository {}

class _MockAuth extends Mock implements AuthRepository {}

CurrencyExchange _flagged({bool resolved = false}) => CurrencyExchange.fromJson({
  'id': 'e1',
  'courierName': 'Luis',
  'fromCurrency': 'USD',
  'fromAmount': 10,
  'toCurrency': 'CUP',
  'toAmount': 4800,
  'rate': 480,
  'configuredRate': 760,
  'deviationPercent': 36.84,
  'occurredAt': '2026-10-11T16:00:06Z',
  'review': {
    'reason': 'UNUSUAL_EXCHANGE_RATE',
    'flaggedAt': '2026-10-11T16:00:06Z',
    'resolvedAt': resolved ? '2026-10-11T17:00:00Z' : null,
  },
});

void main() {
  late _MockCash cash;

  setUpAll(() async {
    registerFallbackValue(const ExchangeInput(fromCurrency: 'USD', fromAmount: 1, toCurrency: 'CUP', rate: 1));
    await OttosLocalization.initialize();
  });

  setUp(() => cash = _MockCash());

  Future<void> pump(WidgetTester tester, Widget page, Set<String> permissions) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions),
        ),
      );
    addTearDown(authBloc.close);
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<CashRepository>.value(
        value: cash,
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void pendingAre(List<CurrencyExchange> items) =>
      when(() => cash.exchanges(review: true, size: 50))
          .thenAnswer((_) async => PageResult(items: items, page: 0, size: 50, totalItems: items.length));

  testWidgets('an unusual exchange is shown with why and resolved with a note', (tester) async {
    pendingAre([_flagged()]);
    when(() => cash.resolveExchangeReview('e1', note: 'Llamé al repartidor')).thenAnswer((_) async {
      pendingAre([]);
      return _flagged(resolved: true);
    });
    await pump(tester, const SingleChildScrollView(child: ExchangesToReview()), {
      Permissions.cashRead,
      Permissions.cashReview,
    });

    expect(find.textContaining('Luis'), findsOneWidget);
    expect(find.textContaining('se aleja 36,84 %'), findsOneWidget);

    await tester.tap(find.text(OpsTexts.resolve));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Llamé al repartidor');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OpsTexts.resolve)));
    await tester.pumpAndSettle();

    verify(() => cash.resolveExchangeReview('e1', note: 'Llamé al repartidor')).called(1);
    expect(find.textContaining('Luis'), findsNothing);
  });

  testWidgets('without cash:review it is shown but not resolved; with none it shows nothing', (tester) async {
    pendingAre([_flagged()]);
    await pump(tester, const SingleChildScrollView(child: ExchangesToReview()), {Permissions.cashRead});
    expect(find.text(OpsTexts.exchangesToReview, findRichText: true), findsNothing);
    expect(find.textContaining(OpsTexts.exchangesToReview), findsOneWidget);
    expect(find.text(OpsTexts.resolve), findsNothing);

    pendingAre([]);
    await pump(tester, const SingleChildScrollView(child: ExchangesToReview(key: ValueKey('again'))), {
      Permissions.cashRead,
    });
    expect(find.textContaining(OpsTexts.exchangesToReview), findsNothing);
  });

  testWidgets('sales register an exchange on behalf of a courier', (tester) async {
    when(() => cash.courierStatement('k1')).thenAnswer(
      (_) async => const CourierStatement(
        cash: CourierCash(courierId: 'k1', name: 'Luis', balances: [], negative: false),
        movements: [],
      ),
    );
    when(() => cash.exchangeFor('k1', any())).thenAnswer((_) async => _flagged());
    await pump(tester, const CourierCashPage(courierId: 'k1'), {Permissions.cashRead, Permissions.cashWrite});

    await tester.tap(find.text(OpsTexts.registerExchange));
    await tester.pumpAndSettle();
    expect(find.text(OpsTexts.exchangeForTitle('Luis')), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.exchangeAmount), '10');
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.exchangeRate), '480');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.exchangeConfirm)));
    await tester.pumpAndSettle();

    verify(
      () => cash.exchangeFor(
        'k1',
        const ExchangeInput(fromCurrency: 'USD', fromAmount: 10, toCurrency: 'CUP', rate: 480, note: ''),
      ),
    ).called(1);
    expect(find.text(OpsTexts.exchangeFlagged), findsOneWidget);
  });
}
