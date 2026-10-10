import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/cubit/assigned_cubit.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

Remittance _remittance(
  String code,
  RemittanceType type, {
  Incident? incident,
  DateTime? expectedDate,
  bool late = false,
}) => Remittance(
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
  expectedDate: expectedDate,
  late: late,
);

void main() {
  late _MockRemittances remittances;

  setUp(() => remittances = _MockRemittances());

  Future<void> pumpList(WidgetTester tester, List<Remittance> items) async {
    when(() => remittances.assignedToMe()).thenAnswer((_) async => items);
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        const AuthLoggedIn(
          CurrentUser(
            id: 'c1',
            email: 'c@ottos.test',
            name: 'Repartidor',
            type: 'COURIER',
            roles: [],
            permissions: {Permissions.remittancesDeliver, Permissions.remittancesPostpone},
          ),
        ),
      );
    addTearDown(authBloc.close);
    await OttosLocalization.initialize();
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: remittances,
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const Scaffold(body: AssignedPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deliveries and pickups look different, and the address is not repeated', (tester) async {
    await pumpList(tester, [_remittance('OT-1', RemittanceType.delivery), _remittance('OT-2', RemittanceType.pickup)]);

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
    await pumpList(tester, [
      _remittance('OT-1', RemittanceType.delivery, incident: const Incident(reason: IncidentReason.notHome)),
      _remittance('OT-2', RemittanceType.pickup),
    ]);

    expect(find.byType(IncidentBadge), findsOneWidget);
    expect(find.textContaining(CoreTexts.incidentReason(IncidentReason.notHome)), findsOneWidget);
  });

  testWidgets('a late remittance says how many days late it is', (tester) async {
    final threeDaysAgo = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 3));
    await pumpList(tester, [_remittance('OT-1', RemittanceType.delivery, expectedDate: threeDaysAgo, late: true)]);

    expect(find.text(CourierTexts.daysLate(3)), findsOneWidget);
  });

  testWidgets('swiping right asks to confirm, then completes and reloads', (tester) async {
    when(() => remittances.deliver('OT-1', note: null))
        .thenAnswer((_) async => _remittance('OT-1', RemittanceType.delivery));
    await pumpList(tester, [_remittance('OT-1', RemittanceType.delivery)]);

    await tester.drag(find.text('OT-1'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    verifyNever(() => remittances.deliver(any(), note: any(named: 'note')));

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    verify(() => remittances.deliver('OT-1', note: null)).called(1);
    verify(() => remittances.assignedToMe()).called(2);
    expect(find.text(CourierTexts.completed), findsOneWidget);
  });

  testWidgets('swiping left asks to postpone; cancelling keeps the remittance', (tester) async {
    await pumpList(tester, [_remittance('OT-1', RemittanceType.delivery)]);

    await tester.drag(find.text('OT-1'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.postponeTitle), findsOneWidget);

    await tester.tap(find.text(CoreTexts.cancel));
    await tester.pumpAndSettle();

    expect(find.text('OT-1'), findsOneWidget);
    verifyNever(
      () => remittances.postpone(
        any(),
        newDate: any(named: 'newDate'),
        reason: any(named: 'reason'),
      ),
    );
  });

  group('order', () {
    final now = DateTime(2026, 10, 10, 12);
    final onTime = _remittance('OT-A', RemittanceType.delivery, expectedDate: DateTime(2026, 10, 11));
    final today = _remittance('OT-B', RemittanceType.delivery, expectedDate: DateTime(2026, 10, 10));
    final withIncident = _remittance(
      'OT-C',
      RemittanceType.delivery,
      expectedDate: DateTime(2026, 10, 10),
      incident: const Incident(reason: IncidentReason.notHome),
    );
    final oneDayLate = _remittance('OT-D', RemittanceType.delivery, expectedDate: DateTime(2026, 10, 9), late: true);
    final fiveDaysLate = _remittance('OT-E', RemittanceType.pickup, expectedDate: DateTime(2026, 10, 5), late: true);
    final all = [fiveDaysLate, withIncident, onTime, oneDayLate, today];

    List<String> codes(AssignedSort sort) => AssignedState.sorted(all, sort, now: now).map((r) => r.code).toList();

    test('the day puts late remittances and incidents last', () {
      expect(codes(AssignedSort.byDay), ['OT-B', 'OT-A', 'OT-E', 'OT-D', 'OT-C']);
    });

    test('most late first, by whole days', () {
      expect(codes(AssignedSort.mostLate), ['OT-E', 'OT-D', 'OT-B', 'OT-C', 'OT-A']);
    });
  });
}
