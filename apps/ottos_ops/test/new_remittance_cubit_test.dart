import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/remittances/cubit/new_remittance_cubit.dart';

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
}
