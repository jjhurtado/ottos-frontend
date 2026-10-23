import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/remittances/view/new_remittance_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  late _MockRates rates;

  setUpAll(OttosLocalization.initialize);

  setUp(() {
    rates = _MockRates();
    when(() => rates.corridors()).thenAnswer(
      (_) async => const [
        Corridor(
          code: 'USD-CUP',
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          rate: ExchangeRate(id: 'r', rate: 410),
          pickupRate: ExchangeRate(id: 'p', rate: 1, remittanceType: RemittanceType.pickup),
        ),
      ],
    );
  });

  Future<void> pump(WidgetTester tester, Set<String> permissions) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions),
        ),
      );
    addTearDown(authBloc.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: _MockRemittances()),
          RepositoryProvider<CustomerRepository>.value(value: _MockCustomers()),
          RepositoryProvider<RateRepository>.value(value: rates),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const Scaffold(body: NewRemittancePage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const sales = {Permissions.remittancesCreate, Permissions.ratesRead, Permissions.customersRead};

  testWidgets('who may sends a delivery on the house, with a reason', (tester) async {
    await pump(tester, {...sales, Permissions.remittancesOnTheHouse});

    expect(find.text(CoreTexts.onTheHouseCheckbox), findsOneWidget);
    expect(find.text(CoreTexts.onTheHouseReason), findsNothing);

    await tester.tap(find.text(CoreTexts.onTheHouseCheckbox));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.onTheHouseReason), findsOneWidget);
    expect(find.widgetWithText(FilledButton, CoreTexts.registerOnTheHouse), findsOneWidget);
    expect(find.widgetWithText(FilledButton, OpsTexts.register), findsNothing);
  });

  testWidgets('a pickup cannot go on the house', (tester) async {
    await pump(tester, {...sales, Permissions.remittancesOnTheHouse});

    await tester.tap(find.text(CoreTexts.pickup));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.onTheHouseCheckbox), findsNothing);
  });

  testWidgets('without the permission there is no box', (tester) async {
    await pump(tester, sales);

    expect(find.text(CoreTexts.onTheHouseCheckbox), findsNothing);
    expect(find.widgetWithText(FilledButton, OpsTexts.register), findsOneWidget);
  });
}
