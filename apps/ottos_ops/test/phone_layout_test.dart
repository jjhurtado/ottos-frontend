import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/audit/view/audit_page.dart';
import 'package:ottos_ops/features/beneficiaries/view/beneficiary_list_page.dart';
import 'package:ottos_ops/features/cash/view/cash_page.dart';
import 'package:ottos_ops/features/cash/view/courier_cash_page.dart';
import 'package:ottos_ops/features/customers/view/customer_list_page.dart';
import 'package:ottos_ops/features/remittances/view/remittance_list_page.dart';
import 'package:ottos_ops/features/reports/view/reports_page.dart';
import 'package:ottos_ops/features/users/view/user_list_page.dart';

import 'reports_test.dart' show sampleJson;

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockRemittances extends Mock implements RemittanceRepository {}

class _MockCash extends Mock implements CashRepository {}

class _MockReports extends Mock implements ReportRepository {}

class _MockAudit extends Mock implements AuditRepository {}

class _MockUsers extends Mock implements UserRepository {}

class _MockRoles extends Mock implements RoleRepository {}

class _MockAuth extends Mock implements AuthRepository {}

/// Where to write the screenshots, when set (to look at them by hand).
final _shots = Platform.environment['OTTOS_PHONE_SHOTS'];

const _phone = Size(390, 844);

final _customers = [
  for (var i = 0; i < 8; i++)
    Customer(
      id: 'c$i',
      fullName: 'María Fernanda Rodríguez Pérez $i',
      phone: '+1 305 555 000$i',
      address: '1234 SW 8th Street, Apartment 12, Miami, FL 33135',
      documentType: 'PASAPORTE',
      documentNumber: 'K12345678',
      createdAt: DateTime(2026, 10, 1),
      active: i != 2,
    ),
];

final _beneficiaries = [
  for (var i = 0; i < 8; i++)
    Beneficiary(
      id: 'b$i',
      fullName: 'Rosa María Hernández Díaz $i',
      phone: '5352220001',
      alternatePhone: '78881234',
      street: 'Calle 23',
      houseNumber: '1054',
      betweenStreets: '14 y 16',
      neighborhood: 'Vedado',
      municipalityName: 'Plaza de la Revolución',
      provinceName: 'La Habana',
    ),
];

final _remittances = [
  for (var i = 0; i < 8; i++)
    Remittance(
      id: 'r$i',
      code: 'OT-ABC12$i',
      type: i.isEven ? RemittanceType.delivery : RemittanceType.pickup,
      status: 'PAID',
      statusName: 'Pagada',
      customerName: 'María Fernanda Rodríguez',
      beneficiaryName: 'Rosa María Hernández Díaz',
      municipalityName: 'Plaza de la Revolución',
      amount: 1250,
      sourceCurrency: 'USD',
      expectedDate: DateTime(2026, 10, 20),
    ),
];

final _audit = [
  for (var i = 0; i < 6; i++)
    AuditEntry.fromJson({
      'id': 'a$i',
      'occurredAt': '2026-10-11T15:31:05Z',
      'actorName': 'Administrador del sistema',
      'action': 'USER_UPDATED',
      'targetType': 'USER',
      'targetLabel': 'vendedora.principal@remesadeotto.com',
      'details': {'name': 'Vendedora principal'},
    }),
];

const _sales = RoleSummary(id: 'r2', code: 'SALES', name: 'Ventas');
const _users = [
  StaffUser(id: 'u1', email: 'administrador@remesadeotto.com', name: 'Administrador General', roles: [_sales]),
  StaffUser(id: 'u2', email: 'vendedora.principal@remesadeotto.com', name: 'Ana Gómez', roles: [_sales]),
  StaffUser(id: 'u3', email: 'old@remesadeotto.com', name: 'Zoe', active: false, roles: [_sales]),
];

void main() {
  late _MockCustomers customers;
  late _MockRemittances remittances;
  late _MockCash cash;
  late _MockReports reports;
  late _MockAudit audit;
  late _MockUsers users;
  late _MockRoles roles;

  setUpAll(() async {
    registerFallbackValue(const RemittanceFilter());
    registerFallbackValue(const AuditFilter());
    await OttosLocalization.initialize();
    if (_shots == null) return;
    // Real glyphs, so the screenshots read like the browser.
    Future<void> load(String family, List<String> paths) async {
      final loader = FontLoader(family);
      for (final path in paths) {
        loader.addFont(File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
      }
      await loader.load();
    }

    await load('Roboto', [
      'assets/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto-Medium.ttf',
      'assets/fonts/Roboto-Bold.ttf',
    ]);
    final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  setUp(() {
    customers = _MockCustomers();
    remittances = _MockRemittances();
    cash = _MockCash();
    reports = _MockReports();
    audit = _MockAudit();
    users = _MockUsers();
    roles = _MockRoles();
    when(
      () => customers.customerPage(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => PageResult(items: _customers, page: 0, size: 50, totalItems: 339));
    when(
      () => customers.beneficiaryPage(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => PageResult(items: _beneficiaries, page: 0, size: 50, totalItems: 339));
    when(() => remittances.workflow()).thenAnswer(
      (_) async => Workflow.fromJson({
        'statuses': [
          {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
          {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
        ],
        'transitions': const [],
      }),
    );
    when(
      () => remittances.search(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => PageResult(items: _remittances, page: 0, size: 50, totalItems: 2519));
    when(() => cash.businessBalances()).thenAnswer(
      (_) async => const [Balance(currency: 'CUP', amount: 1250000), Balance(currency: 'USD', amount: 15840)],
    );
    when(() => cash.couriers()).thenAnswer(
      (_) async => const [
        CourierCash(
          courierId: 'k1',
          name: 'Luis Alberto Fernández',
          balances: [
            Balance(currency: 'CUP', amount: -82000),
            Balance(currency: 'USD', amount: 300),
          ],
          negative: true,
        ),
      ],
    );
    when(() => cash.businessMovements()).thenAnswer(
      (_) async => [
        CashMovement.fromJson(const {
          'id': 'm1',
          'type': 'COURIER_FUNDING',
          'fromType': 'BUSINESS',
          'toType': 'COURIER',
          'toOwnerId': 'k1',
          'amount': 100000,
          'signedAmount': -100000,
          'currency': 'CUP',
          'note': 'Fondos para las entregas del lunes en Boyeros',
          'occurredAt': '2026-10-09T10:00:00Z',
        }),
      ],
    );
    when(
      () => cash.exchanges(
        review: any(named: 'review'),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => const PageResult(items: [], page: 0, size: 20, totalItems: 0));
    when(() => cash.courierStatement('k1')).thenAnswer(
      (_) async => CourierStatement(
        cash: const CourierCash(
          courierId: 'k1',
          name: 'Luis Alberto Fernández',
          balances: [
            Balance(currency: 'CUP', amount: -82000),
            Balance(currency: 'USD', amount: 300),
          ],
          negative: true,
        ),
        movements: [
          for (final (type, signed) in [
            ('COURIER_FUNDING', 100000),
            ('DELIVERY_PAYOUT', -182000),
            ('COURIER_RETURN', -50),
          ])
            CashMovement.fromJson({
              'id': type,
              'type': type,
              'amount': signed.abs(),
              'signedAmount': signed,
              'currency': signed.abs() > 1000 ? 'CUP' : 'USD',
              'note': 'Entrega OT-ABC123 en Boyeros, La Habana',
              'remittanceId': type == 'DELIVERY_PAYOUT' ? 'r1' : null,
              'occurredAt': '2026-10-09T10:00:00Z',
            }),
        ],
      ),
    );
    when(() => reports.monthly(any(), any())).thenAnswer((_) async => MonthlyReport.fromJson(sampleJson));
    when(
      () => audit.search(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => PageResult(items: _audit, page: 0, size: 50, totalItems: 6));
    when(() => users.list()).thenAnswer((_) async => [..._users]);
    when(() => roles.list()).thenAnswer((_) async => const []);
  });

  Future<void> pumpOnPhone(WidgetTester tester, String name, Widget page, {double height = 844}) async {
    final auth = _MockAuth();
    when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
    final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
      ..add(
        AuthLoggedIn(
          CurrentUser(
            id: 'u1',
            email: 'admin@ottos.test',
            name: 'Admin',
            type: '',
            roles: const [],
            permissions: const {
              Permissions.usersRead,
              Permissions.usersWrite,
              Permissions.rolesRead,
              Permissions.rolesWrite,
              Permissions.ratesRead,
              Permissions.configurationRead,
              Permissions.configurationWrite,
              Permissions.customersRead,
              Permissions.customersWrite,
              Permissions.customersExport,
              Permissions.customersImport,
              Permissions.remittancesCreate,
              Permissions.remittancesRead,
              Permissions.remittancesReadFinancials,
              Permissions.remittancesAssign,
              Permissions.remittancesPostpone,
              Permissions.remittancesReview,
              Permissions.remittancesVoid,
              Permissions.remittancesHistorical,
              Permissions.remittancesCompleteFromBusiness,
              Permissions.auditRead,
              Permissions.reportsRead,
              Permissions.cashRead,
              Permissions.cashWrite,
              Permissions.cashAdjust,
              Permissions.cashReview,
            },
          ),
        ),
      );
    addTearDown(authBloc.close);
    tester.view.physicalSize = Size(_phone.width, height) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CustomerRepository>.value(value: customers),
          RepositoryProvider<RemittanceRepository>.value(value: remittances),
          RepositoryProvider<CashRepository>.value(value: cash),
          RepositoryProvider<ReportRepository>.value(value: reports),
          RepositoryProvider<AuditRepository>.value(value: audit),
          RepositoryProvider<UserRepository>.value(value: users),
          RepositoryProvider<RoleRepository>.value(value: roles),
        ],
        child: BlocProvider.value(
          value: authBloc,
          child: MaterialApp(
            theme: OttosTheme.light().copyWith(textTheme: OttosTheme.light().textTheme.apply(fontFamily: 'Roboto')),
            localizationsDelegates: OttosLocalization.delegates,
            supportedLocales: OttosLocalization.supportedLocales,
            home: Scaffold(body: page),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (_shots case final dir?) {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile(Uri.file('$dir/$name.png')));
    }
  }

  // Each page fits a phone: no overflow and nothing wider than the screen.
  for (final (name, page) in [
    ('remittances', const RemittanceListPage()),
    ('customers', const CustomerListPage()),
    ('beneficiaries', const BeneficiaryListPage()),
    ('cash', const CashPage()),
    ('reports', const ReportsPage()),
    ('audit', const AuditPage()),
    ('users', const UserListPage()),
    ('courier_cash', const CourierCashPage(courierId: 'k1')),
  ]) {
    testWidgets('$name fits a phone', (tester) async {
      // The cash pages scroll: tall enough to see every section.
      await pumpOnPhone(tester, name, page, height: name.contains('cash') ? 1800 : 844);
      expect(tester.takeException(), isNull);
    });
  }
}
