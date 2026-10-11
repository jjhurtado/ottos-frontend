import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

const _customer = Customer(id: 'c1', fullName: 'Ana', phone: '+1305');
const _beneficiary = Beneficiary(id: 'b1', fullName: 'Rosa', phone: '535');
const _quote = Quote(
  sourceCurrency: 'USD',
  targetCurrency: 'CUP',
  amount: 100,
  fee: 10,
  total: 110,
  rate: 410,
  amountToDeliver: 41000,
);
const _created = Remittance(
  id: 'r1',
  code: 'OT-1',
  type: RemittanceType.delivery,
  status: 'PAID',
  statusName: 'Pagada',
);

void main() {
  late _MockRemittances remittances;
  late _MockCustomers customers;
  late _MockRates rates;
  late NewRemittanceCubit cubit;

  setUpAll(() {
    registerFallbackValue(RemittanceType.delivery);
    registerFallbackValue(
      const NewRemittance(
        type: RemittanceType.delivery,
        customerId: '',
        beneficiaryId: '',
        amount: 0,
        targetCurrency: '',
      ),
    );
  });

  setUp(() {
    remittances = _MockRemittances();
    customers = _MockCustomers();
    rates = _MockRates();
    when(() => rates.corridors()).thenAnswer(
      (_) async => const [
        Corridor(
          code: 'USD-CUP',
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          rate: ExchangeRate(id: 'x', rate: 410),
          pickupRate: ExchangeRate(id: 'p', rate: 1, remittanceType: RemittanceType.pickup),
        ),
        Corridor(code: 'USD-EUR', sourceCurrency: 'USD', targetCurrency: 'EUR'),
        Corridor(
          code: 'USD-USD',
          sourceCurrency: 'USD',
          targetCurrency: 'USD',
          rate: ExchangeRate(id: 'x', rate: 1),
        ),
        Corridor(
          code: 'USD-MLC',
          sourceCurrency: 'USD',
          targetCurrency: 'MLC',
          rate: ExchangeRate(id: 'x', rate: 1),
          active: false,
        ),
      ],
    );
    when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_beneficiary]);
    when(
      () => rates.quote(
        sourceCurrency: any(named: 'sourceCurrency'),
        targetCurrency: any(named: 'targetCurrency'),
        amount: any(named: 'amount'),
        type: any(named: 'type'),
        rate: any(named: 'rate'),
      ),
    ).thenAnswer((_) async => _quote);
    cubit = NewRemittanceCubit(remittances: remittances, customers: customers, rates: rates, quoteDelay: Duration.zero);
  });

  tearDown(() => cubit.close());

  /// Lets the debounced quote and other pending futures run.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  Future<void> fillForm() async {
    await cubit.load();
    await cubit.customerSelected(_customer);
    cubit.amountChanged(100);
    await settle();
  }

  test('offers active corridors from USD that have a rate, USD first and preselected', () async {
    await cubit.load();

    expect(cubit.state.corridorsStatus, LoadStatus.success);
    expect(cubit.state.targetCurrencies, ['USD', 'CUP']);
    expect(cubit.state.targetCurrency, 'USD');
  });

  test('preselects the first currency when USD has no rate', () async {
    when(() => rates.corridors()).thenAnswer(
      (_) async => const [
        Corridor(
          code: 'USD-CUP',
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          rate: ExchangeRate(id: 'x', rate: 410),
        ),
      ],
    );

    await cubit.load();

    expect(cubit.state.targetCurrency, 'CUP');
  });

  test('starts with the customer given, if active', () async {
    when(() => customers.get('c1')).thenAnswer((_) async => _customer);

    await cubit.load(customerId: 'c1');
    await settle();

    expect(cubit.state.customer, _customer);
    expect(cubit.state.beneficiary, _beneficiary);
  });

  test('ignores a customer that cannot be loaded', () async {
    when(() => customers.get('c9')).thenThrow(const ApiException(CoreTexts.notFound, statusCode: 404));

    await cubit.load(customerId: 'c9');

    expect(cubit.state.corridorsStatus, LoadStatus.success);
    expect(cubit.state.customer, isNull);
  });

  test('picks a beneficiary created from the form', () async {
    await fillForm();
    const marta = Beneficiary(id: 'b2', fullName: 'Marta', phone: '535');

    cubit.beneficiaryCreated(marta);

    expect(cubit.state.beneficiaries, const [_beneficiary, marta]);
    expect(cubit.state.beneficiary, marta);
  });

  test('picks the beneficiary when the customer has only one', () async {
    await cubit.load();
    await cubit.customerSelected(_customer);

    expect(cubit.state.beneficiary, _beneficiary);
  });

  test('changing the customer clears the beneficiary', () async {
    await fillForm();

    await cubit.customerSelected(null);

    expect(cubit.state.beneficiary, isNull);
    expect(cubit.state.canSubmit, isFalse);
  });

  test('quotes the amount and enables submit', () async {
    await fillForm();

    expect(cubit.state.quote, _quote);
    expect(cubit.state.canSubmit, isTrue);
    verify(() => rates.quote(sourceCurrency: 'USD', targetCurrency: 'USD', amount: 100, type: RemittanceType.delivery))
        .called(1);
  });

  test('a pickup offers the currencies with a pickup rate and quotes with it', () async {
    await fillForm();
    cubit.targetCurrencyChanged('CUP');
    await settle();

    cubit.typeChanged(RemittanceType.pickup);
    await settle();

    expect(cubit.state.targetCurrencies, ['CUP']);
    expect(cubit.state.targetCurrency, 'CUP');
    verify(() => rates.quote(sourceCurrency: 'USD', targetCurrency: 'CUP', amount: 100, type: RemittanceType.pickup))
        .called(1);
  });

  test('drops the quote when the amount is cleared', () async {
    await fillForm();

    cubit.amountChanged(null);

    expect(cubit.state.quote, isNull);
    expect(cubit.state.canSubmit, isFalse);
  });

  test('registers with the same idempotency key on every retry', () async {
    final keys = <String>[];
    var attempts = 0;
    when(() => remittances.register(any(), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((invocation) async {
          keys.add(invocation.namedArguments[#idempotencyKey] as String);
          if (attempts++ == 0) throw const ApiException(CoreTexts.networkError);
          return _created;
        });
    await fillForm();

    await cubit.submit(notes: '  ');
    expect(cubit.state.error, CoreTexts.networkError);
    expect(cubit.state.created, isNull);

    await cubit.submit(notes: 'Llamar antes');
    expect(cubit.state.created, _created);
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);

    final sent = verify(() => remittances.register(captureAny(), idempotencyKey: any(named: 'idempotencyKey'))).captured
        .cast<NewRemittance>();
    expect(sent.first.notes, isNull);
    expect(
      sent.last,
      const NewRemittance(
        type: RemittanceType.delivery,
        customerId: 'c1',
        beneficiaryId: 'b1',
        amount: 100,
        targetCurrency: 'USD',
        notes: 'Llamar antes',
      ),
    );
  });

  group('assigning on registering', () {
    const courier = Courier(id: 'k1', name: 'Luis');

    setUp(() {
      when(() => remittances.couriers()).thenAnswer((_) async => const [courier]);
      when(() => remittances.register(any(), idempotencyKey: any(named: 'idempotencyKey')))
          .thenAnswer((_) async => _created);
    });

    test('offers the couriers only to who can assign', () async {
      await cubit.load();
      await settle();
      expect(cubit.state.couriers, isEmpty);
      verifyNever(() => remittances.couriers());

      await cubit.load(canAssign: true);
      await settle();
      expect(cubit.state.couriers, [courier]);
    });

    test('assigns the chosen courier right after registering', () async {
      const assigned = Remittance(
        id: 'r1',
        code: 'OT-1',
        type: RemittanceType.delivery,
        status: 'ASSIGNED',
        statusName: 'Asignada',
        courierId: 'k1',
      );
      when(() => remittances.assign('r1', courierId: 'k1')).thenAnswer((_) async => assigned);
      await fillForm();
      cubit.courierSelected(courier);

      await cubit.submit();

      expect(cubit.state.created, assigned);
      expect(cubit.state.error, isNull);
    });

    test('a failed assignment keeps the registered remittance and says so', () async {
      when(() => remittances.assign('r1', courierId: 'k1'))
          .thenThrow(const ApiException('Not allowed', statusCode: 403));
      await fillForm();
      cubit.courierSelected(courier);

      await cubit.submit();

      expect(cubit.state.created, _created);
      expect(cubit.state.error, CoreTexts.registeredNotAssigned('Not allowed'));
    });

    test('without a courier it is only registered', () async {
      await fillForm();

      await cubit.submit();

      expect(cubit.state.created, _created);
      verifyNever(() => remittances.assign(any(), courierId: any(named: 'courierId')));
    });
  });

  group('pickup rate', () {
    setUp(
      () =>
          when(() => remittances.register(any(), idempotencyKey: any(named: 'idempotencyKey')))
              .thenAnswer((_) async => _created),
    );

    test('a pickup starts with the configured rate and may take its own', () async {
      await fillForm();
      cubit.targetCurrencyChanged('CUP');
      cubit.typeChanged(RemittanceType.pickup);
      await settle();
      expect(cubit.configuredPickupRate, 1);
      expect(cubit.state.pickupRate, isNull);

      cubit.pickupRateChanged(1.5);
      await settle();
      verify(
        () => rates.quote(
          sourceCurrency: 'USD',
          targetCurrency: 'CUP',
          amount: 100,
          type: RemittanceType.pickup,
          rate: 1.5,
        ),
      ).called(1);

      await cubit.submit();
      final sent =
          verify(() => remittances.register(captureAny(), idempotencyKey: any(named: 'idempotencyKey'))).captured.single
              as NewRemittance;
      expect(sent.rate, 1.5);
      expect(sent.toJson()['rate'], 1.5);
    });

    test('typing the configured rate, or switching to a delivery, drops the own rate', () async {
      await fillForm();
      cubit.targetCurrencyChanged('CUP');
      cubit.typeChanged(RemittanceType.pickup);
      cubit.pickupRateChanged(2);
      expect(cubit.state.pickupRate, 2);

      cubit.pickupRateChanged(1);
      expect(cubit.state.pickupRate, isNull);

      cubit.pickupRateChanged(2);
      cubit.typeChanged(RemittanceType.delivery);
      expect(cubit.state.pickupRate, isNull);
      expect(
        const NewRemittance(
          type: RemittanceType.delivery,
          customerId: 'c',
          beneficiaryId: 'b',
          amount: 1,
          targetCurrency: 'CUP',
        ).toJson().containsKey('rate'),
        isFalse,
      );
    });
  });

  group('beneficiaries of other customers', () {
    const rosa = Beneficiary(id: 'b2', fullName: 'Rosa Suelta', phone: '536');
    const gone = Beneficiary(id: 'b3', fullName: 'Rosa Baja', phone: '537', active: false);

    setUp(() {
      cubit = NewRemittanceCubit(remittances: remittances, customers: customers, rates: rates);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_beneficiary]);
    });

    tearDown(() => cubit.close());

    test('the search offers every active beneficiary', () async {
      when(() => customers.searchBeneficiaries('Rosa')).thenAnswer((_) async => const [rosa, gone]);
      expect(await cubit.searchBeneficiaries('Rosa'), [rosa]);
    });

    test('one found is added and picked; one already listed is just picked', () async {
      await cubit.customerSelected(_customer);
      cubit.beneficiaryCreated(rosa);
      expect(cubit.state.beneficiaries, [_beneficiary, rosa]);
      expect(cubit.state.beneficiary, rosa);

      cubit.beneficiaryCreated(_beneficiary);
      expect(cubit.state.beneficiaries, hasLength(2));
      expect(cubit.state.beneficiary, _beneficiary);
    });
  });
}
