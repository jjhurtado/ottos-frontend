import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/remittances/view/remittance_detail_page.dart';
import 'package:ottos_ops/features/remittances/view/remittance_list_page.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

/// Tester round for REQ-019 (panel): name first, code small, in the list, the
/// detail and the void dialog; the audit log keeps the code (BR-5).
const _rosa = Remittance(
  id: 'r1',
  code: 'OT-ABC123',
  type: RemittanceType.delivery,
  status: 'CREATED',
  statusName: 'Creada',
  beneficiaryName: 'Rosa Pérez',
);
const _rosaAgain = Remittance(
  id: 'r2',
  code: 'OT-ZZZ999',
  type: RemittanceType.delivery,
  status: 'CREATED',
  statusName: 'Creada',
  beneficiaryName: 'Rosa Pérez',
);
const _pickup = Remittance(
  id: 'r3',
  code: 'OT-PKP777',
  type: RemittanceType.pickup,
  status: 'CREATED',
  statusName: 'Creada',
  beneficiaryName: 'Juan Gómez',
);
const _noName = Remittance(
  id: 'r4',
  code: 'OT-OLD404',
  type: RemittanceType.delivery,
  status: 'CREATED',
  statusName: 'Creada',
);

void main() {
  late _MockRemittances remittances;

  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    await OttosLocalization.initialize();
  });

  setUp(() {
    remittances = _MockRemittances();
    when(() => remittances.workflow()).thenAnswer((_) async => const Workflow(statuses: [], transitions: []));
    when(() => remittances.events(any())).thenAnswer((_) async => const []);
  });

  AuthBloc authBloc() {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final bloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        const AuthLoggedIn(
          CurrentUser(id: 'u1', email: 'u@ottos.test', name: 'U', type: 'STAFF', roles: [], permissions: {}),
        ),
      );
    addTearDown(bloc.close);
    return bloc;
  }

  Future<void> pump(WidgetTester tester, Widget page, {Size size = const Size(1400, 1000)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepositoryProvider<RemittanceRepository>.value(
        value: remittances,
        child: BlocProvider.value(
          value: authBloc(),
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void listReturns(List<Remittance> items) => when(
    () => remittances.search(
      any(),
      page: any(named: 'page'),
      size: any(named: 'size'),
    ),
  ).thenAnswer((_) async => PageResult(items: items, page: 0, size: 20, totalItems: items.length));

  Finder titleOf(String code) => find.byWidgetPredicate((w) => w is RemittanceTitle && w.code == code);

  for (final (label, size) in [('table', const Size(1400, 1000)), ('phone', const Size(390, 900))]) {
    testWidgets('AC-1.1 ($label): the list shows the name as title and the code smaller', (tester) async {
      listReturns([_rosa, _rosaAgain, _pickup, _noName]);
      await pump(tester, const RemittanceListPage(), size: size);

      for (final item in [_rosa, _rosaAgain, _pickup]) {
        final name = find.descendant(of: titleOf(item.code), matching: find.text(item.beneficiaryName!));
        final code = find.descendant(of: titleOf(item.code), matching: find.text(item.code));
        expect(name, findsOneWidget, reason: item.code);
        expect(code, findsOneWidget, reason: 'BR-2');
        expect(tester.getTopLeft(code).dy, greaterThan(tester.getTopLeft(name).dy));
        expect(
          tester.widget<Text>(code).style!.fontSize!,
          lessThan(tester.widget<Text>(name).style?.fontSize ?? 16),
          reason: 'the code smaller',
        );
      }
      expect(
        find.descendant(of: titleOf('OT-OLD404'), matching: find.byType(Text)),
        findsOneWidget,
        reason: 'no name',
      );
    });

    testWidgets('AC-1.4 ($label): two remittances of one beneficiary are told apart by code', (tester) async {
      listReturns([_rosa, _rosaAgain]);
      await pump(tester, const RemittanceListPage(), size: size);

      expect(find.text('Rosa Pérez'), findsNWidgets(2));
      expect(find.text('OT-ABC123'), findsOneWidget);
      expect(find.text('OT-ZZZ999'), findsOneWidget);
    });
  }

  testWidgets('AC-1.1 (table): the first column header is the beneficiary, no separate name column', (tester) async {
    listReturns([_rosa]);
    await pump(tester, const RemittanceListPage());

    expect(find.text(OpsTexts.beneficiary), findsWidgets);
    expect(find.text(OpsTexts.code), findsNothing, reason: 'the code lives under the name now');
    expect(find.text('Rosa Pérez'), findsOneWidget, reason: 'the name is not repeated in another column');
  });

  testWidgets('AC-1.2: the detail title is the name, the code is shown smaller', (tester) async {
    when(() => remittances.get('r1')).thenAnswer((_) async => _rosa);
    await pump(tester, const RemittanceDetailPage(remittanceId: 'r1'));

    final name = find.descendant(of: titleOf('OT-ABC123'), matching: find.text('Rosa Pérez'));
    final code = find.descendant(of: titleOf('OT-ABC123'), matching: find.text('OT-ABC123'));
    expect(name, findsOneWidget);
    expect(code, findsOneWidget);
    expect(
      tester.widget<Text>(code).style!.fontSize!,
      lessThan(tester.widget<Text>(name).style!.fontSize!),
      reason: 'BR-2',
    );
  });

  testWidgets('AC-1.2 (pickup): the detail names the person the cash is collected from', (tester) async {
    when(() => remittances.get('r3')).thenAnswer((_) async => _pickup);
    await pump(tester, const RemittanceDetailPage(remittanceId: 'r3'));

    expect(find.descendant(of: titleOf('OT-PKP777'), matching: find.text('Juan Gómez')), findsOneWidget);
  });

  testWidgets('AC-1.2 (no name): the detail title falls back to the code', (tester) async {
    when(() => remittances.get('r4')).thenAnswer((_) async => _noName);
    await pump(tester, const RemittanceDetailPage(remittanceId: 'r4'));

    expect(find.descendant(of: titleOf('OT-OLD404'), matching: find.byType(Text)), findsOneWidget);
  });

  testWidgets('AC-1.2: the void dialog names the beneficiary and the code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: OttosLocalization.delegates,
        supportedLocales: OttosLocalization.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(onPressed: () => askVoidReason(context, _rosa), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.voidTitle('Rosa Pérez · OT-ABC123')), findsOneWidget);
  });

  group('BR-5: the audit log keeps the remittance code', () {
    test('a remittance entry is labelled by the label the backend sends, never by a name', () {
      final entry = AuditEntry.fromJson({
        'id': 'a1',
        'occurredAt': '2026-10-11T15:31:05Z',
        'actorName': 'Administrator',
        'action': 'REMITTANCE_VOIDED',
        'targetType': 'REMITTANCE',
        'targetLabel': 'OT-ABC123',
        'details': {'code': 'OT-ABC123'},
      });
      expect(OpsTexts.auditTargetLabel(entry), 'OT-ABC123');
    });
  });
}
