import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/roles/cubit/roles_cubit.dart';
import 'package:ottos_ops/features/roles/view/role_dialog.dart';
import 'package:ottos_ops/features/roles/view/roles_page.dart';

class _MockRoles extends Mock implements RoleRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _catalog = [
  PermissionInfo(code: Permissions.remittancesRead, module: 'remittances'),
  PermissionInfo(code: Permissions.remittancesCreate, module: 'remittances'),
  PermissionInfo(code: Permissions.cashAdjust, module: 'payments'),
  PermissionInfo(code: 'reports:read', module: 'reporting', description: 'View reports'),
];
const _admin = Role(
  id: 'r1',
  code: 'ADMIN',
  name: 'Administrador',
  builtIn: true,
  permissions: [Permissions.remittancesRead, Permissions.remittancesCreate, Permissions.cashAdjust],
);
const _sales = Role(id: 'r2', code: 'SALES', name: 'ventas', permissions: [Permissions.remittancesRead]);

void main() {
  late _MockRoles roles;

  setUpAll(() => registerFallbackValue(const NewRole(code: '', name: '')));

  setUp(() {
    roles = _MockRoles();
    when(() => roles.list()).thenAnswer((_) async => [_sales, _admin]);
    when(() => roles.permissions()).thenAnswer((_) async => _catalog);
  });

  test('role codes are UPPER_SNAKE_CASE, 2 to 50 characters', () {
    expect(roleCodeError('SUPERVISOR'), isNull);
    expect(roleCodeError('CASH_2'), isNull);
    expect(roleCodeError(''), OpsTexts.requiredField);
    expect(roleCodeError('A'), OpsTexts.roleCodeInvalid);
    expect(roleCodeError('2ND'), OpsTexts.roleCodeInvalid);
    expect(roleCodeError('A${'B' * 50}'), OpsTexts.roleCodeInvalid);
  });

  test('labels permissions in Spanish, falling back to the backend description', () {
    expect(OpsTexts.permissionLabel(_catalog[0]), 'Ver todas las remesas y su historial');
    expect(OpsTexts.permissionLabel(_catalog[3]), 'View reports');
    expect(OpsTexts.permissionModule('reporting'), 'reporting');
  });

  test('lists built-in roles first, then by name', () async {
    final cubit = RolesCubit(roles: roles);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.roles.map((r) => r.code), ['ADMIN', 'SALES']);
    expect(cubit.state.catalog, _catalog);
  });

  group('page', () {
    Future<void> pumpRoles(WidgetTester tester, Set<String> permissions) async {
      final auth = _MockAuth();
      when(() => auth.sessionExpired).thenAnswer((_) => const Stream.empty());
      final authBloc = AuthBloc(authRepository: auth, accessPolicy: (_) => true)
        ..add(
          AuthLoggedIn(
            CurrentUser(
              id: 'u1',
              email: 'u@ottos.test',
              name: 'U',
              type: '',
              roles: const [],
              permissions: permissions,
            ),
          ),
        );
      addTearDown(authBloc.close);
      await tester.binding.setSurfaceSize(const Size(1400, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RepositoryProvider<RoleRepository>.value(
          value: roles,
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(home: Scaffold(body: RolesPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Can manage roles, but lacks cash:adjust.
    const writer = {
      Permissions.rolesRead,
      Permissions.rolesWrite,
      Permissions.remittancesRead,
      Permissions.remittancesCreate,
    };

    testWidgets('built-in roles are read-only', (tester) async {
      await pumpRoles(tester, writer);

      expect(find.text(OpsTexts.builtIn), findsOneWidget);
      expect(find.text(OpsTexts.edit), findsOneWidget, reason: 'only SALES');
      expect(find.text(OpsTexts.newRole), findsOneWidget);
    });

    testWidgets('a reader cannot change roles', (tester) async {
      await pumpRoles(tester, {Permissions.rolesRead});

      expect(find.text('ventas'), findsOneWidget);
      expect(find.text(OpsTexts.newRole), findsNothing);
      expect(find.text(OpsTexts.edit), findsNothing);
    });

    testWidgets('only permissions you have can be granted', (tester) async {
      when(() => roles.create(any())).thenAnswer((_) async => _sales);
      await pumpRoles(tester, writer);

      await tester.tap(find.text(OpsTexts.newRole));
      await tester.pumpAndSettle();
      final cash = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, OpsTexts.permissionLabel(_catalog[2])),
      );
      expect(cash.onChanged, isNull);
      expect(find.text(OpsTexts.onlyYourPermissions), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.roleCode} *'), 'supervisor');
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.roleName} *'), 'Supervisor');
      await tester.tap(find.widgetWithText(CheckboxListTile, OpsTexts.permissionLabel(_catalog[1])));
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(
        () => roles.create(
          const NewRole(
            code: 'SUPERVISOR',
            name: 'Supervisor',
            description: '',
            permissions: {Permissions.remittancesCreate},
          ),
        ),
      ).called(1);
      expect(find.text(OpsTexts.roleCreated('ventas')), findsOneWidget);
    });

    testWidgets('editing saves only what changed', (tester) async {
      when(() => roles.replacePermissions('r2', {Permissions.remittancesRead, Permissions.remittancesCreate}))
          .thenAnswer((_) async => _sales);
      await pumpRoles(tester, writer);

      await tester.tap(find.text(OpsTexts.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, OpsTexts.permissionLabel(_catalog[1])));
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(() => roles.replacePermissions('r2', {Permissions.remittancesRead, Permissions.remittancesCreate}))
          .called(1);
      verifyNever(
        () => roles.describe(
          any(),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      );
    });

    testWidgets('a role in use cannot be deleted', (tester) async {
      when(() => roles.delete('r2'))
          .thenThrow(ApiException(CoreTexts.errorCodes['ROLE_IN_USE']!, statusCode: 409, code: 'ROLE_IN_USE'));
      await pumpRoles(tester, writer);

      await tester.tap(find.widgetWithText(TextButton, OpsTexts.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, OpsTexts.delete));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.errorCodes['ROLE_IN_USE']!), findsOneWidget);
      verify(() => roles.list()).called(1);
    });
  });
}
