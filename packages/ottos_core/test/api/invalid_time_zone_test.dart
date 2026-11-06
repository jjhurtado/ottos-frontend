import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('AC-1.4: a 400 INVALID_TIME_ZONE shows the approved message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/settings'),
      response: Response(
        requestOptions: RequestOptions(path: '/settings'),
        statusCode: 400,
        data: {'status': 400, 'code': 'INVALID_TIME_ZONE', 'detail': 'Invalid time zone'},
      ),
    );

    final exception = ApiException.fromDio(error);

    expect(exception.message, 'La zona horaria no es válida. Usa un desfase fijo entre UTC−12 y UTC+14.');
    expect(exception.code, 'INVALID_TIME_ZONE');
  });

  test('AC-1.4 (range): the dropdown offers UTC−12 to UTC+14 in whole hours and nothing else', () {
    final minutes = BusinessTimeZone.wholeHours.map((z) => z.offsetMinutes).toList();

    expect(minutes.first, -12 * 60);
    expect(minutes.last, 14 * 60);
    expect(minutes.length, 27);
  });
}
