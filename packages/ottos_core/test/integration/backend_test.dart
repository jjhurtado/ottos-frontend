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
