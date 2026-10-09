import 'package:equatable/equatable.dart';

/// A remittance status, configured in the database (`StatusView`).
class RemittanceStatus extends Equatable {
  const RemittanceStatus({
    required this.code,
    required this.name,
    required this.position,
    required this.isInitial,
    required this.requiresCourier,
    required this.isFinal,
  });

  factory RemittanceStatus.fromJson(Map<String, dynamic> json) => RemittanceStatus(
    code: json['code'] as String,
    name: json['name'] as String? ?? json['code'] as String,
    position: json['position'] as int? ?? 0,
    isInitial: json['initial'] as bool? ?? false,
    requiresCourier: json['requiresCourier'] as bool? ?? false,
    isFinal: json['isFinal'] as bool? ?? false,
  );

  final String code;
  final String name;
  final int position;
  final bool isInitial;
  final bool requiresCourier;
  final bool isFinal;

  @override
  List<Object?> get props => [code];
}

class RemittanceTransition extends Equatable {
  const RemittanceTransition({required this.from, required this.to, required this.permission});

  factory RemittanceTransition.fromJson(Map<String, dynamic> json) => RemittanceTransition(
    from: json['from'] as String,
    to: json['to'] as String,
    permission: json['permission'] as String? ?? '',
  );

  final String from;
  final String to;
  final String permission;

  @override
  List<Object?> get props => [from, to];
}

/// Statuses (sorted by position) and allowed transitions.
class Workflow {
  const Workflow({required this.statuses, required this.transitions});

  factory Workflow.fromJson(Map<String, dynamic> json) => Workflow(
    statuses:
        (json['statuses'] as List? ?? const [])
            .map((status) => RemittanceStatus.fromJson(status as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
    transitions: (json['transitions'] as List? ?? const [])
        .map((transition) => RemittanceTransition.fromJson(transition as Map<String, dynamic>))
        .toList(),
  );

  final List<RemittanceStatus> statuses;
  final List<RemittanceTransition> transitions;

  String nameOf(String code) => statuses.firstWhere((status) => status.code == code, orElse: () => _unknown(code)).name;

  static RemittanceStatus _unknown(String code) =>
      RemittanceStatus(code: code, name: code, position: 0, isInitial: false, requiresCourier: false, isFinal: false);
}
