import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

final _full = Remittance(
  id: 'r1',
  code: 'OT-VKK5RX',
  type: RemittanceType.delivery,
  status: 'ASSIGNED',
  statusName: 'Asignada',
  customerName: 'Sender Test',
  customerPhone: '+13055550001',
  beneficiaryName: 'Rosa Pérez',
  beneficiaryPhone: '+5352000001',
  beneficiaryAlternatePhone: '+5352000002',
  beneficiaryAddress: 'Calle 23 #456',
  municipalityName: 'Plaza',
  beneficiaryReference: 'Casa azul',
  sourceCurrency: 'USD',
  targetCurrency: 'CUP',
  amount: 100,
  fee: 10,
  total: 110,
  amountToDeliver: 36000,
  cashAmount: 36000,
  cashCurrency: 'CUP',
  pin: '4821',
  expectedDate: DateTime(2026, 11, 14),
);

void main() {
  group('remittanceShareText', () {
    test('REQ-025 BR-2: lists code and type, beneficiary, phones, address, reference, amount and date', () {
      expect(
        remittanceShareText(_full),
        'Remesa OT-VKK5RX · Entrega a domicilio\n'
        'Beneficiario: Rosa Pérez\n'
        'Teléfono: +5352000001 / +5352000002\n'
        'Dirección: Calle 23 #456, Plaza\n'
        'Referencia: Casa azul\n'
        'Entregar: ${Formatters.money(36000, 'CUP')}\n'
        'Fecha prevista: 14/11/2026',
      );
    });

    test('REQ-025 BR-3: never has the PIN, the sender, the fee or the total', () {
      final text = remittanceShareText(_full);
      expect(text, isNot(contains('4821')));
      expect(text, isNot(contains('Sender Test')));
      expect(text, isNot(contains('+13055550001')));
      expect(text, isNot(contains(Formatters.money(110, 'USD'))));
      expect(text, isNot(contains(Formatters.money(10, 'USD'))));
    });

    test('REQ-025 BR-2: empty fields are left out', () {
      const bare = Remittance(
        id: 'r2',
        code: 'OT-2',
        type: RemittanceType.delivery,
        status: 'PAID',
        statusName: 'Pagada',
        beneficiaryName: '  ',
        beneficiaryPhone: '+5352000001',
        beneficiaryAlternatePhone: '',
        municipalityName: 'Plaza',
      );
      expect(remittanceShareText(bare), 'Remesa OT-2 · Entrega a domicilio\nTeléfono: +5352000001\nDirección: Plaza');
    });

    test('REQ-025 BR-2: a pickup says Recogida and what to collect', () {
      const pickup = Remittance(
        id: 'r3',
        code: 'OT-3',
        type: RemittanceType.pickup,
        status: 'PAID',
        statusName: 'Pagada',
        beneficiaryName: 'Ana',
        cashAmount: 50,
        cashCurrency: 'USD',
      );
      expect(
        remittanceShareText(pickup),
        'Remesa OT-3 · Recogida\nBeneficiario: Ana\nRecoger: ${Formatters.money(50, 'USD')}',
      );
    });

    test('REQ-025 AC-1.4: a voided remittance starts with ANULADA', () {
      const voided = Remittance(
        id: 'r4',
        code: 'OT-4',
        type: RemittanceType.delivery,
        status: 'PAID',
        statusName: 'Pagada',
        voided: Voided(reason: 'Duplicada'),
      );
      expect(remittanceShareText(voided).split('\n').first, 'ANULADA');
    });

    test('REQ-025 BR-2: an expected date sent as an instant uses the business calendar', () {
      // 02:00 UTC is still the 13th at UTC−4.
      final remittance = Remittance(
        id: 'r5',
        code: 'OT-5',
        type: RemittanceType.delivery,
        status: 'PAID',
        statusName: 'Pagada',
        expectedDate: DateTime.utc(2026, 11, 14, 2),
      );
      expect(remittanceShareText(remittance), endsWith('Fecha prevista: 13/11/2026'));
    });
  });

  group('who did what (REQ-024)', () {
    test('AC-1.1: an event reads its author', () {
      final event = RemittanceEvent.fromJson(const {
        'id': 'e1',
        'type': 'CREATED',
        'actorId': 'u1',
        'actorName': 'Ana',
      });
      expect(event.actorName, 'Ana');
    });

    test('AC-1.2: a remittance reads who completed it', () {
      final remittance = Remittance.fromJson(const {'id': 'r1', 'completedByName': 'Luis'});
      expect(remittance.completedByName, 'Luis');
    });

    test('AC-2.3: a movement reads its author and remittance code', () {
      final movement = CashMovement.fromJson(const {
        'id': 'm1',
        'type': 'DELIVERY_PAYOUT',
        'amount': 10,
        'currency': 'USD',
        'actorName': 'Ana',
        'remittanceId': 'r1',
        'remittanceCode': 'OT-1',
      });
      expect(movement.actorName, 'Ana');
      expect(movement.remittanceCode, 'OT-1');
    });

    test('AC-2.2: the filter sends dates as days and the type by code', () {
      final filter = MovementFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 13),
        type: CashMovementType.deliveryPayout,
      );
      expect(filter.toQuery(), {'from': '2026-11-01', 'to': '2026-11-13', 'type': 'DELIVERY_PAYOUT'});
      expect(const MovementFilter().isEmpty, isTrue);
      expect(filter.copyWith(type: null).type, isNull);
    });
  });
}
