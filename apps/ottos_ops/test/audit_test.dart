import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/audit/view/audit_page.dart';

class _MockAudit extends Mock implements AuditRepository {}

AuditEntry _entry(
  String action,
  Map<String, dynamic> details, {
  String type = 'USER',
  String? actor = 'Administrator',
}) => AuditEntry.fromJson({
  'id': action,
  'occurredAt': '2026-10-11T15:31:05Z',
  'actorName': actor,
  'action': action,
  'targetType': type,
  'targetLabel': type == 'ROLE' ? 'CAJEROS' : 'luis@ottos.test',
  'details': details,
});

void main() {
  setUpAll(() async {
    registerFallbackValue(const AuditFilter());
    await OttosLocalization.initialize();
  });

  group('details', () {
    test('imports and exports read in Spanish, about the kind of records', () {
      final beneficiaries = _entry('BENEFICIARIES_IMPORTED', {
        'beneficiariesCreated': 2,
        'beneficiariesExisting': 0,
        'beneficiariesRejected': 1,
      }, type: 'BENEFICIARIES');
      expect(OpsTexts.auditAction(beneficiaries.action), 'Beneficiarios importados (CSV)');
      expect(OpsTexts.auditTargetLabel(beneficiaries), 'Beneficiarios');
      expect(OpsTexts.auditDetails(beneficiaries), ['Beneficiarios: 2 nuevos · 0 ya existían · 1 rechazados']);

      final customers = _entry('CUSTOMERS_IMPORTED', {
        'customersCreated': 1,
        'customersExisting': 3,
        'customersRejected': 0,
        'beneficiariesCreated': 4,
        'beneficiariesExisting': 0,
        'beneficiariesRejected': 0,
        'linksCreated': 4,
      }, type: 'CUSTOMERS');
      expect(OpsTexts.auditDetails(customers), [
        'Clientes: 1 nuevos · 3 ya existían · 0 rechazados',
        'Beneficiarios: 4 nuevos · 0 ya existían · 0 rechazados',
        'Vínculos nuevos: 4',
      ]);
      expect(OpsTexts.auditDetails(_entry('CUSTOMERS_EXPORTED', {'customers': 12}, type: 'CUSTOMERS')), [
        '12 clientes',
      ]);
    });

    test('roles and permissions read by their Spanish names', () {
      expect(
        OpsTexts.auditDetails(
          _entry('USER_ROLES_CHANGED', {
            'before': ['DELIVERY'],
            'after': ['SALES', 'DELIVERY'],
          }),
        ),
        ['Repartidor → Ventas, Repartidor'],
      );
      expect(
        OpsTexts.auditDetails(
          _entry('ROLE_PERMISSIONS_CHANGED', {
            'added': ['remittances:read'],
            'removed': [],
          }, type: 'ROLE'),
        ),
        ['Añadidos: Ver todas las remesas y su historial'],
      );
    });

    test('a renamed role says what changed and what not', () {
      expect(
        OpsTexts.auditDetails(
          _entry('ROLE_DESCRIBED', {
            'before': {'name': 'Cajeros', 'description': null},
            'after': {'name': 'Cajeros', 'description': 'Cobran en tienda'},
          }, type: 'ROLE'),
        ),
        ['Descripción: — → Cobran en tienda'],
      );
    });

    test('a remittance completed from the business says what and whether it had a courier', () {
      final entry = _entry('REMITTANCE_COMPLETED_FROM_BUSINESS', {
        'code': 'OT-6XAHP7',
        'type': 'DELIVERY',
        'amount': 76000,
        'currency': 'CUP',
        'previousCourierId': 'k1',
        'note': 'Entregada en la oficina',
      }, type: 'REMITTANCE');
      expect(OpsTexts.auditAction(entry.action), 'Completada desde el negocio');
      expect(OpsTexts.auditDetails(entry), [
        '${CoreTexts.delivery} · ${Formatters.money(76000, 'CUP')}',
        'Se le quitó al repartidor que la tenía',
        'Nota: Entregada en la oficina',
      ]);
      final bare = _entry('REMITTANCE_COMPLETED_FROM_BUSINESS', {
        'type': 'PICKUP',
        'amount': 200,
        'currency': 'USD',
        'previousCourierId': null,
        'note': null,
      }, type: 'REMITTANCE');
      expect(OpsTexts.auditDetails(bare), ['${CoreTexts.pickup} · ${Formatters.money(200, 'USD')}']);
    });

    test('on the house reads who sent what to whom, the fee not charged and why', () {
      final entry = _entry('REMITTANCE_ON_THE_HOUSE', {
        'code': 'OT-7K3F9Q',
        'type': 'DELIVERY',
        'amount': 37.00,
        'currency': 'USD',
        'waivedFee': 10.00,
        'customerId': 'c1',
        'customerName': 'Ana Pérez',
        'beneficiaryId': 'b1',
        'beneficiaryName': 'Rosa Martínez',
        'reason': 'Su madre',
      }, type: 'REMITTANCE');
      expect(OpsTexts.auditAction(entry.action), 'Remesa por la casa (sin comisión)');
      expect(OpsTexts.auditActions['REMITTANCE'], contains('REMITTANCE_ON_THE_HOUSE'));
      expect(OpsTexts.auditDetails(entry), [
        '${Formatters.money(37, 'USD')} de Ana Pérez para Rosa Martínez',
        '${CoreTexts.waivedFee}: ${Formatters.money(10, 'USD')}',
        'Motivo: Su madre',
      ]);
    });

    test('the permission of on the house reads in Spanish', () {
      expect(
        OpsTexts.permissionLabel(const PermissionInfo(code: Permissions.remittancesOnTheHouse, module: 'remittances')),
        'Registrar entregas por la casa (sin comisión)',
      );
    });

    test('unknown actions keep their code and raw details', () {
      final entry = _entry('SOMETHING_NEW', {'field': 'x'});
      expect(OpsTexts.auditAction(entry.action), 'SOMETHING_NEW');
      expect(OpsTexts.auditDetails(entry), ['field: x']);
    });
  });

  group('page', () {
    late _MockAudit audit;

    setUp(() {
      audit = _MockAudit();
      when(
        () => audit.search(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer(
        (_) async => PageResult(
          items: [
            _entry('USER_DEACTIVATED', const {}),
            _entry('USER_CREATED', const {
              'name': 'Administrator',
              'roles': ['ADMIN'],
            }, actor: null),
          ],
          page: 0,
          size: 50,
          totalItems: 2,
        ),
      );
    });

    Future<void> pump(WidgetTester tester, {double width = 1400}) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<AuditRepository>.value(
          value: audit,
          child: MaterialApp(
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: const Scaffold(body: AuditPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists who did what, the system included', (tester) async {
      await pump(tester);

      expect(find.text(OpsTexts.auditAction('USER_DEACTIVATED')), findsOneWidget);
      expect(find.text(OpsTexts.system), findsOneWidget);
      expect(find.textContaining('Roles: Administrador'), findsOneWidget);
    });

    testWidgets('filtering by type and action asks again from the first page', (tester) async {
      await pump(tester);

      await tester.tap(find.text(OpsTexts.allTargets));
      await tester.pumpAndSettle();
      await tester.tap(find.text(OpsTexts.auditTarget('ROLE')).last);
      await tester.pumpAndSettle();

      verify(() => audit.search(const AuditFilter(targetType: 'ROLE'), page: 0, size: 50)).called(1);
      await tester.tap(find.text(OpsTexts.allActions));
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.auditAction('ROLE_DELETED')), findsOneWidget);
      // Only the table row: the menu offers role actions only.
      expect(find.text(OpsTexts.auditAction('USER_CREATED')), findsOneWidget);
    });

    testWidgets('the date stays on one line when the details are long', (tester) async {
      when(
        () => audit.search(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer(
        (_) async => PageResult(
          items: [
            _entry('ROLE_PERMISSIONS_CHANGED', const {
              'added': ['remittances:read', 'remittances:assign', 'customers:write', 'cash:read', 'reports:read'],
              'removed': ['users:write'],
            }, type: 'ROLE'),
          ],
          page: 0,
          size: 50,
          totalItems: 1,
        ),
      );
      await pump(tester, width: 1000);

      final date = find.text(Formatters.dateTime(DateTime.parse('2026-10-11T15:31:05Z')));
      final lineHeight = tester.getSize(find.text(OpsTexts.when)).height;
      expect(tester.getSize(date).height, lessThan(lineHeight * 1.5));
    });
  });
}
