import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockApi extends Mock implements ApiClient {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRates extends Mock implements RateRepository {}

/// REQ-022 batch 1: optimizations of the shared package.
void main() {
  setUpAll(OttosLocalization.initialize);

  group('OPT-F1: Spanish-only localization delegates', () {
    testWidgets('Material, Cupertino and Widgets texts and dates are Spanish', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: OttosLocalization.locale,
          supportedLocales: OttosLocalization.supportedLocales,
          localizationsDelegates: OttosLocalization.delegates,
          home: Builder(
            builder: (inner) {
              context = inner;
              return const SizedBox();
            },
          ),
        ),
      );

      final material = MaterialLocalizations.of(context);
      expect(material, isA<MaterialLocalizationEs>());
      expect(material.cancelButtonLabel, 'Cancelar');
      expect(material.formatMediumDate(DateTime(2026, 11, 6)), 'vie, 6 nov');
      expect(material.formatMonthYear(DateTime(2026, 11, 6)), 'noviembre de 2026');
      expect(CupertinoLocalizations.of(context), isA<CupertinoLocalizationEs>());
      expect(WidgetsLocalizations.of(context), isA<WidgetsLocalizationEs>());
    });

    testWidgets('the date picker opens in Spanish', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: OttosLocalization.locale,
          supportedLocales: OttosLocalization.supportedLocales,
          localizationsDelegates: OttosLocalization.delegates,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 11, 6),
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('noviembre de 2026'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });

  group('OPT-F3: open remittances with their totals in one call', () {
    late _MockApi api;

    setUp(() {
      api = _MockApi();
      when(() => api.get<Map<String, dynamic>>('/remittance-workflow')).thenAnswer(
        (_) async => {
          'statuses': [
            {'code': 'PAID', 'position': 10},
            {'code': 'ASSIGNED', 'position': 20},
            {'code': 'DELIVERED', 'position': 30, 'isFinal': true},
          ],
        },
      );
    });

    test('asks the open ones, not voided, with the totals, and returns both', () async {
      when(() => api.get<Map<String, dynamic>>('/remittances', query: any(named: 'query'))).thenAnswer(
        (_) async => {
          'items': [
            {'id': 'a', 'code': 'OT-a', 'type': 'DELIVERY', 'status': 'PAID'},
          ],
          'page': 0,
          'size': 100,
          'totalItems': 1,
          'totals': {
            'toDeliver': [
              {'currency': 'USD', 'remittances': 1, 'amount': 100},
            ],
            'toCollect': [],
          },
        },
      );

      final (:page, :totals) = await RemittanceRepository(api: api).pending(size: 100);

      expect(page.items.single.code, 'OT-a');
      expect(totals!.toDeliver.single, const PendingAmount(currency: 'USD', remittances: 1, amount: 100));
      final query =
          verify(() => api.get<Map<String, dynamic>>('/remittances', query: captureAny(named: 'query'))).captured.single
              as Map<String, dynamic>;
      expect(query, containsPair('status', 'PAID,ASSIGNED'));
      expect(query, containsPair('voided', false));
      expect(query, containsPair('size', 100));
      expect(query, containsPair('totals', true));
    });

    test('a page without totals gives null totals, not an error', () async {
      when(() => api.get<Map<String, dynamic>>('/remittances', query: any(named: 'query')))
          .thenAnswer((_) async => {'items': [], 'totalItems': 0});

      final (:page, :totals) = await RemittanceRepository(api: api).pending(size: 100);

      expect(page.items, isEmpty);
      expect(totals, isNull);
    });
  });

  group('OPT-F2: new remittance from a customer', () {
    test('asks for the currencies without waiting for the customer', () async {
      final customers = _MockCustomers();
      final rates = _MockRates();
      final customer = Completer<Customer>();
      when(() => customers.get('c1')).thenAnswer((_) => customer.future);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
      when(() => rates.corridors()).thenAnswer((_) async => const []);
      final cubit = NewRemittanceCubit(remittances: _MockRemittances(), customers: customers, rates: rates);
      addTearDown(cubit.close);

      final load = cubit.load(customerId: 'c1');
      await Future<void>.delayed(Duration.zero);

      verify(() => rates.corridors()).called(1);
      expect(cubit.state.corridorsStatus, LoadStatus.success);
      customer.complete(const Customer(id: 'c1', fullName: 'Ana', phone: '+1305'));
      await load;
      expect(cubit.state.customer?.id, 'c1');
    });

    test('CR-1: the corridors fail, the customer arrives later: the error stays', () async {
      final customers = _MockCustomers();
      final rates = _MockRates();
      final customer = Completer<Customer>();
      when(() => customers.get('c1')).thenAnswer((_) => customer.future);
      when(() => customers.beneficiaries('c1')).thenAnswer((_) async => const []);
      when(() => rates.corridors()).thenThrow(const ApiException('Sin tasas'));
      final cubit = NewRemittanceCubit(remittances: _MockRemittances(), customers: customers, rates: rates);
      addTearDown(cubit.close);

      final load = cubit.load(customerId: 'c1');
      await Future<void>.delayed(Duration.zero);
      verify(() => rates.corridors()).called(1);
      customer.complete(const Customer(id: 'c1', fullName: 'Ana', phone: '+1305'));
      await load;
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.corridorsStatus, LoadStatus.failure);
      expect(cubit.state.error, 'Sin tasas');
      expect(cubit.state.customer, isNull);

      // «Reintentar» calls load() without the customer: it still starts with it.
      when(() => rates.corridors()).thenAnswer((_) async => const []);
      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.corridorsStatus, LoadStatus.success);
      expect(cubit.state.customer?.id, 'c1');
    });
  });
}
