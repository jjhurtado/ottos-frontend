import 'package:equatable/equatable.dart';

/// Staff who can be assigned remittances (`GET /couriers`).
class Courier extends Equatable {
  const Courier({required this.id, required this.name, this.email, this.openRemittances = 0});

  factory Courier.fromJson(Map<String, dynamic> json) => Courier(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    openRemittances: json['openRemittances'] as int? ?? 0,
  );

  final String id;
  final String name;
  final String? email;

  /// Assigned remittances not yet in a final status.
  final int openRemittances;

  String get displayName => name.isEmpty ? email ?? id : name;

  @override
  List<Object?> get props => [id, name, openRemittances];
}
