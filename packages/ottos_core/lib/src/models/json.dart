/// Small helpers to read API JSON. Every response field is optional in the
/// OpenAPI contract, so readers tolerate nulls.
DateTime? parseDateTime(Object? value) => value is String ? DateTime.tryParse(value) : null;

double? parseDecimal(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};
