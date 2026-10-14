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
    PageResult<Beneficiary> page(List<Beneficiary> items, {int total = 2}) =>
        PageResult(items: items, page: 0, size: 50, totalItems: total);

    test('lists the first page, searches after the delay and keeps edited ones in place', () async {
      when(() => customers.beneficiaryPage('', page: 0, size: 50))
          .thenAnswer((_) async => page(const [_rosa, _suelto]));
      when(() => customers.beneficiaryPage('su', page: 0, size: 50))
          .thenAnswer((_) async => page(const [_suelto], total: 1));
      final cubit = BeneficiaryListCubit(customers: customers, searchDelay: Duration.zero);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.beneficiaries, const [_rosa, _suelto]);

      const renamed = Beneficiary(id: 'b2', fullName: 'Juana', phone: '5352220002');
      await cubit.saved(renamed);
      expect(cubit.state.beneficiaries.map((b) => b.fullName), ['Rosa', 'Juana']);
      expect(cubit.state.result?.totalItems, 2);
      verify(() => customers.beneficiaryPage('', page: 0, size: 50)).called(1);

      cubit.queryChanged('su');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.query, 'su');
      expect(cubit.state.beneficiaries, const [_suelto]);
      expect(cubit.state.result?.totalItems, 1);
    });

    test('a new beneficiary loads the first page again', () async {
      const created = Beneficiary(id: 'b3', fullName: 'Nueva', phone: '5352220003');
      var calls = 0;
      when(() => customers.beneficiaryPage('', page: 0, size: 50)).thenAnswer(
        (_) async => ++calls == 1 ? page(const [_rosa, _suelto]) : page(const [created, _rosa, _suelto], total: 3),
      );
      final cubit = BeneficiaryListCubit(customers: customers);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.saved(created);

      expect(cubit.state.beneficiaries.first, created);
      expect(cubit.state.result?.totalItems, 3);
    });

    test('reports a failed search', () async {
      when(() => customers.beneficiaryPage('', page: 0, size: 50))
          .thenThrow(const ApiException(CoreTexts.networkError));
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

    setUp(
      () => when(
        () => customers.beneficiaryPage(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((_) async => const PageResult(items: [_rosa, _suelto], page: 0, size: 50, totalItems: 120)),
    );

    testWidgets('shows the total and moves to the next page', (tester) async {
      await pump(tester, {Permissions.customersRead});

      expect(find.text(OpsTexts.pageOf(1, 2, 120)), findsOneWidget);
      await tester.tap(find.byTooltip(OpsTexts.nextPage));
      await tester.pumpAndSettle();

      verify(() => customers.beneficiaryPage('', page: 1, size: 50)).called(1);
    });

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
