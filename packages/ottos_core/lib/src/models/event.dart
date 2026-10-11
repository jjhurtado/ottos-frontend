import 'package:equatable/equatable.dart';

import 'json.dart';
import 'remittance.dart';

/// One entry of a remittance's history (`EventView`).
class RemittanceEvent extends Equatable {
  const RemittanceEvent({
    required this.id,
    required this.type,
    this.fromStatus,
    this.toStatus,
    this.courierId,
    this.previousDate,
    this.newDate,
    this.incidentReason,
    this.reviewReason,
    this.note,
    this.actorId,
    this.occurredAt,
  });

  factory RemittanceEvent.fromJson(Map<String, dynamic> json) => RemittanceEvent(
    id: json['id'] as String,
    type: json['type'] as String? ?? '',
    fromStatus: json['fromStatus'] as String?,
    toStatus: json['toStatus'] as String?,
    courierId: json['courierId'] as String?,
    previousDate: parseDateTime(json['previousDate']),
    newDate: parseDateTime(json['newDate']),
    incidentReason: json['incidentReason'] == null ? null : IncidentReason.fromCode(json['incidentReason'] as String?),
    reviewReason: json['reviewReason'] == null ? null : ReviewReason.fromCode(json['reviewReason'] as String?),
    note: json['note'] as String?,
    actorId: json['actorId'] as String?,
    occurredAt: parseDateTime(json['occurredAt']),
  );

  final String id;
  final String type;
  final String? fromStatus;
  final String? toStatus;
  final String? courierId;
  final DateTime? previousDate;
  final DateTime? newDate;

  /// Only on `INCIDENT_REPORTED` events.
  final IncidentReason? incidentReason;

  /// Why it was marked, in REVIEW_FLAGGED events.
  final ReviewReason? reviewReason;
  final String? note;
  final String? actorId;
  final DateTime? occurredAt;

  @override
  List<Object?> get props => [id];
}
