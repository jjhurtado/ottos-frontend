import 'package:dio/dio.dart';

import '../l10n/core_texts.dart';

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
