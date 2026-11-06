import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockApi extends Mock implements ApiClient {}

/// REQ-022 batch 2 (OPT-F4): the Home counters in one `GET /remittances/summary`.
void main() {
  test('OPT-F4: summary() reads the contract fields, zeros and order kept', () async {
    final api = _MockApi();
    when(() => api.get<Map<String, dynamic>>('/remittances/summary')).thenAnswer(
      (_) async => {
        'openByStatus': [
          {'code': 'PAID', 'name': 'Pagada', 'count': 2},
          {'code': 'ASSIGNED', 'name': 'Asignada', 'count': 0},
        ],
        'late': 3,
        'incident': 1,
        'review': 4,
      },
    );

    final summary = await RemittanceRepository(api: api).summary();

    expect(
      summary,
      const RemittanceSummary(
        openByStatus: [
          StatusCount(code: 'PAID', name: 'Pagada', count: 2),
          StatusCount(code: 'ASSIGNED', name: 'Asignada', count: 0),
        ],
        late: 3,
        incident: 1,
        review: 4,
      ),
    );
  });
}
