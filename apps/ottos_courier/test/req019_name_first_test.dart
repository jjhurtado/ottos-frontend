import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/assigned/view/assigned_page.dart';
import 'package:ottos_courier/features/remittance/view/remittance_page.dart';
import 'package:ottos_courier/notifications/notices.dart';
import 'package:ottos_courier/offline/offline_store.dart';
import 'package:ottos_courier/offline/remittance_source.dart';
import 'package:ottos_courier/offline/sync_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockSync extends Mock implements SyncRepository {}

/// Tester round for REQ-019 (courier app): name first, code small, in the
/// assigned list, the detail bar, the notifications and the cash note.
Remittance _remittance(String code, {String? name = 'Rosa Pérez', RemittanceType type = RemittanceType.delivery}) =>
    Remittance(
      id: code,
      code: code,
      type: type,
      status: 'ASSIGNED',
      statusName: 'Asignada',
      courierId: 'c1',
      beneficiaryName: name,
      beneficiaryAddress: 'Calle 1, Boyeros, La Habana',
      municipalityName: 'Boyeros',
      cashAmount: 100,
      cashCurrency: 'USD',
    );

Remittance _named(String id, String? name) => Remittance.fromJson({
  'id': id,
  'code': 'OT-$id',
  'type': 'DELIVERY',
  'status': 'ASSIGNED',
  'beneficiaryName': name,
  'municipalityName': 'Boyeros',
  'courierId': 'c1',
  'courierName': 'Luis',
});

void main() {
  late _MockRemittances remittances;

  setUpAll(() async {
    sqfliteFfiInit();
    registerFallbackValue(<SyncAction>[]);
    registerFallbackValue(IncidentReason.other);
    await OttosLocalization.initialize();
  });

  setUp(() => remittances = _MockRemittances());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
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
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<RemittanceSource>.value(value: OnlineSource(remittances: remittances, onlyMine: true)),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: page is Scaffold ? page : Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder titleOf(String code) => find.byWidgetPredicate((w) => w is RemittanceTitle && w.code == code);

  group('assigned list', () {
    testWidgets('AC-1.1: each card shows the name as title and the code smaller', (tester) async {
      when(() => remittances.assignedToMe()).thenAnswer(
        (_) async => [
          _remittance('OT-1'),
          _remittance('OT-2'),
          _remittance('OT-3', name: 'Juan Gómez', type: RemittanceType.pickup),
          _remittance('OT-4', name: null),
        ],
      );
      await pumpPage(tester, const AssignedPage());

      for (final code in ['OT-1', 'OT-2', 'OT-3']) {
        final name = find.descendant(of: titleOf(code), matching: find.byType(Text)).first;
        final codeText = find.descendant(of: titleOf(code), matching: find.text(code));
        expect(codeText, findsOneWidget, reason: 'BR-2');
        expect(tester.getTopLeft(codeText).dy, greaterThan(tester.getTopLeft(name).dy), reason: code);
        expect(
          tester.widget<Text>(codeText).style!.fontSize!,
          lessThan(tester.widget<Text>(name).style?.fontSize ?? 16),
        );
      }
      expect(
        find.descendant(of: titleOf('OT-3'), matching: find.text('Juan Gómez')),
        findsOneWidget,
        reason: 'AC-1.3',
      );
      expect(find.text('Rosa Pérez'), findsNWidgets(2), reason: 'AC-1.4: same name twice');
      expect(
        find.descendant(of: titleOf('OT-4'), matching: find.byType(Text)),
        findsOneWidget,
        reason: 'no name',
      );
    });
  });

  group('remittance detail', () {
    testWidgets('AC-1.2: the app bar is the name with the code under it', (tester) async {
      when(() => remittances.get('OT-1')).thenAnswer((_) async => _remittance('OT-1'));
      await pumpPage(tester, const RemittancePage(remittanceId: 'OT-1'));

      final bar = find.byType(AppBar);
      expect(find.descendant(of: bar, matching: find.text('Rosa Pérez')), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text('OT-1')), findsOneWidget);
    });

    testWidgets('AC-1.2 (no name): the app bar shows the code alone', (tester) async {
      when(() => remittances.get('OT-1')).thenAnswer((_) async => _remittance('OT-1', name: null));
      await pumpPage(tester, const RemittancePage(remittanceId: 'OT-1'));

      expect(find.descendant(of: find.byType(AppBar), matching: find.text('OT-1')), findsOneWidget);
    });
  });

  group('notifications', () {
    test('AC-2.1 (grouped): exactly three names have no «y N más»', () {
      final notice = newRemittanceNotices([_named('a', 'Ana'), _named('b', 'Beto'), _named('c', 'Carla')]);
      expect(notice, hasLength(3), reason: 'up to three get one notification each');
      expect(notice.map((n) => n.body), ['Ana · Boyeros · OT-a', 'Beto · Boyeros · OT-b', 'Carla · Boyeros · OT-c']);
    });

    test('AC-2.1 (grouped): four remittances name three and add «y 1 más»', () {
      final notice = newRemittanceNotices([
        for (final id in ['a', 'b', 'c', 'd']) _named(id, 'N$id'),
      ]).single;
      expect(notice.title, 'Tienes 4 remesas nuevas', reason: 'existing title stays');
      expect(notice.body, 'Na, Nb, Nc y 1 más');
    });

    test('AC-2.1 (grouped): a nameless remittance among the first three shows its code', () {
      final notice = newRemittanceNotices([
        _named('a', 'Ana'),
        _named('b', null),
        _named('c', ' '),
        _named('d', 'Dora'),
      ]);
      expect(notice.single.body, 'Ana, OT-b, OT-c y 1 más');
    });

    test('AC-2.1 (single): titles stay, name first and code last, no name gives the rest', () {
      final withName = newRemittanceNotices([_named('a', 'Ana')]).single;
      expect(withName.title, 'Nueva entrega asignada');
      expect(withName.body.startsWith('Ana'), isTrue);
      expect(withName.body.endsWith('OT-a'), isTrue);
      expect(newRemittanceNotices([_named('a', null)]).single.body, 'Boyeros · OT-a');
      expect(newRemittanceNotices([_named('a', '  ')]).single.body, 'Boyeros · OT-a', reason: 'blank is empty');
    });

    test('AC-2.2 (grouped): completed remittances join at most three names', () {
      final notice = completedNotices([
        for (final id in ['a', 'b', 'c', 'd']) _named(id, 'N$id'),
      ]).single;
      expect(notice.title, '4 remesas completadas');
      expect(notice.body, 'Na, Nb, Nc y 1 más');
    });

    test('AC-2.2 (single): the completed title stays and the name leads', () {
      final notice = completedNotices([_named('a', 'Ana')]).single;
      expect(notice.title, 'Remesa entregada');
      expect(notice.body, 'Ana · Luis · OT-a');
    });
  });

  group('cash note', () {
    test('the movement of a delivery done offline carries the name and the code, or the code alone', () async {
      final store = await OfflineStore.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      final server = _MockSync();
      when(() => server.state(since: any(named: 'since'))).thenAnswer(
        (_) async => SyncState(
          serverTime: 't1',
          full: true,
          remittances: [
            for (final (id, name) in [('a', 'Rosa Pérez'), ('b', null)])
              {
                'id': id,
                'code': 'OT-$id',
                'type': 'DELIVERY',
                'status': 'ASSIGNED',
                'beneficiaryName': name,
                'cashAmount': 100,
                'cashCurrency': 'USD',
              },
          ],
          cash: {
            'cash': {
              'courierId': 'u1',
              'name': 'Luis',
              'balances': [
                {'currency': 'USD', 'amount': 500},
              ],
            },
            'movements': [],
          },
        ),
      );
      when(() => server.send(any())).thenThrow(const ApiException(CoreTexts.networkError));
      final sync = SyncCubit(store: store, sync: server);
      final source = OfflineSource(sync: sync);
      addTearDown(() async {
        await sync.close();
        await store.close();
      });
      await sync.start('u1');

      await source.deliver(_named('a', 'Rosa Pérez'));
      await source.deliver(_named('b', null));

      final notes = (await sync.cash())!.movements.map((m) => m.note).toList();
      expect(notes, containsAll(['Rosa Pérez · OT-a', 'OT-b']));
    });
  });
}
