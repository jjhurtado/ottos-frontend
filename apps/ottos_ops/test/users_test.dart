import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/users/cubit/user_list_cubit.dart';
import 'package:ottos_ops/features/users/view/user_list_page.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockRoles extends Mock implements RoleRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _admin = RoleSummary(id: 'r1', code: 'ADMIN', name: 'Administrador');
const _sales = RoleSummary(id: 'r2', code: 'SALES', name: 'Ventas');
const _me = StaffUser(id: 'u1', email: 'admin@ottos.test', name: 'Admin', roles: [_admin]);
const _ana = StaffUser(id: 'u2', email: 'ana@ottos.test', name: 'ana', roles: [_sales]);
const _old = StaffUser(id: 'u3', email: 'old@ottos.test', name: 'Zoe', active: false, roles: [_sales]);
const _roles = [
  Role(id: 'r1', code: 'ADMIN', name: 'Administrador', builtIn: true),
  Role(id: 'r2', code: 'SALES', name: 'Ventas'),
];

void main() {
  late _MockUsers users;
  late _MockRoles roles;

  setUpAll(() => registerFallbackValue(const NewStaffUser(email: '', name: '', password: '', roleIds: {})));

  setUp(() {
    users = _MockUsers();
    roles = _MockRoles();
    when(() => users.list()).thenAnswer((_) async => [_old, _me, _ana]);
    when(() => roles.list()).thenAnswer((_) async => _roles);
  });

  group('cubit', () {
    test('sorts by name and hides inactive users until asked', () async {
      final cubit = UserListCubit(users: users);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.visible.map((u) => u.name), ['Admin', 'ana']);
      expect(cubit.state.inactiveCount, 1);

      cubit.showInactiveChanged(true);
      expect(cubit.state.visible.map((u) => u.name), ['Admin', 'ana', 'Zoe']);
    });

    test('searches by name, email or role', () async {
      final cubit = UserListCubit(users: users);
      addTearDown(cubit.close);
      await cubit.load();

      cubit.queryChanged('ANA@');
      expect(cubit.state.visible, [_ana]);
      cubit.queryChanged('ventas');
      expect(cubit.state.visible, [_ana]);
    });
  });

  group('page', () {
    Future<void> pumpUsers(WidgetTester tester, Set<String> permissions) async {
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
              permissions: permissions,
            ),
          ),
        );
      addTearDown(authBloc.close);
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<UserRepository>.value(value: users),
            RepositoryProvider<RoleRepository>.value(value: roles),
          ],
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(home: Scaffold(body: UserListPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const writer = {Permissions.usersRead, Permissions.usersWrite, Permissions.rolesRead};

    testWidgets('you cannot deactivate yourself', (tester) async {
      await pumpUsers(tester, writer);

      await tester.tap(find.byTooltip(OpsTexts.actions).first);
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.resetPassword), findsOneWidget);
      expect(find.text(OpsTexts.deactivate), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(OpsTexts.actions).last);
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.deactivate), findsOneWidget);
    });

    testWidgets('a reader sees the users without actions', (tester) async {
      await pumpUsers(tester, {Permissions.usersRead});

      expect(find.text('ana'), findsOneWidget);
      expect(find.text(OpsTexts.newUser), findsNothing);
      expect(find.byTooltip(OpsTexts.actions), findsNothing);
    });

    testWidgets('a new user needs a role and a valid password', (tester) async {
      when(() => users.create(any())).thenAnswer((_) async => _ana);
      await pumpUsers(tester, writer);

      await tester.tap(find.text(OpsTexts.newUser));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.email} *'), 'luis@ottos.test');
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.fullName} *'), 'Luis');
      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.initialPassword} *'), 'short');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();
      expect(find.text(CoreTexts.passwordTooShort), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, '${OpsTexts.initialPassword} *'), 'long-enough');
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.chooseRole), findsOneWidget);
      verifyNever(() => users.create(any()));

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Ventas'));
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();
      verify(
        () => users.create(
          const NewStaffUser(email: 'luis@ottos.test', name: 'Luis', password: 'long-enough', roleIds: {'r2'}),
        ),
      ).called(1);
      expect(find.text(OpsTexts.userCreated('ana')), findsOneWidget);
    });

    testWidgets('editing saves only what changed', (tester) async {
      when(() => users.replaceRoles('u2', {'r1', 'r2'})).thenAnswer((_) async => _ana);
      await pumpUsers(tester, writer);

      await tester.tap(find.byTooltip(OpsTexts.actions).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(OpsTexts.edit));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Administrador'));
      await tester.tap(find.text(OpsTexts.save));
      await tester.pumpAndSettle();

      verify(() => users.replaceRoles('u2', {'r1', 'r2'})).called(1);
      verifyNever(() => users.rename(any(), any()));
      expect(find.text(OpsTexts.userSaved), findsOneWidget);
    });
  });
}
