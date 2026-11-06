/// REQ-022 batch 1 against a running backend: sales' open list with its totals in one call (OPT-F3) and gzipped
/// answers (OPT-B2, backend PR) read by the client. Works with a backend with or without compression.
///
/// ```sh
/// OTTOS_TEST_EMAIL=admin@ottos.local OTTOS_TEST_PASSWORD=... flutter test --tags integration test/integration
/// ```
///
/// `OTTOS_TEST_API_URL` overrides the backend origin (default `http://localhost:8080`); `OTTOS_TEST_EXPECT_GZIP=true`
/// also requires the answer to come gzipped. Reads only.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

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
  final origin = env['OTTOS_TEST_API_URL'] ?? 'http://localhost:8080';
  final skip = email.isEmpty || password.isEmpty ? 'Set OTTOS_TEST_EMAIL and OTTOS_TEST_PASSWORD' : null;

  late _MemoryTokenStorage storage;
  late ApiClient api;
  late RemittanceRepository remittances;

  setUp(() async {
    storage = _MemoryTokenStorage();
    api = ApiClient(
      config: AppConfig(apiUrl: origin),
      tokenStorage: storage,
    );
    remittances = RemittanceRepository(api: api);
    await AuthRepository(api: api, tokenStorage: storage).login(email: email, password: password);
  });

  tearDown(() => api.dispose());

  group('REQ-022', () {
    test('OPT-F3: the open ones come with their totals in one call, none final or voided', () async {
      final workflow = await remittances.workflow();

      final (:page, :totals) = await remittances.pending(size: 100);

      expect(totals, isNotNull, reason: 'rc.11 and later send the totals');
      for (final remittance in page.items) {
        expect(workflow.isFinal(remittance.status), isFalse, reason: remittance.code);
        expect(remittance.isVoided, isFalse, reason: remittance.code);
      }
      expect(page.items.length, page.totalItems < 100 ? page.totalItems : 100);
      if (page.totalItems <= 100) {
        // Each open delivery is in one «to deliver» group (BR-2 of REQ-021).
        final deliveries = page.items.where((r) => r.type == RemittanceType.delivery).length;
        expect(totals!.toDeliver.fold<int>(0, (sum, group) => sum + group.remittances), deliveries);
      }
    });

    test('OPT-F3: the open ones include those older than the latest 100 of any status', () async {
      final workflow = await remittances.workflow();
      // Every open one, found by reading every page of the whole list.
      final open = <String>{};
      for (var number = 0; ; number++) {
        final all = await remittances.search(const RemittanceFilter(voided: false), page: number, size: 100);
        open.addAll(all.items.where((r) => !workflow.isFinal(r.status)).map((r) => r.id));
        if (number + 1 >= all.totalPages) break;
      }

      final (:page, totals: _) = await remittances.pending(size: 100);

      expect(page.totalItems, open.length);
      if (open.length <= 100) expect(page.items.map((r) => r.id).toSet(), open);
    });

    test('OPT-F3: the completed list asks every final status in one filter', () async {
      final finals = [
        for (final status in (await remittances.workflow()).statuses)
          if (status.isFinal) status.code,
      ];

      final page = await remittances.search(RemittanceFilter(voided: false, status: finals.join(',')), size: 50);

      expect(page.items.every((r) => finals.contains(r.status) && !r.isVoided), isTrue);
    });

    test('OPT-B2: a gzipped answer reads the same as a plain one', () async {
      final token = storage.tokens!.accessToken;
      Future<(String, bool)> get({required bool gzip}) async {
        final client = HttpClient()..autoUncompress = true;
        try {
          final request = await client.getUrl(Uri.parse('$origin/api/v1/remittances?size=100'));
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
          request.headers.set(HttpHeaders.acceptEncodingHeader, gzip ? 'gzip' : 'identity');
          final response = await request.close();
          expect(response.statusCode, 200);
          final compressed = response.compressionState == HttpClientResponseCompressionState.decompressed;
          return (await response.transform(utf8.decoder).join(), compressed);
        } finally {
          client.close();
        }
      }

      final (plain, plainCompressed) = await get(gzip: false);
      final (decoded, compressed) = await get(gzip: true);

      expect(plainCompressed, isFalse);
      expect(jsonDecode(decoded), jsonDecode(plain));
      // And through the client the apps use (dio, which asks for gzip by default on mobile).
      final page = await remittances.search(const RemittanceFilter(), size: 100);
      expect(page.items.length, (jsonDecode(plain) as Map<String, dynamic>)['items'].length);
      // OTTOS_TEST_EXPECT_GZIP=true for a backend that compresses (from REQ-022 batch 1).
      if (env['OTTOS_TEST_EXPECT_GZIP'] == 'true') expect(compressed, isTrue, reason: 'gzip on the wire');
    });
  }, skip: skip);
}
