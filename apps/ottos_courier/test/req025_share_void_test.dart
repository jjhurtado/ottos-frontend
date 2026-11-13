import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

// REQ-025: share a remittance as text and void it from the app (SCR-20).

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _open = Remittance(
  id: 'r1',
  code: 'OT-1',
  type: RemittanceType.delivery,
  status: 'PAID',
  statusName: 'Pagada',
  beneficiaryName: 'Rosa',
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

void main() {
  late _MockRemittances remittances;

  setUpAll(OttosLocalization.initialize);

  setUp(() {
    remittances = _MockRemittances();
    when(() => remittances.get('r1')).thenAnswer((_) async => _open);
  });

  Future<void> pump(WidgetTester tester, Set<String> permissions) async {
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
          RepositoryProvider<RemittanceSource>.value(value: OnlineSource(remittances: remittances, onlyMine: false)),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const RemittancePage(remittanceId: 'r1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC-2.1: «Compartir» is in the app bar with the permission', (tester) async {
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesShare});

    expect(find.byTooltip(CoreTexts.share), findsOneWidget);
  });

  testWidgets('AC-2.3: without the permission there is no «Compartir»', (tester) async {
    await pump(tester, {Permissions.remittancesRead});

    expect(find.byTooltip(CoreTexts.share), findsNothing);
  });

  testWidgets('AC-3.1: «Anular» asks the reason and shows it voided', (tester) async {
    when(() => remittances.voidRemittance('r1', reason: 'Duplicada')).thenAnswer((_) async => _voided);
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesVoid});

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CoreTexts.voidAction));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.voidHelp), findsOneWidget);

    // The reason is required.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();
    expect(find.text(CoreTexts.requiredField), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Duplicada');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();

    verify(() => remittances.voidRemittance('r1', reason: 'Duplicada')).called(1);
    expect(find.text(CoreTexts.voidedDone), findsOneWidget);
    expect(find.byType(VoidedBanner), findsOneWidget);
    expect(find.byType(PopupMenuButton<void>), findsNothing, reason: 'it cannot be voided twice');
  });

  testWidgets('AC-3.2: without a connection it says so and nothing is queued', (tester) async {
    when(() => remittances.voidRemittance('r1', reason: 'Duplicada'))
        .thenThrow(const ApiException(CoreTexts.networkError));
    await pump(tester, {Permissions.remittancesRead, Permissions.remittancesVoid});

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(CoreTexts.voidAction));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Duplicada');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(CoreTexts.voidAction)));
    await tester.pumpAndSettle();

    expect(find.text(CoreTexts.networkError), findsOneWidget);
    expect(find.byType(VoidedBanner), findsNothing);
  });

  testWidgets('AC-3.3: without the permission there is no «Anular»', (tester) async {
    await pump(tester, {Permissions.remittancesRead});

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });
}
