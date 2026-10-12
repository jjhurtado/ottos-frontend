import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('reads the open incident of a remittance', () {
    final remittance = Remittance.fromJson({
      'id': 'r1',
      'code': 'OT-1',
      'type': 'DELIVERY',
      'status': 'ASSIGNED',
      'incident': {
        'reason': 'NOT_HOME',
        'note': 'Nadie abrió',
        'reportedAt': '2026-10-10T10:49:00Z',
        'reportedBy': 'Repartidor Prueba',
      },
    });

    expect(remittance.incident!.reason, IncidentReason.notHome);
    expect(remittance.incident!.note, 'Nadie abrió');
    expect(remittance.incident!.reportedAt, isNotNull);
    expect(remittance.incident!.reportedBy, 'Repartidor Prueba');
  });

  test('a remittance without incident has none', () {
    final remittance = Remittance.fromJson({'id': 'r1', 'code': 'OT-1', 'type': 'DELIVERY', 'status': 'PAID'});

    expect(remittance.incident, isNull);
  });

  test('an unknown reason falls back to other', () {
    expect(IncidentReason.fromCode('NEW_REASON'), IncidentReason.other);
    expect(IncidentReason.fromCode('REFUSED'), IncidentReason.refused);
  });

  test('the history reads the reason of a reported incident', () {
    final event = RemittanceEvent.fromJson({
      'id': 'e1',
      'type': 'INCIDENT_REPORTED',
      'incidentReason': 'WRONG_ADDRESS',
      'occurredAt': '2026-10-10T10:49:00Z',
    });

    expect(event.incidentReason, IncidentReason.wrongAddress);
  });

  test('the list can be filtered by incident', () {
    const filter = RemittanceFilter(incident: true);

    expect(filter.toQuery()['incident'], isTrue);
    expect(filter.isEmpty, isFalse);
    expect(filter.copyWith(incident: null).isEmpty, isTrue);
  });
}
