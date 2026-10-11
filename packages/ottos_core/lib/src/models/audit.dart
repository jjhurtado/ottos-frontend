import 'package:equatable/equatable.dart';

import 'json.dart';

/// One change recorded in the audit log (`AuditEntryView`): who did what to
/// which user or role, and when. [details] depends on [action].
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.targetType,
    this.occurredAt,
    this.actorId,
    this.actorName,
    this.targetId,
    this.targetLabel,
    this.details = const {},
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String? ?? '',
    action: json['action'] as String? ?? '',
    targetType: json['targetType'] as String? ?? '',
    occurredAt: parseDateTime(json['occurredAt']),
    actorId: json['actorId'] as String?,
    actorName: json['actorName'] as String?,
    targetId: json['targetId'] as String?,
    targetLabel: json['targetLabel'] as String?,
    details: (json['details'] as Map<String, dynamic>?) ?? const {},
  );

  final String id;

  /// A stable code, e.g. `USER_ROLES_CHANGED`; translated by the app.
  final String action;

  /// `USER` or `ROLE` today.
  final String targetType;
  final DateTime? occurredAt;

  /// Null when the system did it (the first admin, created on startup).
  final String? actorId;
  final String? actorName;
  final String? targetId;

  /// The target as it read then: an email, a role code…
  final String? targetLabel;
  final Map<String, dynamic> details;

  @override
  List<Object?> get props => [id];
}
