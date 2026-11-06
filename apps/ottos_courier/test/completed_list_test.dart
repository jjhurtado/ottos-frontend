import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';

class _MockAuth extends Mock implements AuthRepository {}

Map<String, dynamic> _open(String id, {String? expected, bool late = false}) => {
  'id': id,
  'code': id,
  'type': 'DELIVERY',
  'status': 'ASSIGNED',
  'statusName': 'Asignada',
  'beneficiaryName': 'Open $id',
  'cashAmount': 100,
  'cashCurrency': 'USD',
  'expectedDate': ?expected,
  'late': late,
};

Map<String, dynamic> _done(String id, int minutesAgo) => {
  'id': id,
  'code': id,
  'type': 'DELIVERY',
  'status': 'DELIVERED',
  'statusName': 'Entregada',
  'beneficiaryName': 'Done $id',
  'cashAmount': 100,
  'cashCurrency': 'USD',
  'completedAt': DateTime.utc(2026, 11, 5, 12).subtract(Duration(minutes: minutesAgo)).toIso8601String(),
};

String _day(DateTime date) => date.toIso8601String().substring(0, 10);

/// The courier's source with the lists in memory (the real one, over SQLite, is
/// proved in offline/sync_cubit_test.dart): a delivery moves the card to the
/// top of the completed ones, unsent.
class _FakeSource implements RemittanceSource {
  _FakeSource({required this.open, required this.done});

  final List<Remittance> open;
  final List<Remittance> done;
  final _unsent = <String>{};

  @override
  bool get canShowCompleted => true;

  @override
  bool get completedAreLatest => true;

  @override
  Future<List<Remittance>> list() async => [...open];

  @override
  Future<PageResult<Remittance>> completed({int page = 0}) async =>
      PageResult(items: [...done], page: 0, size: 20, totalItems: done.length);

  @override
  Future<Set<String>> pendingIds() async => {..._unsent};

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> refresh() async {}

  @override
  Future<ActionOutcome> deliver(Remittance remittance, {String? pin, String? note}) async {
    open.removeWhere((r) => r.id == remittance.id);
    done.insert(0, Remittance.fromJson({..._done(remittance.id, 0), 'completedAt': DateTime.now().toIso8601String()}));
    _unsent.add(remittance.id);
    return const Queued();
  }

  @override
  Future<Remittance> get(String id) => throw UnimplementedError();

  @override
  Future<ActionOutcome> postpone(Remittance remittance, {required DateTime newDate, required String reason}) =>
      throw UnimplementedError();

  @override
  Future<ActionOutcome> reportIncident(Remittance remittance, {required IncidentReason reason, String? note}) =>
      throw UnimplementedError();
}

/// REQ-017: «Mis remesas» of the courier, with «Completadas».
void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    List<Map<String, dynamic>> open = const [],
    List<Map<String, dynamic>> completed = const [],
  }) async {
    // Tall, so every card is built.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _FakeSource(
      open: [for (final json in open) Remittance.fromJson(json)],
      done: [for (final json in completed) Remittance.fromJson(json)],
    );
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
            permissions: {
              Permissions.remittancesReadAssigned,
              Permissions.remittancesDeliver,
              Permissions.remittancesReportIncident,
            },
          ),
        ),
      );
    addTearDown(authBloc.close);
    await OttosLocalization.initialize();
    await tester.pumpWidget(
      RepositoryProvider<RemittanceSource>.value(
        value: source,
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

  Future<void> toggleCompleted(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
    await tester.pumpAndSettle();
  }

  final heading = find.text(CourierTexts.latestCompleted(OfflineStore.maxCompleted));

  double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

  testWidgets('AC-1.8 BR-5: «Completadas» is there for the courier, off, and only the open ones show', (tester) async {
    await pumpList(tester, open: [_open('OT-1')], completed: [_done('OT-9', 5)]);

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
    expect(chip.selected, isFalse);
    expect(find.text('OT-1'), findsOneWidget);
    expect(find.text('OT-9'), findsNothing);
    expect(heading, findsNothing);
  });

  testWidgets('AC-1.1: on, the heading and the completed ones come after the open ones, newest first', (tester) async {
    await pumpList(
      tester,
      open: [_open('OT-1'), _open('OT-2')],
      completed: [_done('OT-7', 30), _done('OT-8', 10), _done('OT-9', 20)],
    );

    await toggleCompleted(tester);

    expect(heading, findsOneWidget);
    final headingTop = tester.getTopLeft(heading).dy;
    expect(top(tester, 'OT-1'), lessThan(top(tester, 'OT-2')));
    expect(top(tester, 'OT-2'), lessThan(headingTop));
    expect(headingTop, lessThan(top(tester, 'OT-8')));
    expect(top(tester, 'OT-8'), lessThan(top(tester, 'OT-9')));
    expect(top(tester, 'OT-9'), lessThan(top(tester, 'OT-7')));
    expect(find.text(CourierTexts.showMore), findsNothing);

    await toggleCompleted(tester);
    expect(find.text('OT-8'), findsNothing, reason: 'off again');
    expect(heading, findsNothing);
  });

  testWidgets('«Más atrasadas primero» sorts the open block only', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await pumpList(
      tester,
      open: [
        _open('OT-A', expected: _day(today.add(const Duration(days: 1)))),
        _open('OT-B', expected: _day(today.subtract(const Duration(days: 5))), late: true),
      ],
      completed: [_done('OT-9', 5)],
    );
    await toggleCompleted(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, CourierTexts.sortMostLate));
    await tester.pumpAndSettle();

    expect(top(tester, 'OT-B'), lessThan(top(tester, 'OT-A')));
    expect(top(tester, 'OT-A'), lessThan(top(tester, 'OT-9')));
  });

  testWidgets('AC-1.6: a completed card cannot be swiped to deliver or report an incident', (tester) async {
    await pumpList(tester, completed: [_done('OT-9', 5)]);
    await toggleCompleted(tester);

    await tester.drag(find.text('OT-9'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.text('OT-9'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('OT-9'), findsOneWidget);
  });

  testWidgets('AC-2.2: a delivery made on the phone is the first completed card, «Sin enviar», not open too', (
    tester,
  ) async {
    await pumpList(tester, open: [_open('OT-1'), _open('OT-2')], completed: [_done('OT-9', 5)]);
    await toggleCompleted(tester);

    await tester.drag(find.text('OT-1'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    expect(find.text('OT-1'), findsOneWidget, reason: 'once, not in both blocks');
    expect(find.text(CourierTexts.unsent), findsOneWidget);
    expect(top(tester, 'OT-2'), lessThan(tester.getTopLeft(heading).dy));
    expect(tester.getTopLeft(heading).dy, lessThan(top(tester, 'OT-1')));
    expect(top(tester, 'OT-1'), lessThan(top(tester, 'OT-9')));
    final card = find.ancestor(of: find.text('OT-1'), matching: find.byType(Card));
    expect(tester.widget<Card>(card).color, OttosColors.completedSurface);
  });

  testWidgets('AC-1.4: nothing open and nothing completed: says so, with the option on or off', (tester) async {
    await pumpList(tester);

    expect(find.text(CourierTexts.noAssigned), findsOneWidget);
    await toggleCompleted(tester);

    expect(find.text(CourierTexts.noRemittances), findsOneWidget);
    expect(heading, findsNothing);
  });

  testWidgets('AC-1.4: nothing completed and some open: on, only the open ones, no heading', (tester) async {
    await pumpList(tester, open: [_open('OT-1')]);

    await toggleCompleted(tester);

    expect(find.text('OT-1'), findsOneWidget);
    expect(heading, findsNothing);
  });
}
