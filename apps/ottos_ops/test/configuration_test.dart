import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/configuration/cubit/configuration_cubit.dart';
import 'package:ottos_ops/features/configuration/view/configuration_page.dart';

class _MockRates extends Mock implements RateRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _cup = Corridor(
  code: 'USD-CUP',
  sourceCurrency: 'USD',
  targetCurrency: 'CUP',
  deliveryRounding: 50,
  rate: ExchangeRate(id: 'r1', rate: 410),
  feeRule: FeeRule(id: 'f1', type: FeeType.percentage, value: 10, minFee: 10),
  pickupRate: ExchangeRate(id: 'p1', rate: 1, remittanceType: RemittanceType.pickup),
  pickupFeeRule: FeeRule(id: 'pf1', type: FeeType.fixed, value: 3, remittanceType: RemittanceType.pickup),
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
    registerFallbackValue(RemittanceType.delivery);
    await OttosLocalization.initialize();
  });

  setUp(() {
    rates = _MockRates();
    when(() => rates.corridors()).thenAnswer((_) async => [_eur, _usd, _cup]);
    when(() => rates.settings()).thenAnswer((_) async => const Settings());
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

  test('loads the settings and lists active corridors first, then by code', () async {
    final cubit = ConfigurationCubit(rates: rates);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.settings, const Settings());
    expect(cubit.state.corridors.map((c) => c.code), ['USD-CUP', 'USD-USD', 'USD-EUR']);
  });

  group('page', () {
    Future<void> pumpPage(WidgetTester tester, Set<String> permissions) async {
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
              home: const Scaffold(body: ConfigurationPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a writer can change rates, except the fixed USD-USD one', (tester) async {
      await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite, Permissions.ratesRead});

      // Deliveries and pickups of each corridor.
      expect(find.text(OpsTexts.newRate), findsNWidgets(4), reason: 'USD-CUP and USD-EUR');
      expect(find.text(OpsTexts.newFeeRule), findsNWidgets(6));
      expect(find.text(OpsTexts.fixedRate), findsNWidgets(2));
      expect(find.text(OpsTexts.noRateWarning(RemittanceType.delivery)), findsOneWidget);
      expect(find.text(OpsTexts.noRateWarning(RemittanceType.pickup)), findsOneWidget);
      expect(find.text(OpsTexts.calculator), findsOneWidget);
    });

    testWidgets('a reader sees the rates but cannot change them', (tester) async {
      await pumpPage(tester, {Permissions.configurationRead, Permissions.ratesRead});

      expect(find.text(OpsTexts.rateValue(410, _cup, null)), findsOneWidget);
      expect(find.text(OpsTexts.ratesFor(RemittanceType.pickup)), findsNWidgets(3));
      expect(find.text(OpsTexts.newRate), findsNothing);
      expect(find.text(OpsTexts.newFeeRule), findsNothing);
    });

    testWidgets('the fee dialog checks the percentage and the bounds before saving', (tester) async {
      await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite, Permissions.ratesRead});

      await tester.tap(find.text(OpsTexts.newFeeRule).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.feeValue} *'), '120');
      await tester.enterText(find.widgetWithText(TextFormField, OpsTexts.minFee), '20');
      await tester.enterText(find.widgetWithText(TextFormField, OpsTexts.maxFee), '5');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.errorCodes['FEE_PERCENTAGE_TOO_HIGH']!), findsOneWidget);
      expect(find.text(CoreTexts.errorCodes['INVALID_FEE_RANGE']!), findsOneWidget);
      verifyNever(() => rates.setFeeRule(any(), any(), type: any(named: 'type')));
    });

    testWidgets('saving a new rate reloads the corridors', (tester) async {
      when(() => rates.setRate('USD-CUP', 420, type: RemittanceType.delivery))
          .thenAnswer((_) async => const ExchangeRate(id: 'r3', rate: 420));
      await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite, Permissions.ratesRead});
      // Like the backend: the reload brings the corridor with its new rate, a
      // different object from the one the calculator had selected.
      const updated = Corridor(
        code: 'USD-CUP',
        sourceCurrency: 'USD',
        targetCurrency: 'CUP',
        deliveryRounding: 50,
        rate: ExchangeRate(id: 'r3', rate: 420),
        feeRule: FeeRule(id: 'f1', type: FeeType.percentage, value: 10, minFee: 10),
      );
      when(() => rates.corridors()).thenAnswer((_) async => [_eur, _usd, updated]);

      await tester.tap(find.text(OpsTexts.newRate).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.rate} *'), '420');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(() => rates.setRate('USD-CUP', 420, type: RemittanceType.delivery)).called(1);
      verify(() => rates.corridors()).called(2);
      expect(find.text(OpsTexts.rateSaved), findsOneWidget);
      expect(find.textContaining('420'), findsWidgets);
    });

    testWidgets('opens the history of a corridor', (tester) async {
      when(() => rates.rateHistory('USD-CUP', type: RemittanceType.delivery))
          .thenAnswer((_) async => const [ExchangeRate(id: 'r1', rate: 410)]);
      when(() => rates.feeRuleHistory('USD-CUP', type: RemittanceType.delivery)).thenAnswer((_) async => const []);
      await pumpPage(tester, {Permissions.configurationRead});

      await tester.tap(find.text(OpsTexts.history).first);
      await tester.pumpAndSettle();

      verify(() => rates.rateHistory('USD-CUP', type: RemittanceType.delivery)).called(1);
      expect(find.text(OpsTexts.rateHistory), findsOneWidget);
    });

    testWidgets('a pickup rate is saved apart from the delivery one', (tester) async {
      when(() => rates.setRate('USD-CUP', 2, type: RemittanceType.pickup))
          .thenAnswer((_) async => const ExchangeRate(id: 'p2', rate: 2, remittanceType: RemittanceType.pickup));
      await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite});

      // USD-CUP comes first (active), deliveries then pickups.
      await tester.tap(find.text(OpsTexts.newRate).at(1));
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.newRateTitle('USD-CUP', RemittanceType.pickup)), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.rate} *'), '2');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(() => rates.setRate('USD-CUP', 2, type: RemittanceType.pickup)).called(1);
      verifyNever(() => rates.setRate(any(), any(), type: RemittanceType.delivery));
    });

    testWidgets('the calculator quotes a pickup with its own rate', (tester) async {
      when(() => rates.quote(sourceCurrency: 'USD', targetCurrency: 'CUP', amount: 100, type: RemittanceType.pickup))
          .thenAnswer(
            (_) async => const Quote(
              sourceCurrency: 'USD',
              targetCurrency: 'CUP',
              amount: 100,
              fee: 3,
              total: 103,
              rate: 1,
              amountToDeliver: 100,
            ),
          );
      await pumpPage(tester, {Permissions.configurationRead, Permissions.ratesRead});

      await tester.enterText(find.widgetWithText(TextField, OpsTexts.amountToSend), '100');
      await tester.tap(find.text(CoreTexts.delivery).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(CoreTexts.pickup).last);
      await tester.pumpAndSettle();

      verify(() => rates.quote(sourceCurrency: 'USD', targetCurrency: 'CUP', amount: 100, type: RemittanceType.pickup))
          .called(1);
      expect(find.textContaining('103'), findsWidgets);
    });

    testWidgets('shows the settings and hides the calculator without rates:read', (tester) async {
      await pumpPage(tester, {Permissions.configurationRead});

      expect(find.text(OpsTexts.noMinimum), findsOneWidget);
      expect(find.text(OpsTexts.deliveryDaysValue(2)), findsOneWidget);
      expect(find.text(OpsTexts.calculator), findsNothing);
      expect(find.text(OpsTexts.edit), findsNothing);
    });

    testWidgets('the settings dialog checks the days and saves both values', (tester) async {
      when(() => rates.updateSettings(minimumAmount: 20, defaultDeliveryDays: 3, exchangeRateTolerancePercent: 20))
          .thenAnswer((_) async => const Settings(minimumAmount: 20, defaultDeliveryDays: 3));
      await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite});

      await tester.tap(find.text(OpsTexts.edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.minimumAmount} *'), '20');
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.deliveryDays} *'), '90');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.deliveryDaysRange), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.deliveryDays} *'), '3');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();
      verify(() => rates.updateSettings(minimumAmount: 20, defaultDeliveryDays: 3, exchangeRateTolerancePercent: 20))
          .called(1);
      expect(find.text(OpsTexts.settingsSaved), findsOneWidget);
    });

    group('business time zone (REQ-006)', () {
      setUp(() {
        BusinessTime.setForTest(deviceClock: () => DateTime.utc(2026, 11, 5, 18, 32));
        when(() => rates.settings()).thenAnswer(
          (_) async => const Settings(businessTime: BusinessTimeZone(timeZone: 'UTC-04:00', offsetMinutes: -240)),
        );
      });
      tearDown(BusinessTime.reset);

      testWidgets('AC-1.1 AC-1.3: a reader sees the zone and the business time, without «Editar»', (tester) async {
        await pumpPage(tester, {Permissions.configurationRead});

        expect(find.text(OpsTexts.businessTimeZone), findsOneWidget);
        expect(find.textContaining('UTC−4 · ahora son las 14:32'), findsOneWidget);
        expect(find.text(OpsTexts.edit), findsNothing);
      });

      testWidgets('AC-1.5: a new zone asks for confirmation and saves it', (tester) async {
        when(
          () => rates.updateSettings(
            minimumAmount: 0,
            defaultDeliveryDays: 2,
            exchangeRateTolerancePercent: 20,
            businessTimeZone: 'UTC-05:00',
          ),
        ).thenAnswer(
          (_) async => const Settings(businessTime: BusinessTimeZone(timeZone: 'UTC-05:00', offsetMinutes: -300)),
        );
        await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite});

        await tester.tap(find.text(OpsTexts.edit));
        await tester.pumpAndSettle();
        expect(find.text('UTC−4 · ${OpsTexts.businessTimeZoneCurrent}'), findsOneWidget);
        await tester.tap(find.text('UTC−4 · ${OpsTexts.businessTimeZoneCurrent}'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('UTC−5').last);
        await tester.pumpAndSettle();
        expect(find.textContaining('Con UTC−5 ahora serían las 13:32'), findsOneWidget);

        await tester.tap(find.text(OpsTexts.save));
        await tester.pumpAndSettle();
        expect(find.text(OpsTexts.businessTimeZoneConfirmTitle('UTC−5')), findsOneWidget);
        await tester.tap(find.text(CoreTexts.cancel).last);
        await tester.pumpAndSettle();
        verifyNever(
          () => rates.updateSettings(
            minimumAmount: any(named: 'minimumAmount'),
            defaultDeliveryDays: any(named: 'defaultDeliveryDays'),
            exchangeRateTolerancePercent: any(named: 'exchangeRateTolerancePercent'),
            businessTimeZone: any(named: 'businessTimeZone'),
          ),
        );

        await tester.tap(find.text(OpsTexts.save));
        await tester.pumpAndSettle();
        await tester.tap(find.text(OpsTexts.businessTimeZoneConfirm));
        await tester.pumpAndSettle();
        verify(
          () => rates.updateSettings(
            minimumAmount: 0,
            defaultDeliveryDays: 2,
            exchangeRateTolerancePercent: 20,
            businessTimeZone: 'UTC-05:00',
          ),
        ).called(1);
      });

      testWidgets('AC-1.4: a refused zone keeps the dialog open with the message', (tester) async {
        when(
          () => rates.updateSettings(
            minimumAmount: any(named: 'minimumAmount'),
            defaultDeliveryDays: any(named: 'defaultDeliveryDays'),
            exchangeRateTolerancePercent: any(named: 'exchangeRateTolerancePercent'),
            businessTimeZone: any(named: 'businessTimeZone'),
          ),
        ).thenThrow(
          ApiException(CoreTexts.errorCodes['INVALID_TIME_ZONE']!, statusCode: 400, code: 'INVALID_TIME_ZONE'),
        );
        await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite});

        await tester.tap(find.text(OpsTexts.edit));
        await tester.pumpAndSettle();
        await tester.tap(find.text('UTC−4 · ${OpsTexts.businessTimeZoneCurrent}'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('UTC−5').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(OpsTexts.save));
        await tester.pumpAndSettle();
        await tester.tap(find.text(OpsTexts.businessTimeZoneConfirm));
        await tester.pumpAndSettle();

        expect(find.text(CoreTexts.errorCodes['INVALID_TIME_ZONE']!), findsOneWidget);
        expect(find.text(OpsTexts.save), findsOneWidget, reason: 'the edit dialog is still open');
      });

      testWidgets('AC-1.5 (same zone): saving without a change asks for no confirmation', (tester) async {
        when(
          () => rates.updateSettings(
            minimumAmount: any(named: 'minimumAmount'),
            defaultDeliveryDays: any(named: 'defaultDeliveryDays'),
            exchangeRateTolerancePercent: any(named: 'exchangeRateTolerancePercent'),
            businessTimeZone: any(named: 'businessTimeZone'),
          ),
        ).thenAnswer(
          (_) async => const Settings(businessTime: BusinessTimeZone(timeZone: 'UTC-04:00', offsetMinutes: -240)),
        );
        await pumpPage(tester, {Permissions.configurationRead, Permissions.configurationWrite});

        await tester.tap(find.text(OpsTexts.edit));
        await tester.pumpAndSettle();
        await tester.tap(find.text(OpsTexts.save));
        await tester.pumpAndSettle();

        expect(find.text(OpsTexts.businessTimeZoneConfirm), findsNothing);
        verify(
          () => rates.updateSettings(
            minimumAmount: any(named: 'minimumAmount'),
            defaultDeliveryDays: any(named: 'defaultDeliveryDays'),
            exchangeRateTolerancePercent: any(named: 'exchangeRateTolerancePercent'),
            businessTimeZone: null,
          ),
        ).called(1);
      });

      test('the audit log says the change in labels', () {
        final entry = AuditEntry.fromJson({
          'id': 'a1',
          'occurredAt': '2026-11-05T18:00:00Z',
          'action': 'BUSINESS_TIME_ZONE_CHANGED',
          'targetType': 'SETTINGS',
          'details': {'from': 'UTC-04:00', 'to': 'UTC-05:00'},
        });
        expect(OpsTexts.auditAction(entry.action), 'Zona horaria cambiada');
        expect(OpsTexts.auditTargetLabel(entry), 'Configuración');
        expect(OpsTexts.auditDetails(entry), ['De UTC−4 a UTC−5']);
      });
    });
  });
}
