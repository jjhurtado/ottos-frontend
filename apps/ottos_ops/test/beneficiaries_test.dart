import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';
import 'package:ottos_ops/features/beneficiaries/cubit/beneficiary_list_cubit.dart';
import 'package:ottos_ops/features/beneficiaries/view/beneficiary_list_page.dart';

class _MockCustomers extends Mock implements CustomerRepository {}

class _MockZones extends Mock implements ZoneRepository {}

class _MockAuth extends Mock implements AuthRepository {}

const _rosa = Beneficiary(
  id: 'b1',
  fullName: 'Rosa',
  phone: '5352220001',
  street: 'Calle 10',
  houseNumber: '1',
  municipalityCode: '2310',
  municipalityName: 'Boyeros',
  provinceName: 'La Habana',
);
// Imported without a customer: only this screen reaches them.
const _suelto = Beneficiary(id: 'b2', fullName: 'Beneficiario Suelto', phone: '5352220002', street: 'Calle 3');

void main() {
  late _MockCustomers customers;
  late _MockZones zones;

  setUpAll(
    () => registerFallbackValue(const BeneficiaryInput(fullName: '', phone: '', street: '', municipalityCode: '')),
  );

  setUp(() {
    customers = _MockCustomers();
    zones = _MockZones();
    when(() => zones.provinces()).thenAnswer((_) async => const [Province(code: '23', name: 'La Habana')]);
    when(() => zones.municipalities())
        .thenAnswer((_) async => const [Municipality(code: '2310', name: 'Boyeros', provinceCode: '23')]);
  });

  group('cubit', () {
    test('lists the most recent, searches after the delay and keeps saved ones in place', () async {
      when(() => customers.searchBeneficiaries('')).thenAnswer((_) async => const [_rosa, _suelto]);
      when(() => customers.searchBeneficiaries('su')).thenAnswer((_) async => const [_suelto]);
      final cubit = BeneficiaryListCubit(customers: customers, searchDelay: Duration.zero);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.beneficiaries, const [_rosa, _suelto]);

      const renamed = Beneficiary(id: 'b2', fullName: 'Juana', phone: '5352220002');
      cubit.saved(renamed);
      expect(cubit.state.beneficiaries.map((b) => b.fullName), ['Rosa', 'Juana']);
      const created = Beneficiary(id: 'b3', fullName: 'Nueva', phone: '5352220003');
      cubit.saved(created);
      expect(cubit.state.beneficiaries.first, created);

      cubit.queryChanged('su');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.query, 'su');
      expect(cubit.state.beneficiaries, const [_suelto]);
    });

    test('reports a failed search', () async {
      when(() => customers.searchBeneficiaries('')).thenThrow(const ApiException(CoreTexts.networkError));
      final cubit = BeneficiaryListCubit(customers: customers);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, BeneficiaryListStatus.failure);
      expect(cubit.state.error, CoreTexts.networkError);
    });
  });

  group('page', () {
    Future<void> pump(WidgetTester tester, Set<String> permissions) async {
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
            RepositoryProvider<CustomerRepository>.value(value: customers),
            RepositoryProvider<ZoneRepository>.value(value: zones),
          ],
          child: BlocProvider.value(
            value: authBloc,
            child: const MaterialApp(home: Scaffold(body: BeneficiaryListPage())),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => when(() => customers.searchBeneficiaries(any())).thenAnswer((_) async => const [_rosa, _suelto]));

    testWidgets('a beneficiary without a customer can be edited', (tester) async {
      when(() => customers.updateBeneficiary('b2', any())).thenAnswer(
        (_) async => const Beneficiary(id: 'b2', fullName: 'Juana Suelta', phone: '5352220002', street: 'Calle 3'),
      );
      await pump(tester, {Permissions.customersRead, Permissions.customersWrite});
      expect(find.text('Calle 10 #1, Boyeros, La Habana'), findsOneWidget);

      await tester.tap(find.byTooltip(OpsTexts.edit).last);
      await tester.pumpAndSettle();
      expect(find.text(OpsTexts.editBeneficiary), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Beneficiario Suelto'), 'Juana Suelta');
      // Imported without a municipality: the form asks for one before saving.
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, '${CoreTexts.province} *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('La Habana').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, '${CoreTexts.municipality} *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boyeros').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(CoreTexts.save));
      await tester.pumpAndSettle();

      final input = verify(() => customers.updateBeneficiary('b2', captureAny())).captured.single as BeneficiaryInput;
      expect(input.fullName, 'Juana Suelta');
      expect(input.municipalityCode, '2310');
      expect(find.text('Juana Suelta'), findsOneWidget);
    });

    testWidgets('a new beneficiary is created without a customer', (tester) async {
      await pump(tester, {Permissions.customersRead, Permissions.customersWrite});

      await tester.tap(find.text(OpsTexts.newBeneficiary));
      await tester.pumpAndSettle();

      expect(find.text(CoreTexts.newBeneficiary), findsNWidgets(2));
      expect(find.text(CoreTexts.pickFromContacts), findsNothing);
    });

    testWidgets('who can only read sees the list without edit buttons', (tester) async {
      await pump(tester, {Permissions.customersRead});

      expect(find.text('Beneficiario Suelto'), findsOneWidget);
      expect(find.byTooltip(OpsTexts.edit), findsNothing);
      expect(find.text(OpsTexts.newBeneficiary), findsNothing);
    });
  });
}
