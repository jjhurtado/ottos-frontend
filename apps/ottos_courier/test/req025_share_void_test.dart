import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

// REQ-025: share a remittance as text and void it from the app (SCR-20).

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockSource extends Mock implements RemittanceSource {}

class _MockAuth extends Mock implements AuthRepository {}

const _open = Remittance(
  id: 'r1',
  code: 'OT-1',
  type: RemittanceType.delivery,
  status: 'PAID',
  statusName: 'Pagada',
  beneficiaryName: 'Rosa',
  beneficiaryPhone: '+5352000001',
  cashAmount: 100,
  cashCurrency: 'USD',
);

const _voided = Remittance(
  id: 'r1',
  code: 'OT-1',
  type: RemittanceType.delivery,
  status: 'PAID',
  statusName: 'Pagada',
  beneficiaryName: 'Rosa',
  voided: Voided(reason: 'Duplicada', byName: 'Admin'),
);

/// The share sheet's platform channel (share_plus): records the text sent to it.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  late _MockRemittances remittances;
  late _MockSource source;
  late List<String?> shared;

  setUpAll(OttosLocalization.initialize);

  setUp(() {
    remittances = _MockRemittances();
    // The phone's copy: the detail reads it, online or not.
    source = _MockSource();
    when(() => source.get('r1')).thenAnswer((_) async => _open);
    when(() => source.refresh()).thenAnswer((_) async {});
    shared = [];
  });

  Future<void> pump(WidgetTester tester, Set<String> permissions, {bool connected = true}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add((call.arguments as Map)['text'] as String?);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_shareChannel, null));
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
          RepositoryProvider<RemittanceSource>.value(value: source),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: RemittancePage(remittanceId: 'r1', hasConnection: () async => connected),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVoid(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CoreTexts.voidAction));
    await tester.pumpAndSettle();
  }

  testWidgets('AC-2.1: «Compartir» sends the remittance text to the share sheet', (tester) async {
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesShare});

    await tester.tap(find.byTooltip(CoreTexts.share));
    await tester.pumpAndSettle();

    expect(shared, [remittanceShareText(_open)]);
  });

  testWidgets('AC-2.3: without a connection, «Compartir» shares the data on the phone', (tester) async {
    // The server is out of reach; the detail comes from the phone's copy.
    when(() => remittances.get(any())).thenThrow(const ApiException(CoreTexts.networkError));
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesShare}, connected: false);

    await tester.tap(find.byTooltip(CoreTexts.share));
    await tester.pumpAndSettle();

    expect(shared, [remittanceShareText(_open)]);
  });

  testWidgets('AC-2.3: without the permission there is no «Compartir»', (tester) async {
    await pump(tester, {Permissions.remittancesRead});

    expect(find.byTooltip(CoreTexts.share), findsNothing);
  });

  testWidgets('AC-3.1, CR-1: «Anular» asks the reason, shows it voided and refreshes the phone\'s copy', (
    tester,
  ) async {
    when(() => remittances.voidRemittance('r1', reason: 'Duplicada')).thenAnswer((_) async => _voided);
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesVoid});

    await tapVoid(tester);
    expect(find.text(CoreTexts.voidHelp), findsOneWidget);

    // The reason is required.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.requiredField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Duplicada');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();

    verify(() => remittances.voidRemittance('r1', reason: 'Duplicada')).called(1);
    // The list and the money pending read the phone's copy: it is brought again.
    verify(() => source.refresh()).called(1);
    expect(find.text(CoreTexts.voidedDone), findsOneWidget);
    expect(find.byType(VoidedBanner), findsOneWidget);
    expect(find.byType(PopupMenuButton<void>), findsNothing, reason: 'it cannot be voided twice');
  });

  testWidgets('AC-3.2: without a connection it says so before asking the reason, and nothing is sent', (tester) async {
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesVoid}, connected: false);

    await tapVoid(tester);

    expect(find.text(CourierTexts.voidNeedsConnection), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(() => remittances.voidRemittance(any(), reason: any(named: 'reason')));
    verifyNever(() => source.refresh());
  });

  testWidgets('AC-3.2: if the call still fails, the network error shows and nothing changes', (tester) async {
    when(() => remittances.voidRemittance('r1', reason: 'Duplicada'))
        .thenThrow(const ApiException(CoreTexts.networkError));
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesVoid});

    await tapVoid(tester);
    await tester.enterText(find.byType(TextFormField), 'Duplicada');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.networkError), findsOneWidget);
    expect(find.byType(VoidedBanner), findsNothing);
    verifyNever(() => source.refresh());
  });

  testWidgets('AC-3.3: without the permission there is no «Anular»', (tester) async {
    await pump(tester, {Permissions.remittancesRead});

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });
}
