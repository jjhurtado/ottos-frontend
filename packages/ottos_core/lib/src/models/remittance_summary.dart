import 'package:equatable/equatable.dart';

/// Open remittances, not voided, in one status (`StatusCount`).
class StatusCount extends Equatable {
  const StatusCount({required this.code, required this.name, required this.count});

  factory StatusCount.fromJson(Map<String, dynamic> json) => StatusCount(
    code: json['code'] as String,
    name: json['name'] as String? ?? json['code'] as String,
    count: json['count'] as int? ?? 0,
  );

  final String code;
  final String name;
  final int count;

  @override
  List<Object?> get props => [code, name, count];
}

/// The panel Home counters in one read (`GET /remittances/summary`, REQ-022
/// OPT-F4). Each one equals the `totalItems` of the list its tile opens.
class RemittanceSummary extends Equatable {
  const RemittanceSummary({this.openByStatus = const [], this.late = 0, this.incident = 0, this.review = 0});

  factory RemittanceSummary.fromJson(Map<String, dynamic> json) => RemittanceSummary(
    openByStatus: [
      for (final item in json['openByStatus'] as List? ?? const []) StatusCount.fromJson(item as Map<String, dynamic>),
    ],
    late: json['late'] as int? ?? 0,
    incident: json['incident'] as int? ?? 0,
    review: json['review'] as int? ?? 0,
  );

  /// Every status the workflow does not mark final, in workflow order, also with 0.
  final List<StatusCount> openByStatus;
  final int late;
  final int incident;
  final int review;

  @override
  List<Object?> get props => [openByStatus, late, incident, review];
}
