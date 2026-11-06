import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

// REQ-020: completed remittances look different in the app's lists and detail.
// Expected results come from 01-user-stories.md (AC-1.1 to AC-1.4, BR-1, BR-2).

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _sales = {
  Permissions.remittancesRead,
  Permissions.remittancesCreate,
  Permissions.remittancesAssign,
  Permissions.cashRead,
  Permissions.configurationRead,
  Permissions.customersRead,
};

const _courier = {Permissions.remittancesReadAssigned, Permissions.remittancesDeliver, Permissions.cashReadOwn};

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
    {'code': 'PICKED_UP', 'name': 'Recogida', 'position': 31, 'isFinal': true},
  ],
  'transitions': const [],
});

Remittance _open(String code, {RemittanceType type = RemittanceType.delivery}) => Remittance(
  id: code,
  code: code,
  type: type,
  status: 'PAID',
  statusName: 'Pagada',
  beneficiaryName: 'Abierta $code',
  cashAmount: 100,
  cashCurrency: 'USD',
);

Remittance _done(String code, {RemittanceType type = RemittanceType.delivery, Voided? voided}) => Remittance(
  id: code,
  code: code,
  type: type,
  status: type == RemittanceType.pickup ? 'PICKED_UP' : 'DELIVERED',
  statusName: type == RemittanceType.pickup ? 'Recogida' : 'Entregada',
  beneficiaryName: 'Hecha $code',
  cashAmount: 100,
  cashCurrency: 'USD',
  completedAt: DateTime.utc(2026, 10, 12, 20, 40),
  voided: voided,
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late _MockRemittances remittances;

  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    await OttosLocalization.initialize();
  });

  setUp(() => remittances = _MockRemittances());

  Future<void> pump(WidgetTester tester, Set<String> permissions, Widget page) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: '', roles: const [], permissions: permissions),
        ),
      );
    addTearDown(authBloc.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<RemittanceSource>.value(
            value: OnlineSource(
              remittances: remittances,
              onlyMine: permissions.contains(Permissions.remittancesReadAssigned),
            ),
          ),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp.router(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => Scaffold(body: page),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cardOf(String beneficiary) => find.ancestor(of: find.text(beneficiary), matching: find.byType(Card));

  /// Sales' list with «Completadas» on: open and completed mixed.
  Future<void> salesListWithCompleted(WidgetTester tester, List<Remittance> open, List<Remittance> done) async {
    when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
    when(() => remittances.search(const RemittanceFilter(voided: false), size: 100))
        .thenAnswer((_) async => PageResult(items: open, page: 0, size: 100, totalItems: open.length));
    when(() => remittances.search(const RemittanceFilter(voided: false), page: 0, size: 50))
        .thenAnswer((_) async => PageResult(items: done, page: 0, size: 50, totalItems: done.length));
    await pump(tester, _sales, const AssignedPage());
    await tester.tap(find.widgetWithText(FilterChip, CourierTexts.showCompleted));
    await tester.pumpAndSettle();
  }

  group('list', () {
    testWidgets('AC-1.1: every completed card in the sales list is grey with a check, the open ones are not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await salesListWithCompleted(
        tester,
        [_open('OT-1'), _open('OT-2', type: RemittanceType.pickup)],
        [_done('OT-3'), _done('OT-4'), _done('OT-5')],
      );

      for (final name in ['Hecha OT-3', 'Hecha OT-4', 'Hecha OT-5']) {
        expect(tester.widget<Card>(cardOf(name)).color, OttosColors.completedSurface, reason: name);
        expect(
          find.descendant(of: cardOf(name), matching: find.byIcon(Icons.check)),
          findsOneWidget,
          reason: name,
        );
      }
      for (final name in ['Abierta OT-1', 'Abierta OT-2']) {
        expect(tester.widget<Card>(cardOf(name)).color, isNot(OttosColors.completedSurface), reason: name);
        expect(
          find.descendant(of: cardOf(name), matching: find.byIcon(Icons.check)),
          findsNothing,
          reason: name,
        );
      }
    });

    testWidgets('AC-1.2: a courier\'s completed remittances all have the same completed look', (tester) async {
      // REQ-017 (the courier's own completed list) is not in this branch; the courier list
      // already shows a recently completed one through the same card.
      when(() => remittances.assignedToMe())
          .thenAnswer((_) async => [_open('OT-1'), _done('OT-2'), _done('OT-3', type: RemittanceType.pickup)]);
      await pump(tester, _courier, const AssignedPage());

      for (final name in ['Hecha OT-2', 'Hecha OT-3']) {
        expect(tester.widget<Card>(cardOf(name)).color, OttosColors.completedSurface, reason: name);
        expect(
          find.descendant(of: cardOf(name), matching: find.byIcon(Icons.check)),
          findsOneWidget,
          reason: name,
        );
      }
      expect(tester.widget<Card>(cardOf('Abierta OT-1')).color, isNot(OttosColors.completedSurface));
    });

    testWidgets('AC-1.3: a completed delivery and a completed pickup each keep their type', (tester) async {
      when(() => remittances.assignedToMe())
          .thenAnswer((_) async => [_done('OT-1'), _done('OT-2', type: RemittanceType.pickup)]);
      await pump(tester, _courier, const AssignedPage());

      Finder badge(String card, String type) =>
          find.descendant(of: cardOf(card), matching: find.widgetWithText(RemittanceTypeBadge, type));
      expect(badge('Hecha OT-1', CoreTexts.delivery), findsOneWidget);
      expect(badge('Hecha OT-1', CoreTexts.pickup), findsNothing);
      expect(find.descendant(of: cardOf('Hecha OT-1'), matching: find.text('Entregada')), findsOneWidget);
      expect(badge('Hecha OT-2', CoreTexts.pickup), findsOneWidget);
      expect(badge('Hecha OT-2', CoreTexts.delivery), findsNothing);
      expect(
        find.descendant(of: cardOf('Hecha OT-2'), matching: find.text('Recogida')),
        findsNWidgets(2),
        reason: 'status word and type, on purpose',
      );
    });

    testWidgets('AC-1.4: the completed mark is an icon plus a word and an outline, not only a colour', (tester) async {
      when(() => remittances.assignedToMe()).thenAnswer((_) async => [_done('OT-1'), _open('OT-2')]);
      await pump(tester, _courier, const AssignedPage());

      final done = tester.widget<Card>(cardOf('Hecha OT-1'));
      final border = (done.shape! as RoundedRectangleBorder).side;
      expect(border.color, OttosColors.completedBorder);
      expect(border.width, greaterThan(0));
      expect(tester.widget<Card>(cardOf('Abierta OT-2')).shape, isNull, reason: 'open cards have no outline');
      final chip = find.descendant(of: cardOf('Hecha OT-1'), matching: find.byType(RemittanceStatusChip));
      expect(find.descendant(of: chip, matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text('Entregada')), findsOneWidget);
    });

    test('AC-1.4 (contrast): muted text and chip text stay readable (4.5:1) on the completed grey', () {
      final tint = Color.alphaBlend(OttosColors.success.withValues(alpha: 0.12), OttosColors.completedSurface);
      expect(_contrast(OttosColors.inkMuted, OttosColors.completedSurface), greaterThanOrEqualTo(4.5));
      expect(_contrast(OttosColors.successText, tint), greaterThanOrEqualTo(4.5));
    });

    testWidgets('BR-1 (voided): a voided completed remittance keeps its own look, not the completed one', (
      tester,
    ) async {
      when(() => remittances.assignedToMe()).thenAnswer(
        (_) async => [
          _done(
            'OT-1',
            voided: const Voided(reason: 'Duplicada', byName: 'Admin'),
          ),
        ],
      );
      await pump(tester, _courier, const AssignedPage());

      expect(tester.widget<Card>(cardOf('Hecha OT-1')).color, isNot(OttosColors.completedSurface));
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  group('detail', () {
    Future<void> openDetail(WidgetTester tester, Remittance remittance, Set<String> permissions) async {
      when(() => remittances.get('r1')).thenAnswer((_) async => remittance);
      await pump(tester, permissions, const RemittancePage(remittanceId: 'r1'));
    }

    testWidgets('US-1 assumption: a completed pickup shows «Recogida el …» with a check', (tester) async {
      await openDetail(tester, _done('OT-1', type: RemittanceType.pickup), _sales);

      expect(find.textContaining('Recogida el '), findsOneWidget);
      expect(find.textContaining('12 oct 2026'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2), reason: 'banner and header chip');
    });

    testWidgets('US-1 assumption: a completed delivery shows «Entregada el …», also to the courier', (tester) async {
      await openDetail(tester, _done('OT-1'), _courier);

      expect(find.textContaining('Entregada el '), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('US-1 assumption (open): an open remittance shows no completed banner or check', (tester) async {
      await openDetail(tester, _open('OT-1'), _sales);

      expect(find.textContaining(' el '), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('US-1 assumption (voided): a voided completed one shows the voided banner only', (tester) async {
      await openDetail(
        tester,
        _done(
          'OT-1',
          voided: const Voided(reason: 'Duplicada', byName: 'Admin'),
        ),
        _sales,
      );

      expect(find.byType(VoidedBanner), findsOneWidget);
      expect(find.textContaining('Entregada el '), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
