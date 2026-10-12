import 'package:dio/dio.dart';

import '../l10n/core_texts.dart';
import '../models/json.dart';
import '../utils/formatters.dart';

/// An error returned by the API or caused by the network, with a message that
/// can be shown to the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  /// Builds the exception from a Dio error, reading the backend's
  /// ProblemDetail (`{"status", "detail", "code"}`) when there is one.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(CoreTexts.networkError);
    }
    final status = response.statusCode;
    final data = response.data;
    final code = data is Map ? data['code'] as String? : null;
    final detail = data is Map ? data['detail'] as String? : null;
    if (code == 'AMOUNT_BELOW_MINIMUM' && data is Map) {
      final minimum = Formatters.money(parseDecimal(data['minimumAmount']), data['currency'] as String?);
      return ApiException(CoreTexts.amountBelowMinimum(minimum), statusCode: status, code: code);
    }
    if (code == 'TOO_MANY_LOGIN_ATTEMPTS') {
      // The body says how long; the Retry-After header too; 15 minutes otherwise.
      final seconds =
          (data is Map ? (data['retryAfterSeconds'] as num?)?.toInt() : null) ??
          int.tryParse(response.headers.value('retry-after') ?? '') ??
          900;
      return ApiException(CoreTexts.tooManyLoginAttempts((seconds / 60).ceil()), statusCode: status, code: code);
    }
    return ApiException(_messageFor(status, code, detail), statusCode: status, code: code);
  }

  final String message;
  final int? statusCode;

  /// The backend's stable error code, e.g. `INCORRECT_PIN`; null for network errors.
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  static String _messageFor(int? status, String? code, String? detail) {
    final translated = CoreTexts.errorCodes[code];
    if (translated != null) return translated;
    return switch (status) {
      401 => CoreTexts.sessionExpired,
      403 => CoreTexts.forbidden,
      404 => CoreTexts.notFound,
      409 => CoreTexts.conflict,
      // A code without a translation yet: the English detail beats a generic message.
      400 || 422 => detail ?? CoreTexts.invalidRequest,
      _ => CoreTexts.unexpectedError,
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
