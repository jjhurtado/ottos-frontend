import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

Remittance _remittance(String code, RemittanceType type, {Incident? incident}) => Remittance(
  id: code,
  code: code,
  type: type,
  status: 'ASSIGNED',
  statusName: 'Asignada',
  courierId: 'c1',
  beneficiaryName: 'Rosa',
  beneficiaryAddress: 'Calle 1, Boyeros, La Habana',
  municipalityName: 'Boyeros',
  cashAmount: 100,
  cashCurrency: 'USD',
  incident: incident,
);

void main() {
  testWidgets('deliveries and pickups look different, and the address is not repeated', (tester) async {
    final remittances = _MockRemittances();
    when(() => remittances.assignedToMe()).thenAnswer(
      (_) async => [_remittance('OT-1', RemittanceType.delivery), _remittance('OT-2', RemittanceType.pickup)],
    );
    await OttosLocalization.initialize();
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: remittances,
        child: const MaterialApp(home: Scaffold(body: AssignedPage())),
      ),
    );
    await tester.pumpAndSettle();

    final delivery = find.widgetWithText(RemittanceTypeBadge, CoreTexts.delivery);
    final pickup = find.widgetWithText(RemittanceTypeBadge, CoreTexts.pickup);
    expect(delivery, findsOneWidget);
    expect(pickup, findsOneWidget);
    expect(
      tester.widget<Text>(find.descendant(of: delivery, matching: find.byType(Text))).style?.color,
      OttosColors.delivery,
    );
    expect(
      tester.widget<Text>(find.descendant(of: pickup, matching: find.byType(Text))).style?.color,
      OttosColors.pickup,
    );
    expect(find.text('Calle 1, Boyeros, La Habana'), findsNWidgets(2));
    expect(find.textContaining('La Habana, Boyeros'), findsNothing);
  });

  testWidgets('a remittance with an incident is marked in the list', (tester) async {
    final remittances = _MockRemittances();
    when(() => remittances.assignedToMe()).thenAnswer(
      (_) async => [
        _remittance('OT-1', RemittanceType.delivery, incident: const Incident(reason: IncidentReason.notHome)),
        _remittance('OT-2', RemittanceType.pickup),
      ],
    );
    await OttosLocalization.initialize();
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: remittances,
        child: const MaterialApp(home: Scaffold(body: AssignedPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IncidentBadge), findsOneWidget);
    expect(find.textContaining(CoreTexts.incidentReason(IncidentReason.notHome)), findsOneWidget);
  });
}
