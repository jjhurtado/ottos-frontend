import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

ApiException _from(int status, Map<String, dynamic>? body) {
  final request = RequestOptions(path: '/x');
  return ApiException.fromDio(
    DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: status, data: body),
    ),
  );
}

void main() {
  test('translates a known code', () {
    final error = _from(400, {'status': 400, 'code': 'INCORRECT_PIN', 'detail': 'Incorrect PIN'});

    expect(error.message, 'El PIN no es correcto.');
    expect(error.code, 'INCORRECT_PIN');
    expect(error.statusCode, 400);
  });

  test('falls back to the English detail for an untranslated 400 code', () {
    expect(_from(400, {'code': 'SOMETHING_NEW', 'detail': 'Something new'}).message, 'Something new');
  });

  test('falls back to a message by status', () {
    expect(_from(401, {'code': 'INVALID_TOKEN'}).message, CoreTexts.sessionExpired);
    expect(_from(403, {'code': 'FORBIDDEN'}).message, CoreTexts.forbidden);
    expect(_from(409, {'code': 'SOMETHING_NEW', 'detail': 'x'}).message, CoreTexts.conflict);
    expect(_from(500, null).message, CoreTexts.unexpectedError);
  });

  test('reports a network error without a response', () {
    final error = ApiException.fromDio(DioException(requestOptions: RequestOptions(path: '/x')));

    expect(error.message, CoreTexts.networkError);
    expect(error.code, isNull);
  });
}
