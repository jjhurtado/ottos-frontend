import 'package:dio/dio.dart';

import '../l10n/core_texts.dart';

/// An error returned by the API or caused by the network, with a message that
/// can be shown to the user.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// Builds the exception from a Dio error, reading the backend's
  /// ProblemDetail (`{"title", "status", "detail"}`) when there is one.
  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(CoreTexts.networkError);
    }
    final status = response.statusCode;
    final data = response.data;
    final detail = data is Map ? data['detail'] as String? : null;
    return ApiException(_messageFor(status, detail), statusCode: status);
  }

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  static String _messageFor(int? status, String? detail) {
    return switch (status) {
      401 when detail == 'Invalid credentials' => CoreTexts.invalidCredentials,
      401 => CoreTexts.sessionExpired,
      403 => CoreTexts.forbidden,
      404 => CoreTexts.notFound,
      // Validation and business rule messages come from the backend in English;
      // keep them as detail until the backend returns error codes to translate.
      400 || 409 || 422 => detail ?? CoreTexts.invalidRequest,
      _ => CoreTexts.unexpectedError,
    };
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
