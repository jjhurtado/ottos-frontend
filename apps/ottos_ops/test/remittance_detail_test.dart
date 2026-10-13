import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/remittances/cubit/remittance_detail_cubit.dart';
import 'package:ottos_ops/features/remittances/view/remittance_detail_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20, 'requiresCourier': true},
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
  ],
  'transitions': [
    {'from': 'PAID', 'to': 'ASSIGNED', 'permission': Permissions.remittancesAssign},
    {'from': 'ASSIGNED', 'to': 'ASSIGNED', 'permission': Permissions.remittancesAssign},
    {'from': 'ASSIGNED', 'to': 'DELIVERED', 'permission': Permissions.remittancesDeliver},
  ],
});

Remittance _remittance(String status, {String? courierId, Incident? incident, Review? review, Voided? voided}) =>
    Remittance(
      id: 'r1',
      code: 'OT-1',
      type: RemittanceType.delivery,
      status: status,
      statusName: _workflow.nameOf(status),
      courierId: courierId,
      incident: incident,
      review: review,
      voided: voided,
    );

CurrentUser _user(Set<String> permissions) =>
    CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: 'STAFF', roles: const [], permissions: permissions);

void main() {
  late _MockRemittances remittances;

  setUp(() {
    remittances = _MockRemittances();
    when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
    when(() => remittances.events('r1')).thenAnswer((_) async => const []);
  });

  group('actions shown', () {
    Future<void> pumpDetail(WidgetTester tester, Remittance remittance, Set<String> permissions) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => remittance);
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)..add(AuthLoggedIn(_user(permissions)));
      addTearDown(authBloc.close);
      await tester.pumpWidget(
        RepositoryProvider<RemittanceRepository>.value(
          value: remittances,
          child: BlocProvider.value(
            value: authBloc,
            child: MaterialApp(
              localizationsDelegates: OttosLocalization.delegates,
              supportedLocales: OttosLocalization.supportedLocales,
              home: const Scaffold(body: RemittanceDetailPage(remittanceId: 'r1')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const all = {Permissions.remittancesAssign, Permissions.remittancesDeliver, Permissions.remittancesPostpone};

    testWidgets('a paid remittance can be assigned and postponed', (tester) async {
      await pumpDetail(tester, _remittance('PAID'), all);

      expect(find.text(OpsTexts.assignCourier), findsOneWidget);
      expect(find.text(CoreTexts.postpone), findsOneWidget);
      expect(find.text(OpsTexts.markDelivered), findsNothing);
    });

    testWidgets('an assigned remittance can be reassigned and delivered', (tester) async {
      await pumpDetail(tester, _remittance('ASSIGNED', courierId: 'k1'), all);

      expect(find.text(OpsTexts.reassignCourier), findsOneWidget);
      expect(find.text(OpsTexts.markDelivered), findsOneWidget);
    });

    testWidgets('a delivered remittance has no actions', (tester) async {
      await pumpDetail(tester, _remittance('DELIVERED', courierId: 'k1'), all);

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('a read-only user sees no actions', (tester) async {
      await pumpDetail(tester, _remittance('ASSIGNED', courierId: 'k1'), {Permissions.remittancesRead});

      expect(find.text(OpsTexts.reassignCourier), findsNothing);
      expect(find.text(OpsTexts.markDelivered), findsNothing);
      expect(find.text(CoreTexts.postpone), findsNothing);
    });

    const withIncidents = {...all, Permissions.remittancesReportIncident};

    testWidgets('an incident can be reported once a courier has the remittance', (tester) async {
      await pumpDetail(tester, _remittance('ASSIGNED', courierId: 'k1'), withIncidents);

      expect(find.text(CoreTexts.reportIncident), findsOneWidget);
    });

    testWidgets('no incident before a courier is assigned', (tester) async {
      await pumpDetail(tester, _remittance('PAID'), withIncidents);
      expect(find.text(CoreTexts.reportIncident), findsNothing);
    });

    testWidgets('no incident without the permission', (tester) async {
      await pumpDetail(tester, _remittance('ASSIGNED', courierId: 'k1'), all);
      expect(find.text(CoreTexts.reportIncident), findsNothing);
    });

    testWidgets('a remittance under review is resolved with a note', (tester) async {
      const review = Review(reason: ReviewReason.pinMismatch);
      when(() => remittances.resolveReview('r1', note: 'El beneficiario confirmó la entrega'))
          .thenAnswer((_) async => _remittance('DELIVERED', courierId: 'k1'));
      await pumpDetail(tester, _remittance('DELIVERED', courierId: 'k1', review: review), {
        Permissions.remittancesRead,
        Permissions.remittancesReview,
      });
      expect(find.textContaining(CoreTexts.reviewReason(ReviewReason.pinMismatch)), findsOneWidget);

      await tester.tap(find.text(OpsTexts.resolve));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OpsTexts.resolve)));
      await tester.pumpAndSettle();
      expect(find.text(CoreTexts.requiredField), findsOneWidget, reason: 'the note is required');

      await tester.enterText(find.byType(TextFormField), 'El beneficiario confirmó la entrega');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OpsTexts.resolve)));
      await tester.pumpAndSettle();

      verify(() => remittances.resolveReview('r1', note: 'El beneficiario confirmó la entrega')).called(1);
      expect(find.byType(ReviewBanner), findsNothing);
    });

    testWidgets('an admin voids a delivered remittance with a required reason', (tester) async {
      final voided = _remittance(
        'DELIVERED',
        courierId: 'k1',
        voided: const Voided(reason: 'Era una entrega de efectivo', byName: 'Administrator'),
      );
      when(() => remittances.voidRemittance('r1', reason: 'Era una entrega de efectivo'))
          .thenAnswer((_) async => voided);
      await pumpDetail(tester, _remittance('DELIVERED', courierId: 'k1'), {...all, Permissions.remittancesVoid});

      await tester.tap(find.text(OpsTexts.voidAction));
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.voidHelp), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OpsTexts.voidAction)));
      await tester.pumpAndSettle();
      expect(find.text(CoreTexts.requiredField), findsOneWidget, reason: 'the reason is required');

      await tester.enterText(find.byType(TextFormField), 'Era una entrega de efectivo');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(OpsTexts.voidAction)));
      await tester.pumpAndSettle();

      verify(() => remittances.voidRemittance('r1', reason: 'Era una entrega de efectivo')).called(1);
      expect(find.text(CoreTexts.voidedBy('Administrator')), findsOneWidget);
      expect(find.text(CoreTexts.voided), findsOneWidget, reason: 'the status chip says it is voided');
      expect(find.text(OpsTexts.voidAction), findsNothing, reason: 'it cannot be voided twice');
    });

    testWidgets('a voided remittance shows why and allows nothing', (tester) async {
      await pumpDetail(
        tester,
        _remittance(
          'ASSIGNED',
          courierId: 'k1',
          incident: const Incident(reason: IncidentReason.notHome),
          voided: const Voided(reason: 'Duplicada'),
        ),
        {...all, Permissions.remittancesReportIncident, Permissions.remittancesVoid},
      );

      expect(find.byType(VoidedBanner), findsOneWidget);
      expect(find.text('${CoreTexts.voidReason}: Duplicada'), findsOneWidget);
      expect(find.byType(IncidentBanner), findsNothing);
      expect(find.text(OpsTexts.reassignCourier), findsNothing);
      expect(find.text(OpsTexts.markDelivered), findsNothing);
      expect(find.text(CoreTexts.postpone), findsNothing);
      expect(find.text(OpsTexts.voidAction), findsNothing);
    });

    testWidgets('only who has the permission can void', (tester) async {
      await pumpDetail(tester, _remittance('PAID'), all);
      expect(find.text(OpsTexts.voidAction), findsNothing);
    });

    testWidgets('without the permission the review is shown but not resolved', (tester) async {
      await pumpDetail(
        tester,
        _remittance(
          'DELIVERED',
          courierId: 'k1',
          review: const Review(reason: ReviewReason.lateSync),
        ),
        {Permissions.remittancesRead},
      );

      expect(find.byType(ReviewBanner), findsOneWidget);
      expect(find.text(OpsTexts.resolve), findsNothing);
    });

    testWidgets('the reported incident is shown', (tester) async {
      const incident = Incident(reason: IncidentReason.refused, note: 'No quiere el dinero');
      await pumpDetail(tester, _remittance('ASSIGNED', courierId: 'k1', incident: incident), all);

      expect(find.byType(IncidentBanner), findsOneWidget);
      expect(find.textContaining(CoreTexts.incidentReason(IncidentReason.refused)), findsOneWidget);
      expect(find.text('No quiere el dinero'), findsOneWidget);
    });
  });

  group('cubit', () {
    late RemittanceDetailCubit cubit;

    setUp(() async {
      when(() => remittances.get('r1')).thenAnswer((_) async => _remittance('PAID'));
      cubit = RemittanceDetailCubit(remittances: remittances, id: 'r1');
      await cubit.load();
    });

    tearDown(() => cubit.close());

    test('assigning updates the remittance and reloads the history', () async {
      when(() => remittances.assign('r1', courierId: 'k1', note: null))
          .thenAnswer((_) async => _remittance('ASSIGNED', courierId: 'k1'));

      await cubit.assign(courierId: 'k1');

      expect(cubit.state.action, RemittanceAction.assigned);
      expect(cubit.state.remittance!.status, 'ASSIGNED');
      expect(cubit.state.submitting, isFalse);
      verify(() => remittances.events('r1')).called(2);
    });

    test('reporting an incident updates the remittance', () async {
      const incident = Incident(reason: IncidentReason.notHome);
      when(() => remittances.reportIncident('r1', reason: IncidentReason.notHome, note: null))
          .thenAnswer((_) async => _remittance('ASSIGNED', courierId: 'k1', incident: incident));

      await cubit.reportIncident(reason: IncidentReason.notHome);

      expect(cubit.state.action, RemittanceAction.incidentReported);
      expect(cubit.state.remittance!.incident, incident);
    });

    test('a rejected action keeps the remittance and reports the error', () async {
      when(() => remittances.deliverWithPin('r1', pin: '1', note: null))
          .thenThrow(const ApiException('Wrong PIN', statusCode: 422));

      await cubit.complete(pin: '1');

      expect(cubit.state.action, RemittanceAction.failed);
      expect(cubit.state.actionError, 'Wrong PIN');
      expect(cubit.state.remittance!.status, 'PAID');
    });

    test('the action still counts when only the history reload fails', () async {
      when(() => remittances.deliver('r1', note: null))
          .thenAnswer((_) async => _remittance('DELIVERED', courierId: 'k1'));
      when(() => remittances.events('r1')).thenThrow(const ApiException(CoreTexts.networkError));

      await cubit.complete();

      expect(cubit.state.action, RemittanceAction.completed);
      expect(cubit.state.remittance!.status, 'DELIVERED');
    });
  });
}
