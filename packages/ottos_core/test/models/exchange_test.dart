import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('the rate is always CUP per 1 USD, in both directions', () {
    const usdToCup = ExchangeInput(fromCurrency: 'USD', fromAmount: 100, toCurrency: 'CUP', rate: 480);
    const cupToUsd = ExchangeInput(fromCurrency: 'CUP', fromAmount: 100000, toCurrency: 'USD', rate: 480);

    expect(usdToCup.toAmount, 48000);
    expect(cupToUsd.toAmount, 208.33);
    expect(const ExchangeInput(fromCurrency: 'CUP', fromAmount: 1, toCurrency: 'USD', rate: 8).toAmount, 0.13);
  });

  test('reads an exchange and whether its review is still pending', () {
    final exchange = CurrencyExchange.fromJson({
      'id': 'e1',
      'courierName': 'Luis',
      'fromCurrency': 'USD',
      'fromAmount': 10.00,
      'toCurrency': 'CUP',
      'toAmount': 4800.00,
      'rate': 480.0,
      'configuredRate': 760.0,
      'deviationPercent': 36.84,
      'review': {'reason': 'UNUSUAL_EXCHANGE_RATE', 'flaggedAt': '2026-10-11T16:00:06Z', 'resolvedAt': null},
    });

    expect(exchange.pendingReview, isTrue);
    expect(exchange.review!.reason, ReviewReason.unusualExchangeRate);
    expect(exchange.deviationPercent, 36.84);
  });

  test('movements carry the exchange they belong to', () {
    final movement = CashMovement.fromJson({
      'id': 'm1',
      'type': 'COURIER_EXCHANGE_OUT',
      'amount': 10,
      'signedAmount': -10,
      'currency': 'USD',
      'exchangeId': 'e1',
      'rate': 480,
    });

    expect(movement.type, CashMovementType.courierExchangeOut);
    expect(movement.exchangeId, 'e1');
    expect(movement.rate, 480);
  });

  testWidgets('the dialog shows what is received and returns the exchange', (tester) async {
    ExchangeInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              TextButton(onPressed: () async => result = await showExchangeDialog(context), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.exchangeAmount), '100');
    await tester.enterText(find.widgetWithText(TextFormField, CoreTexts.exchangeRate), '480');
    await tester.pump();
    expect(find.textContaining('48.000,00 CUP'), findsOneWidget);

    await tester.tap(find.text('CUP → USD'));
    await tester.pump();
    expect(find.textContaining('0,21 USD'), findsOneWidget);

    await tester.tap(find.text(CoreTexts.exchangeConfirm));
    await tester.pumpAndSettle();

    expect(result, const ExchangeInput(fromCurrency: 'CUP', fromAmount: 100, toCurrency: 'USD', rate: 480, note: ''));
  });
}
