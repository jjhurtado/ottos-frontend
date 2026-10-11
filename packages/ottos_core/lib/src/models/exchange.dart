import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// The currencies the cash handles; one side of an exchange is always USD.
const exchangeCurrencies = ['USD', 'CUP'];

/// A courier changing cash from one currency to another (`ExchangeView`).
/// [rate] is always units of the other currency per 1 USD, in both directions.
class CurrencyExchange extends Equatable {
  const CurrencyExchange({
    required this.id,
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.toAmount,
    required this.rate,
    this.courierId,
    this.courierName,
    this.configuredRate,
    this.deviationPercent,
    this.note,
    this.occurredAt,
    this.review,
  });

  factory CurrencyExchange.fromJson(Map<String, dynamic> json) => CurrencyExchange(
    id: json['id'] as String? ?? '',
    courierId: json['courierId'] as String?,
    courierName: json['courierName'] as String?,
    fromCurrency: json['fromCurrency'] as String? ?? '',
    fromAmount: parseDecimal(json['fromAmount']) ?? 0,
    toCurrency: json['toCurrency'] as String? ?? '',
    toAmount: parseDecimal(json['toAmount']) ?? 0,
    rate: parseDecimal(json['rate']) ?? 0,
    configuredRate: parseDecimal(json['configuredRate']),
    deviationPercent: parseDecimal(json['deviationPercent']),
    note: json['note'] as String?,
    occurredAt: parseDateTime(json['occurredAt']),
    review: json['review'] == null ? null : ExchangeReview.fromJson(json['review'] as Map<String, dynamic>),
  );

  final String id;
  final String? courierId;
  final String? courierName;
  final String fromCurrency;
  final double fromAmount;
  final String toCurrency;
  final double toAmount;
  final double rate;

  /// The delivery rate it was compared with, and how far it was; null without one.
  final double? configuredRate;
  final double? deviationPercent;
  final String? note;
  final DateTime? occurredAt;
  final ExchangeReview? review;

  /// Waiting for sales to check it.
  bool get pendingReview => review != null && review!.resolvedAt == null;

  @override
  List<Object?> get props => [id, review?.resolvedAt];
}

/// Why an exchange was marked and, once resolved, how. It stays as history.
class ExchangeReview extends Equatable {
  const ExchangeReview({required this.reason, this.flaggedAt, this.resolvedAt, this.resolvedBy, this.resolvedNote});

  factory ExchangeReview.fromJson(Map<String, dynamic> json) => ExchangeReview(
    reason: ReviewReason.fromCode(json['reason'] as String?),
    flaggedAt: parseDateTime(json['flaggedAt']),
    resolvedAt: parseDateTime(json['resolvedAt']),
    resolvedBy: json['resolvedBy'] as String?,
    resolvedNote: json['resolvedNote'] as String?,
  );

  final ReviewReason reason;
  final DateTime? flaggedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolvedNote;

  @override
  List<Object?> get props => [reason, flaggedAt, resolvedAt, resolvedNote];
}

/// A new exchange (`POST /cash/.../exchanges`).
class ExchangeInput extends Equatable {
  const ExchangeInput({
    required this.fromCurrency,
    required this.fromAmount,
    required this.toCurrency,
    required this.rate,
    this.note,
  });

  final String fromCurrency;
  final double fromAmount;
  final String toCurrency;

  /// Units of the other currency per 1 USD.
  final double rate;
  final String? note;

  /// What the server will compute: USD→other multiplies, other→USD divides;
  /// 2 decimals, half up.
  double get toAmount {
    final raw = fromCurrency == 'USD' ? fromAmount * rate : fromAmount / rate;
    return (raw * 100 + 1e-9).roundToDouble() / 100;
  }

  Map<String, dynamic> toJson() => {
    'fromCurrency': fromCurrency,
    'fromAmount': fromAmount,
    'toCurrency': toCurrency,
    'rate': rate,
    'note': note == null || note!.trim().isEmpty ? null : note!.trim(),
  };

  @override
  List<Object?> get props => [fromCurrency, fromAmount, toCurrency, rate, note];
}
