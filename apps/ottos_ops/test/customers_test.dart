import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/customers/cubit/customer_detail_cubit.dart';
import 'package:ottos_ops/features/customers/cubit/customer_list_cubit.dart';

class _MockCustomers extends Mock implements CustomerRepository {}

const _ana = Customer(id: 'c1', fullName: 'Ana', phone: '+13055550001');
const _luis = Customer(id: 'c2', fullName: 'Luis', phone: '+13055550002');
const _rosa = Beneficiary(id: 'b1', fullName: 'Rosa', phone: '5352220001');
const _pedro = Beneficiary(id: 'b2', fullName: 'pedro', phone: '5352220002');

void main() {
  late _MockCustomers customers;

  setUp(() => customers = _MockCustomers());

  group('phone validation', () {
    test('accepts international and local numbers with separators', () {
      expect(phoneError('+1 305-555-0001'), isNull);
      expect(phoneError('53 5222 3344'), isNull);
      expect(phoneError('(305) 555 0001'), isNull);
    });

    test('rejects letters and numbers that are too short or too long', () {
      expect(phoneError('abc'), OpsTexts.phoneInvalid);
      expect(phoneError('12345'), OpsTexts.phoneInvalid);
      expect(phoneError('+1234567890123456'), OpsTexts.phoneInvalid);
    });
  });

  group('customer list', () {
    test('loads the most recent customers, then searches after the delay', () async {
      when(() => customers.search('')).thenAnswer((_) async => const [_ana, _luis]);
      when(() => customers.search('lu')).thenAnswer((_) async => const [_luis]);
      final cubit = CustomerListCubit(customers: customers, searchDelay: Duration.zero);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.customers, const [_ana, _luis]);

      cubit.queryChanged('l');
      cubit.queryChanged('lu');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, CustomerListStatus.success);
      expect(cubit.state.query, 'lu');
      expect(cubit.state.customers, const [_luis]);
      verifyNever(() => customers.search('l'));
    });

    test('reports a failed search', () async {
      when(() => customers.search('')).thenThrow(const ApiException(CoreTexts.networkError));
      final cubit = CustomerListCubit(customers: customers);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, CustomerListStatus.failure);
      expect(cubit.state.error, CoreTexts.networkError);
    });
  });

  group('customer detail', () {
    setUp(() {
      when(() => customers.get('c1')).thenAnswer((_) async => _ana);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const [_rosa, _pedro]);
      when(() => customers.stats('c1')).thenAnswer((_) async => const CustomerStats(remittances: 3, open: 1));
    });

    test('loads the customer, beneficiaries by name and stats', () async {
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.customer, _ana);
      expect(cubit.state.beneficiaries.map((b) => b.fullName), ['pedro', 'Rosa']);
      expect(cubit.state.stats?.remittances, 3);
    });

    test('works without stats when they fail or are not allowed', () async {
      when(() => customers.stats('c1')).thenThrow(const ApiException(CoreTexts.forbidden, statusCode: 403));
      final failing = CustomerDetailCubit(customers: customers, id: 'c1');
      final notAllowed = CustomerDetailCubit(customers: customers, id: 'c1', loadStats: false);
      addTearDown(failing.close);
      addTearDown(notAllowed.close);

      await failing.load();
      await notAllowed.load();

      expect(failing.state.status, CustomerDetailStatus.success);
      expect(failing.state.stats, isNull);
      expect(notAllowed.state.stats, isNull);
      verify(() => customers.stats('c1')).called(1);
    });

    test('adds and replaces saved beneficiaries', () async {
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);
      await cubit.load();

      cubit.beneficiarySaved(const Beneficiary(id: 'b3', fullName: 'Marta', phone: '535'));
      cubit.beneficiarySaved(const Beneficiary(id: 'b1', fullName: 'Rosa María', phone: '535'));

      expect(cubit.state.beneficiaries.map((b) => b.fullName), ['Marta', 'pedro', 'Rosa María']);
    });

    test('unlinks a beneficiary, or reports why it could not', () async {
      when(() => customers.unlinkBeneficiary('c1', 'b1')).thenAnswer((_) async {});
      when(() => customers.unlinkBeneficiary('c1', 'b2')).thenThrow(const ApiException(CoreTexts.forbidden));
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.unlink(_rosa);
      expect(cubit.state.beneficiaries, const [_pedro]);

      await cubit.unlink(_pedro);
      expect(cubit.state.beneficiaries, const [_pedro]);
      expect(cubit.state.actionError, CoreTexts.forbidden);
    });
  });
}
