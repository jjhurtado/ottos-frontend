import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/rates/cubit/rates_cubit.dart';
import 'package:ottos_ops/features/rates/view/rates_page.dart';

class _MockRates extends Mock implements RateRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _cup = Corridor(
  code: 'USD-CUP',
  sourceCurrency: 'USD',
  targetCurrency: 'CUP',
  deliveryRounding: 50,
  rate: ExchangeRate(id: 'r1', rate: 410),
  feeRule: FeeRule(id: 'f1', type: FeeType.percentage, value: 10, minFee: 10),
);
const _usd = Corridor(
  code: 'USD-USD',
  sourceCurrency: 'USD',
  targetCurrency: 'USD',
  deliveryRounding: 0.01,
  rate: ExchangeRate(id: 'r2', rate: 1),
  feeRule: FeeRule(id: 'f2', type: FeeType.fixed, value: 5),
);
const _eur = Corridor(code: 'USD-EUR', sourceCurrency: 'USD', targetCurrency: 'EUR', active: false);

void main() {
  late _MockRates rates;

  setUpAll(() async {
    registerFallbackValue(const FeeRuleInput(type: FeeType.fixed, value: 0));
    await OttosLocalization.initialize();
  });

  setUp(() {
    rates = _MockRates();
    when(() => rates.corridors()).thenAnswer((_) async => [_eur, _usd, _cup]);
  });

  group('texts', () {
    test('describe fee rules', () {
      expect(OpsTexts.describeFee(_cup.feeRule!, 'USD'), '10,00 % (mínimo 10,00 USD)');
      expect(OpsTexts.describeFee(_usd.feeRule!, 'USD'), '5,00 USD');
      expect(
        OpsTexts.describeFee(const FeeRule(id: 'f', type: FeeType.percentage, value: 5, minFee: 0, maxFee: 50), 'USD'),
        '5,00 % (máximo 50,00 USD)',
      );
    });

    test('describe a rate', () {
      expect(OpsTexts.rateValue(410, _cup, null), '410,00 CUP por 1 USD');
    });
  });

  test('lists active corridors first, then by code', () async {
    final cubit = RatesCubit(rates: rates);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.corridors.map((c) => c.code), ['USD-CUP', 'USD-USD', 'USD-EUR']);
  });

  group('page', () {
    Future<void> pumpRates(WidgetTester tester, Set<String> permissions) async {
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
              permissions: permissions,
            ),
          ),
        );
      addTearDown(authBloc.close);
      await tester.binding.setSurfaceSize(const Size(1400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<RateRepository>.value(
          value: rates,
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: RatesPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a writer can change rates, except the fixed USD-USD one', (tester) async {
      await pumpRates(tester, {Permissions.ratesRead, Permissions.ratesWrite});

      expect(find.text(OpsTexts.newRate), findsNWidgets(2), reason: 'USD-CUP and USD-EUR');
      expect(find.text(OpsTexts.newFeeRule), findsNWidgets(3));
      expect(find.text(OpsTexts.fixedRate), findsOneWidget);
      expect(find.text(OpsTexts.noRateWarning), findsOneWidget);
      expect(find.text(OpsTexts.calculator), findsOneWidget);
    });

    testWidgets('a reader sees the rates but cannot change them', (tester) async {
      await pumpRates(tester, {Permissions.ratesRead});

      expect(find.text(OpsTexts.rateValue(410, _cup, null)), findsOneWidget);
      expect(find.text(OpsTexts.newRate), findsNothing);
      expect(find.text(OpsTexts.newFeeRule), findsNothing);
    });

    testWidgets('the fee dialog checks the percentage and the bounds before saving', (tester) async {
      await pumpRates(tester, {Permissions.ratesRead, Permissions.ratesWrite});

      await tester.tap(find.text(OpsTexts.newFeeRule).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.feeValue} *'), '120');
      await tester.enterText(find.widgetWithText(TextFormField, OpsTexts.minFee), '20');
      await tester.enterText(find.widgetWithText(TextFormField, OpsTexts.maxFee), '5');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.errorCodes['FEE_PERCENTAGE_TOO_HIGH']!), findsOneWidget);
      expect(find.text(CoreTexts.errorCodes['INVALID_FEE_RANGE']!), findsOneWidget);
      verifyNever(() => rates.setFeeRule(any(), any()));
    });

    testWidgets('saving a new rate reloads the corridors', (tester) async {
      when(() => rates.setRate('USD-CUP', 420)).thenAnswer((_) async => const ExchangeRate(id: 'r3', rate: 420));
      await pumpRates(tester, {Permissions.ratesRead, Permissions.ratesWrite});

      await tester.tap(find.text(OpsTexts.newRate).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.rate} *'), '420');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(() => rates.setRate('USD-CUP', 420)).called(1);
      verify(() => rates.corridors()).called(2);
      expect(find.text(OpsTexts.rateSaved), findsOneWidget);
    });
  });
}
