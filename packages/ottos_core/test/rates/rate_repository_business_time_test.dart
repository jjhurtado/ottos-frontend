import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';

class _MockApi extends Mock implements ApiClient {}

void main() {
  late _MockApi api;
  late RateRepository rates;

  setUp(() {
    api = _MockApi();
    rates = RateRepository(api: api);
  });
  tearDown(BusinessTime.reset);

  test('AC-2.3: saving a new zone applies it at once', () async {
    when(() => api.put<Map<String, dynamic>>('/configuration/settings', body: any(named: 'body'))).thenAnswer(
      (_) async => {
        'businessTime': {'timeZone': 'UTC-05:00', 'offsetMinutes': -300},
      },
    );

    await rates.updateSettings(businessTimeZone: 'UTC-05:00');

    expect(BusinessTime.zone.offsetMinutes, -300);
    verify(() => api.put<Map<String, dynamic>>('/configuration/settings', body: {'businessTimeZone': 'UTC-05:00'}))
        .called(1);
  });

  test('AC-2.5: an older server without the operation keeps UTC−4', () async {
    when(() => api.get<Map<String, dynamic>>('/configuration/business-time')).thenAnswer((_) async => {});

    expect(await rates.businessTime(), isNull);
    expect(BusinessTime.zone, BusinessTimeZone.fallback);
  });
}
