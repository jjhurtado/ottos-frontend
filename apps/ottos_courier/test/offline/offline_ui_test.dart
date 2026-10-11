import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/app/courier_texts.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:ottos_courier/shell/courier_shell.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSync extends Mock implements SyncRepository {}

const _courier = CurrentUser(
  id: 'c1',
  email: 'c1@ottos.test',
  name: 'Courier 1',
  type: '',
  roles: [],
  permissions: {Permissions.remittancesReadAssigned},
);

SyncAction _action(SyncActionType type) => SyncAction(
  id: SyncRepository.newActionId(),
  type: type,
  remittanceId: 'r1',
  occurredAt: DateTime(2026, 10, 10, 9, 30),
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    registerFallbackValue(<SyncAction>[]);
    await OttosLocalization.initialize();
  });

  group('summary', () {
    final now = DateTime(2026, 10, 10, 12);

    test('says how it stands', () {
      expect(
        CourierTexts.syncSummary(const SyncStatus(offline: true, pending: 2), now: now),
        'Sin conexión · 2 sin enviar',
      );
      expect(
        CourierTexts.syncSummary(SyncStatus(lastSync: now.subtract(const Duration(minutes: 5))), now: now),
        'Sincronizado hace 5 min',
      );
      expect(
        CourierTexts.syncSummary(SyncStatus(lastSync: DateTime(2026, 10, 10, 8, 5)), now: now),
        'Sincronizado a las 8:05',
      );
      expect(CourierTexts.syncSummary(const SyncStatus(), now: now), 'Sin sincronizar todavía');
    });
  });

  group('shell', () {
    late _MockAuthRepository auth;
    late AuthBloc authBloc;
    late OfflineStore store;
    late SyncCubit sync;

    Future<void> pumpShell(WidgetTester tester, {List<SyncAction> queued = const [], int rejected = 0}) async {
      auth = _MockAuthRepository();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      when(() => auth.logout()).thenAnswer((_) async {});
      authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)..add(const AuthLoggedIn(_courier));
      await tester.runAsync(() async {
        store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
        final server = _MockSync();
        // No network: everything stays on the phone.
        when(() => server.state(since: any(named: 'since'))).thenThrow(const ApiException(CoreTexts.networkError));
        when(() => server.send(any())).thenThrow(const ApiException(CoreTexts.networkError));
        sync = SyncCubit(store: store, sync: server);
        await store.useFor('c1');
        for (final action in queued) {
          await store.enqueue(action);
        }
        for (var i = 0; i < rejected; i++) {
          final action = _action(SyncActionType.reportIncident);
          await store.enqueue(action);
          await store.reject(action.id, code: 'REMITTANCE_NOT_FOUND', message: 'La remesa no existe.');
        }
        await sync.start('c1');
      });
      addTearDown(() async {
        await authBloc.close();
        await tester.runAsync(() async {
          await sync.close();
          await store.close();
        });
      });
      await tester.pumpWidget(
        RepositoryProvider<SyncCubit?>.value(
          value: sync,
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(
              home: CourierShell(location: '/', child: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows that it is offline and what waits to be sent', (tester) async {
      await pumpShell(tester, queued: [_action(SyncActionType.deliver)]);

      expect(find.text('Sin conexión · 1 sin enviar'), findsOneWidget);
      expect(find.byTooltip(CourierTexts.syncNow), findsOneWidget);
    });

    testWidgets('warns before logging out with unsent actions', (tester) async {
      await pumpShell(tester, queued: [_action(SyncActionType.deliver)]);

      await tester.tap(find.byTooltip(CourierTexts.account));
      await tester.pumpAndSettle();
      await tester.tap(find.text(CoreTexts.logout));
      await tester.pumpAndSettle();

      expect(find.text(CourierTexts.unsentOnLogout(1)), findsOneWidget);
      await tester.tap(find.text(CoreTexts.cancel));
      await tester.pumpAndSettle();
      verifyNever(() => auth.logout());
      expect(authBloc.state.isAuthenticated, isTrue);
    });

    testWidgets('lists the rejected actions with why, to dismiss them', (tester) async {
      await pumpShell(tester, rejected: 1);

      await tester.tap(find.text(CourierTexts.notSynced(1)));
      await tester.pumpAndSettle();

      expect(find.text(CourierTexts.notSyncedTitle), findsOneWidget);
      expect(find.textContaining('La remesa no existe.'), findsOneWidget);
      expect(find.text(CourierTexts.actionName(SyncActionType.reportIncident)), findsOneWidget);
    });
  });
}
