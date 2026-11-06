import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/customers/cubit/customer_detail_cubit.dart';
import 'package:ottos_ops/features/home/cubit/home_cubit.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'initial': true, 'position': 10},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20},
    {'code': 'DELIVERED', 'name': 'Entregada', 'isFinal': true, 'position': 30},
  ],
});

PageResult<T> _count<T>(int total) => PageResult<T>(items: const [], page: 0, size: 1, totalItems: total);

/// REQ-022 batch 1: the panel's independent calls in parallel (OPT-F2) and the
/// Home status tiles without voided remittances.
void main() {
  setUpAll(() => registerFallbackValue(const RemittanceFilter()));

  group('Home', () {
    late _MockRemittances remittances;
    late _MockCash cash;

    setUp(() {
      remittances = _MockRemittances();
      cash = _MockCash();
      when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
      when(() => remittances.search(any(), size: 1)).thenAnswer((_) async => _count(2));
      when(() => remittances.pendingTotals()).thenAnswer((_) async => const PendingTotals());
      when(() => cash.exchanges(review: true, size: 1)).thenAnswer((_) async => _count(1));
    });

    test('OPT-F2: exchanges and money pending start without waiting for the workflow', () async {
      final workflow = Completer<Workflow>();
      when(() => remittances.workflow()).thenAnswer((_) => workflow.future);
      final cubit = HomeCubit(remittances: remittances, cash: cash);
      addTearDown(cubit.close);

      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);

      verify(() => cash.exchanges(review: true, size: 1)).called(1);
      verify(() => remittances.pendingTotals()).called(1);
      verifyNever(() => remittances.search(any(), size: 1));
      workflow.complete(_workflow);
      await load;

      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.exchangesToReview, 1);
      expect(cubit.state.pending, const PendingTotals());
    });

    test('voided remittances do not count in the status tiles', () async {
      final cubit = HomeCubit(remittances: remittances);
      addTearDown(cubit.close);

      await cubit.load();

      verify(() => remittances.search(const RemittanceFilter(status: 'PAID', voided: false), size: 1)).called(1);
      verify(() => remittances.search(const RemittanceFilter(status: 'ASSIGNED', voided: false), size: 1)).called(1);
      verifyNever(() => remittances.search(const RemittanceFilter(status: 'PAID'), size: 1));
      expect(cubit.state.openByStatus.map((item) => item.count), [2, 2]);
    });

    test('AC-1.8 (REQ-021): the money pending still fails on its own', () async {
      when(() => remittances.pendingTotals()).thenThrow(const ApiException('Sin totales'));
      final cubit = HomeCubit(remittances: remittances, cash: cash);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.pending, isNull);
      expect(cubit.state.pendingError, 'Sin totales');
    });

    test('a failed counter fails the Home, and the money pending is not shown', () async {
      when(() => cash.exchanges(review: true, size: 1)).thenThrow(const ApiException('Error'));
      final cubit = HomeCubit(remittances: remittances, cash: cash);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, HomeStatus.failure);
      expect(cubit.state.pending, isNull);
    });
  });

  group('customer detail', () {
    test('OPT-F2: the numbers are asked with the customer, not after it', () async {
      final customers = _MockCustomers();
      final customer = Completer<Customer>();
      when(() => customers.get('c1')).thenAnswer((_) => customer.future);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
      when(() => customers.stats('c1')).thenAnswer((_) async => const CustomerStats(remittances: 3));
      final cubit = CustomerDetailCubit(customers: customers, id: 'c1');
      addTearDown(cubit.close);

      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);

      verify(() => customers.stats('c1')).called(1);
      customer.complete(const Customer(id: 'c1', fullName: 'Ana', phone: '+1305'));
      await load;
      expect(cubit.state.status, CustomerDetailStatus.success);
      expect(cubit.state.stats, const CustomerStats(remittances: 3));
    });
  });
}
