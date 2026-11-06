import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _PendingSource extends OnlineSource {
  _PendingSource(RemittanceRepository remittances) : super(remittances: remittances, onlyMine: true);

  @override
  Future<Set<String>> pendingIds() async => const {'OT-1'};
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// REQ-007 (tester): the «Sin enviar» badge text uses the darker amber.
void main() {
  setUpAll(() => registerFallbackValue(IncidentReason.other));

  testWidgets('REQ-007: «Sin enviar» uses warningText and reads at 4.5:1 on its tint', (tester) async {
    final remittances = _MockRemittances();
    when(() => remittances.assignedToMe()).thenAnswer(
      (_) async => [
        const Remittance(
          id: 'OT-1',
          code: 'OT-1',
          type: RemittanceType.delivery,
          status: 'ASSIGNED',
          statusName: 'Asignada',
          courierId: 'c1',
          beneficiaryName: 'Rosa',
          beneficiaryAddress: 'Calle 1',
          municipalityName: 'Boyeros',
          cashAmount: 100,
          cashCurrency: 'USD',
        ),
      ],
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
            permissions: {Permissions.remittancesReadAssigned, Permissions.remittancesDeliver},
          ),
        ),
      );
    addTearDown(authBloc.close);
    await OttosLocalization.initialize();
    await tester.pumpWidget(
      RepositoryProvider<RemittanceSource>.value(
        value: _PendingSource(remittances),
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

    final text = tester.widget<Text>(find.text(CourierTexts.unsent));
    expect(text.style!.color, OttosColors.warningText);
    final tint = Color.alphaBlend(OttosColors.warning.withValues(alpha: 0.12), Colors.white);
    expect(_contrast(text.style!.color!, tint), greaterThanOrEqualTo(4.5));
  });
}
