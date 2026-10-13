import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockCustomers extends Mock implements CustomerRepository {}

const _ana = Customer(id: 'c1', fullName: 'Ana', phone: '5551234');

void main() {
  late _MockCustomers customers;

  setUp(() => customers = _MockCustomers());

  Future<void> open(WidgetTester tester, Future<void> Function(BuildContext) show) async {
    await tester.pumpWidget(
      RepositoryProvider<CustomerRepository>.value(
        value: customers,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => show(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(find.widgetWithText(TextFormField, label)).controller!.text;

  test('contact phones keep only digits and a leading +', () {
    expect(cleanContactPhone(' +53 5 123-45.67 '), '+5351234567');
    expect(cleanContactPhone('(305) 555 0100'), '3055550100');
  });

  testWidgets('a new customer takes name and phone from the chosen contact', (tester) async {
    await open(
      tester,
      (context) => showCustomerFormDialog(
        context,
        title: 'Nuevo remitente',
        pickContact: () async => const PickedContact(name: ' Rosa Pérez ', phone: '+53 5 123 4567'),
      ),
    );
    expect(find.text('Nuevo remitente'), findsOneWidget);

    await tester.tap(find.text(CoreTexts.pickFromContacts));
    await tester.pumpAndSettle();

    expect(fieldText(tester, '${CoreTexts.fullName} *'), 'Rosa Pérez');
    expect(fieldText(tester, '${CoreTexts.phone} *'), '+5351234567');
  });

  testWidgets('a cancelled pick leaves the form as it was', (tester) async {
    await open(tester, (context) => showCustomerFormDialog(context, pickContact: () async => null));
    await tester.enterText(find.widgetWithText(TextFormField, '${CoreTexts.fullName} *'), 'Ana');

    await tester.tap(find.text(CoreTexts.pickFromContacts));
    await tester.pumpAndSettle();

    expect(fieldText(tester, '${CoreTexts.fullName} *'), 'Ana');
  });

  testWidgets('without a picker, or when editing, there is no contacts button', (tester) async {
    await open(tester, (context) => showCustomerFormDialog(context));
    expect(find.text(CoreTexts.newCustomer), findsOneWidget);
    expect(find.text(CoreTexts.pickFromContacts), findsNothing);
    await tester.tap(find.text(CoreTexts.cancel));
    await tester.pumpAndSettle();

    await open(tester, (context) => showCustomerFormDialog(context, customer: _ana, pickContact: () async => null));
    expect(find.text(CoreTexts.editCustomer), findsOneWidget);
    expect(find.text(CoreTexts.pickFromContacts), findsNothing);
  });
}
