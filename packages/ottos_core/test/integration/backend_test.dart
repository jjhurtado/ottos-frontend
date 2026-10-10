/// End-to-end check of the shared client against a running backend: login,
/// session restore, token refresh and the remittance endpoints the apps use.
///
/// Skipped unless credentials are given:
///
/// ```sh
/// OTTOS_TEST_EMAIL=admin@ottos.local OTTOS_TEST_PASSWORD=... flutter test test/integration
/// ```
///
/// `OTTOS_TEST_API_URL` overrides the backend origin (default `http://localhost:8080`).
/// The user needs `remittances:read`; nothing is written except sessions.
@Tags(['integration'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

class _MemoryTokenStorage implements TokenStorage {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}

void main() {
  final env = Platform.environment;
  final email = env['OTTOS_TEST_EMAIL'] ?? '';
  final password = env['OTTOS_TEST_PASSWORD'] ?? '';
  final config = AppConfig(apiUrl: env['OTTOS_TEST_API_URL'] ?? 'http://localhost:8080');
  final skip = email.isEmpty || password.isEmpty ? 'Set OTTOS_TEST_EMAIL and OTTOS_TEST_PASSWORD' : null;

  late _MemoryTokenStorage storage;
  late ApiClient api;
  late AuthRepository auth;
  late RemittanceRepository remittances;

  setUp(() {
    storage = _MemoryTokenStorage();
    api = ApiClient(config: config, tokenStorage: storage);
    auth = AuthRepository(api: api, tokenStorage: storage);
    remittances = RemittanceRepository(api: api);
  });

  tearDown(() => api.dispose());

  group('auth', () {
    test('rejects wrong credentials with a user-facing message', () async {
      await expectLater(
        auth.login(email: email, password: '$password-wrong'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', CoreTexts.invalidCredentials)),
      );
      expect(storage.tokens, isNull);
    });

    test('logs in, stores tokens and loads the current user', () async {
      final user = await auth.login(email: '  $email ', password: password);

      expect(user.email, email.toLowerCase());
      expect(user.can(Permissions.remittancesRead), isTrue);
      expect(storage.tokens, isNotNull);
      expect(await auth.restoreSession(), user);
    });

    test('refreshes an expired access token and retries the request', () async {
      await auth.login(email: email, password: password);
      final refreshToken = storage.tokens!.refreshToken;
      storage.tokens = AuthTokens(accessToken: 'expired', refreshToken: refreshToken);

      final user = await auth.currentUser();

      expect(user.email, email.toLowerCase());
      expect(storage.tokens!.accessToken, isNot('expired'));
    });

    test('expires the session when the refresh token is no longer valid', () async {
      final expired = expectLater(api.sessionExpired, emits(null));
      storage.tokens = const AuthTokens(accessToken: 'expired', refreshToken: 'revoked');

      await expectLater(
        auth.currentUser(),
        throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
      );
      await expired;
      expect(storage.tokens, isNull);
    });

    test('logout revokes the refresh token', () async {
      await auth.login(email: email, password: password);
      final tokens = storage.tokens!;

      await auth.logout();

      expect(storage.tokens, isNull);
      storage.tokens = AuthTokens(accessToken: 'expired', refreshToken: tokens.refreshToken);
      await expectLater(auth.currentUser(), throwsA(isA<ApiException>()));
    });
  }, skip: skip);

  group('remittances', () {
    setUp(() => auth.login(email: email, password: password));

    test('loads the workflow', () async {
      final workflow = await remittances.workflow();

      expect(workflow.statuses, isNotEmpty);
      expect(workflow.statuses.where((status) => status.isInitial), hasLength(1));
      expect(workflow.transitions, isNotEmpty);
    });

    test('searches, then loads one remittance by id and by code, with its history', () async {
      final page = await remittances.search(const RemittanceFilter(), size: 5);

      expect(page.items.length, lessThanOrEqualTo(5));
      expect(page.totalItems, greaterThanOrEqualTo(page.items.length));
      if (page.items.isEmpty) {
        markTestSkipped('No remittances in the backend to load');
        return;
      }

      final first = page.items.first;
      final byId = await remittances.get(first.id);
      final byCode = await remittances.getByCode(first.code);
      final events = await remittances.events(first.id);

      expect(byId, first);
      expect(byCode.id, first.id);
      expect(events, isNotEmpty);
    });

    test('filters by status', () async {
      final workflow = await remittances.workflow();
      final status = workflow.statuses.first.code;

      final page = await remittances.search(RemittanceFilter(status: status));

      expect(page.items.every((remittance) => remittance.status == status), isTrue);
    });

    test('reports a missing remittance as not found', () async {
      await expectLater(
        remittances.get('00000000-0000-0000-0000-000000000000'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  }, skip: skip);

  // Writes to the backend: registers one remittance per run and delivers it.
  group('remittance flow', () {
    late CustomerRepository customers;
    late RateRepository rates;

    setUp(() async {
      customers = CustomerRepository(api: api);
      rates = RateRepository(api: api);
      await auth.login(email: email, password: password);
    });

    test('registers, assigns and delivers a remittance', () async {
      // A customer with a beneficiary and a currency with a rate, as the form offers them.
      Customer? customer;
      Beneficiary? beneficiary;
      for (final candidate in await customers.search('')) {
        final linked = (await customers.beneficiaries(candidate.id)).where((b) => b.active);
        if (candidate.active && linked.isNotEmpty) {
          (customer, beneficiary) = (candidate, linked.first);
          break;
        }
      }
      final currency = (await rates.corridors())
          .where((corridor) => corridor.canQuote && corridor.sourceCurrency == 'USD')
          .map((corridor) => corridor.targetCurrency)
          .firstOrNull;
      if (customer == null || beneficiary == null || currency == null) {
        markTestSkipped('Needs a customer with a beneficiary and a corridor with a rate');
        return;
      }

      final quote = await rates.quote(sourceCurrency: 'USD', targetCurrency: currency, amount: 100);
      expect(quote.total, greaterThan(quote.amount));

      final newRemittance = NewRemittance(
        type: RemittanceType.delivery,
        customerId: customer.id,
        beneficiaryId: beneficiary.id,
        amount: 100,
        targetCurrency: currency,
        notes: 'Frontend integration test',
      );
      final key = RemittanceRepository.newIdempotencyKey();
      final created = await remittances.register(newRemittance, idempotencyKey: key);
      final retried = await remittances.register(newRemittance, idempotencyKey: key);
      expect(retried.id, created.id, reason: 'same Idempotency-Key, same remittance');
      expect(created.amountToDeliver, quote.amountToDeliver);

      final workflow = await remittances.workflow();
      const admin = {Permissions.remittancesAssign, Permissions.remittancesDeliver};
      expect(workflow.canAssign(created.status, admin), isTrue);

      final couriers = await remittances.couriers();
      final courier = couriers.firstWhere((c) => c.email != email, orElse: () => couriers.first);
      final assigned = await remittances.assign(created.id, courierId: courier.id, note: 'Integration test');
      expect(assigned.courierId, courier.id);
      expect(workflow.canComplete(assigned.status, admin), isTrue);

      await expectLater(
        remittances.deliverWithPin(created.id, pin: assigned.pin == '000000' ? '111111' : '000000'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INCORRECT_PIN')),
      );
      final delivered = await remittances.deliverWithPin(created.id, pin: assigned.pin!);
      expect(workflow.isFinal(delivered.status), isTrue);
      expect(delivered.completedAt, isNotNull);

      final history = await remittances.events(created.id);
      expect(
        history.map((event) => event.toStatus),
        containsAllInOrder([created.status, assigned.status, delivered.status]),
      );
    });
  }, skip: skip);

  // Writes to the backend: registers one customer and two beneficiaries per run.
  group('customers', () {
    late CustomerRepository customers;
    late ZoneRepository zones;

    setUp(() async {
      customers = CustomerRepository(api: api);
      zones = ZoneRepository(api: api);
      await auth.login(email: email, password: password);
    });

    test('registers and edits a customer and their beneficiaries', () async {
      final phone = '+1305${Random().nextInt(9000000) + 1000000}';
      final created = await customers.create(CustomerInput(fullName: 'Prueba Frontend', phone: phone, email: ' '));
      expect(created.fullName, 'Prueba Frontend');
      expect(created.email, isNull);
      expect((await customers.search(phone.substring(4))).map((c) => c.id), contains(created.id));

      await expectLater(
        customers.create(CustomerInput(fullName: 'Duplicado', phone: phone)),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'PHONE_ALREADY_REGISTERED')),
      );

      final updated = await customers.update(
        created.id,
        CustomerInput.of(created).copyWithName('Prueba Frontend Editada'),
      );
      expect(updated.fullName, 'Prueba Frontend Editada');

      final provinces = await zones.provinces();
      final municipality = (await zones.municipalities()).firstWhere((m) => m.provinceCode == provinces.first.code);
      final input = BeneficiaryInput(
        fullName: 'Beneficiaria Prueba',
        phone: '5352${Random().nextInt(900000) + 100000}',
        street: 'Calle 1',
        municipalityCode: municipality.code,
      );
      final beneficiary = await customers.addBeneficiary(created.id, input);
      expect(beneficiary.municipalityName, municipality.name);

      final edited = await customers.updateBeneficiary(
        beneficiary.id,
        BeneficiaryInput.of(beneficiary).copyWithStreet('Calle 2'),
      );
      expect(edited.street, 'Calle 2');
      expect((await customers.beneficiaries(created.id)).map((b) => b.id), [beneficiary.id]);

      await customers.unlinkBeneficiary(created.id, beneficiary.id);
      expect(await customers.beneficiaries(created.id), isEmpty);

      await expectLater(
        customers.addBeneficiary(created.id, BeneficiaryInput.of(beneficiary).copyWithMunicipality('9999')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', anyOf(400, 404))),
      );
    });
  }, skip: skip);

  // Writes to the backend: each operation is undone by its opposite, so balances end as they started.
  group('cash', () {
    late CashRepository cash;

    setUp(() async {
      cash = CashRepository(api: api);
      await auth.login(email: email, password: password);
    });

    double balanceOf(List<Balance> balances, String currency) =>
        balances.where((b) => b.currency == currency).fold(0, (sum, b) => sum + b.amount);

    test('deposits and withdraws from the business box', () async {
      final before = balanceOf(await cash.businessBalances(), 'USD');

      final deposit = await cash.deposit(const CashInput(amount: 12.5, currency: 'USD', note: 'Integration test'));
      expect(deposit.type, CashMovementType.businessDeposit);
      expect(balanceOf(await cash.businessBalances(), 'USD'), before + 12.5);

      await cash.withdraw(const CashInput(amount: 12.5, currency: 'USD', note: 'Integration test'));
      expect(balanceOf(await cash.businessBalances(), 'USD'), before);

      await expectLater(
        cash.deposit(const CashInput(amount: 1, currency: 'USD')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_FAILED')),
      );
      final latest = await cash.businessMovements();
      expect(latest.first.type, CashMovementType.businessWithdrawal);
    });

    test('funds a courier and registers the return', () async {
      final couriers = await cash.couriers();
      if (couriers.isEmpty) {
        markTestSkipped('No courier with cash movements');
        return;
      }
      final courier = couriers.first;
      final before = balanceOf((await cash.courierStatement(courier.courierId)).cash.balances, 'USD');

      final funding = await cash.fundCourier(courier.courierId, const CashInput(amount: 20, currency: 'USD'));
      expect(funding.toOwnerId, courier.courierId);
      final funded = await cash.courierStatement(courier.courierId);
      expect(balanceOf(funded.cash.balances, 'USD'), before + 20);
      expect(funded.movements.first.type, CashMovementType.courierFunding);

      await cash.courierReturn(courier.courierId, const CashInput(amount: 20, currency: 'USD'));
      expect(balanceOf((await cash.courierStatement(courier.courierId)).cash.balances, 'USD'), before);
    });

    test('lists the movements of a delivered remittance', () async {
      final delivered = (await RemittanceRepository(
        api: api,
      ).search(const RemittanceFilter(status: 'DELIVERED'), size: 1)).items.firstOrNull;
      if (delivered == null) {
        markTestSkipped('No delivered remittance');
        return;
      }

      final movements = await cash.remittanceMovements(delivered.id);

      expect(movements.map((m) => m.type), contains(CashMovementType.remittancePayment));
      expect(movements.every((m) => m.remittanceId == delivered.id), isTrue);
    });
  }, skip: skip);

  // Writes to the backend: saves a rate, a fee rule and settings equal to the ones in force, so nothing changes.
  group('rates', () {
    late RateRepository rates;

    setUp(() async {
      rates = RateRepository(api: api);
      await auth.login(email: email, password: password);
    });

    test('re-saves the rate and fee rule in force and finds them first in the history', () async {
      final corridor = (await rates.corridors())
          .where((c) => c.canQuote && !c.hasFixedRate && c.feeRule != null)
          .firstOrNull;
      if (corridor == null) {
        markTestSkipped('Needs a corridor with a rate and a fee rule');
        return;
      }
      final rule = corridor.feeRule!;

      final rate = await rates.setRate(corridor.code, corridor.currentRate!);
      final feeRule = await rates.setFeeRule(
        corridor.code,
        FeeRuleInput(type: rule.type, value: rule.value, minFee: rule.minFee, maxFee: rule.maxFee),
      );

      expect((await rates.rateHistory(corridor.code)).first.id, rate.id);
      expect((await rates.feeRuleHistory(corridor.code)).first.id, feeRule.id);
      final refreshed = (await rates.corridors()).firstWhere((c) => c.code == corridor.code);
      expect(refreshed.rate?.id, rate.id);
      expect(refreshed.feeRule?.value, rule.value);
    });

    test('re-saves the settings in force', () async {
      final settings = await rates.settings();

      final saved = await rates.updateSettings(
        minimumAmount: settings.minimumAmount,
        defaultDeliveryDays: settings.defaultDeliveryDays,
      );

      expect(saved, settings);
      await expectLater(
        rates.updateSettings(defaultDeliveryDays: 0),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'VALIDATION_FAILED')),
      );
      expect(await rates.settings(), settings);
    });

    test('rejects a rate for a same-currency corridor and a percentage over 100', () async {
      final corridors = await rates.corridors();
      final fixed = corridors.where((c) => c.hasFixedRate).firstOrNull;
      if (fixed != null) {
        await expectLater(
          rates.setRate(fixed.code, 2),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FIXED_RATE')),
        );
      }
      await expectLater(
        rates.setFeeRule(corridors.first.code, const FeeRuleInput(type: FeeType.percentage, value: 150)),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FEE_PERCENTAGE_TOO_HIGH')),
      );
    });
  }, skip: skip);

  // Writes to the backend: creates one staff user per run and leaves it deactivated.
  group('users', () {
    late UserRepository users;

    setUp(() async {
      users = UserRepository(api: api);
      await auth.login(email: email, password: password);
    });

    /// Logs in as another user with a client of its own; returns null if refused.
    Future<CurrentUser?> loginAs(String userEmail, String userPassword) async {
      final storage = _MemoryTokenStorage();
      final client = ApiClient(config: config, tokenStorage: storage);
      try {
        return await AuthRepository(api: client, tokenStorage: storage).login(email: userEmail, password: userPassword);
      } on ApiException {
        return null;
      } finally {
        await client.dispose();
      }
    }

    test('creates, edits, resets, deactivates and reactivates a user', () async {
      final roles = await RoleRepository(api: api).list();
      final sales = roles.firstWhere((role) => role.code == 'SALES');
      final delivery = roles.firstWhere((role) => role.code == 'DELIVERY');
      final userEmail = 'frontend-test-${Random().nextInt(1 << 32)}@ottos.test';

      final created = await users.create(
        NewStaffUser(email: userEmail, name: 'Prueba Frontend', password: 'first-pass-1', roleIds: {sales.id}),
      );
      expect(created.roles.map((r) => r.code), ['SALES']);
      await expectLater(
        users.create(NewStaffUser(email: userEmail, name: 'Otro', password: 'first-pass-1', roleIds: {sales.id})),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_TAKEN')),
      );

      expect((await users.rename(created.id, 'Prueba Frontend Editada')).name, 'Prueba Frontend Editada');
      final reassigned = await users.replaceRoles(created.id, {sales.id, delivery.id});
      expect(reassigned.roles.map((r) => r.code), containsAll(['SALES', 'DELIVERY']));

      await users.resetPassword(created.id, 'second-pass-2');
      expect(await loginAs(userEmail, 'first-pass-1'), isNull);
      expect((await loginAs(userEmail, 'second-pass-2'))?.can(Permissions.remittancesCreate), isTrue);

      expect((await users.deactivate(created.id)).active, isFalse);
      expect(await loginAs(userEmail, 'second-pass-2'), isNull);
      expect((await users.activate(created.id)).active, isTrue);
      expect(await loginAs(userEmail, 'second-pass-2'), isNotNull);
      await users.deactivate(created.id);
    });

    test('refuses to deactivate yourself', () async {
      final me = await auth.currentUser();

      await expectLater(
        users.deactivate(me.id),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CANNOT_DEACTIVATE_SELF')),
      );
    });
  }, skip: skip);

  // Writes to the backend: creates one role per run and deletes it.
  group('roles', () {
    late RoleRepository roles;

    setUp(() async {
      roles = RoleRepository(api: api);
      await auth.login(email: email, password: password);
    });

    test('creates, describes, re-permissions and deletes a role', () async {
      final catalog = await roles.permissions();
      expect(catalog.map((p) => p.code), contains(Permissions.remittancesRead));
      final code = 'FRONTEND_TEST_${Random().nextInt(1 << 30)}';

      final created = await roles.create(
        NewRole(code: code, name: 'Prueba Frontend', permissions: const {Permissions.remittancesRead}),
      );
      expect(created.permissions, [Permissions.remittancesRead]);
      expect(created.builtIn, isFalse);
      await expectLater(
        roles.create(NewRole(code: code, name: 'Otro')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ROLE_CODE_TAKEN')),
      );

      final described = await roles.describe(created.id, name: 'Prueba Frontend Editada', description: 'Rol de prueba');
      expect(described.description, 'Rol de prueba');
      final permitted = await roles.replacePermissions(created.id, {
        Permissions.remittancesRead,
        Permissions.customersRead,
      });
      expect(permitted.permissions, containsAll([Permissions.remittancesRead, Permissions.customersRead]));

      await roles.delete(created.id);
      expect((await roles.list()).map((r) => r.id), isNot(contains(created.id)));
    });

    test('refuses to change a built-in role', () async {
      final builtIn = (await roles.list()).firstWhere((role) => role.builtIn);

      await expectLater(
        roles.describe(builtIn.id, name: builtIn.name),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'BUILT_IN_ROLE')),
      );
    });
  }, skip: skip);
}

extension on CustomerInput {
  CustomerInput copyWithName(String fullName) => CustomerInput(
    fullName: fullName,
    phone: phone,
    email: email,
    documentType: documentType,
    documentNumber: documentNumber,
    address: address,
    notes: notes,
  );
}

extension on BeneficiaryInput {
  BeneficiaryInput copyWithStreet(String street) => _copy(street: street);

  BeneficiaryInput copyWithMunicipality(String municipalityCode) => _copy(municipalityCode: municipalityCode);

  BeneficiaryInput _copy({String? street, String? municipalityCode}) => BeneficiaryInput(
    fullName: fullName,
    phone: phone,
    street: street ?? this.street,
    municipalityCode: municipalityCode ?? this.municipalityCode,
    alternatePhone: alternatePhone,
    houseNumber: houseNumber,
    betweenStreets: betweenStreets,
    neighborhood: neighborhood,
    reference: reference,
    documentNumber: documentNumber,
    notes: notes,
  );
}
