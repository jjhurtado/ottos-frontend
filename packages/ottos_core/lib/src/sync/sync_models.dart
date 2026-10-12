import 'package:equatable/equatable.dart';

import '../models/cash.dart';
import '../models/remittance.dart';
import '../models/workflow.dart';

/// What the mobile app keeps to work offline (`GET /sync/state`). The
/// remittances stay as JSON so they can be stored as they arrived.
class SyncState {
  const SyncState({
    required this.serverTime,
    required this.full,
    this.remittances = const [],
    this.removedIds = const [],
    this.cash,
    this.workflow,
  });

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
    serverTime: json['serverTime'] as String,
    full: json['full'] as bool? ?? false,
    remittances: [for (final item in json['remittances'] as List? ?? const []) item as Map<String, dynamic>],
    removedIds: [for (final id in json['removedIds'] as List? ?? const []) id as String],
    cash: json['cash'] as Map<String, dynamic>?,
    workflow: json['workflow'] as Map<String, dynamic>?,
  );

  /// The server's clock, as it came: the `since` of the next download.
  final String serverTime;

  /// The whole state: replaces the local copy instead of adding to it.
  final bool full;
  final List<Map<String, dynamic>> remittances;
  final List<String> removedIds;

  /// `CourierStatement` JSON; null for who carries no cash.
  final Map<String, dynamic>? cash;
  final Map<String, dynamic>? workflow;

  List<Remittance> get parsedRemittances => remittances.map(Remittance.fromJson).toList();

  CourierStatement? get parsedCash => cash == null ? null : CourierStatement.fromJson(cash!);

  Workflow? get parsedWorkflow => workflow == null ? null : Workflow.fromJson(workflow!);
}

enum SyncActionType {
  deliver('DELIVER'),
  deliverWithPin('DELIVER_WITH_PIN'),
  postpone('POSTPONE'),
  reportIncident('REPORT_INCIDENT'),

  /// A courier changes cash from one currency to another; no remittance.
  cashExchange('CASH_EXCHANGE');

  const SyncActionType(this.code);

  final String code;

  static SyncActionType fromCode(String code) => values.firstWhere((type) => type.code == code);

  /// Completes the remittance: it leaves the list once queued.
  bool get completes => this == deliver || this == deliverWithPin;
}

/// One action of the offline queue. [id] is generated on the phone and is the
/// idempotency key: resending it never applies it twice.
class SyncAction extends Equatable {
  const SyncAction({
    required this.id,
    required this.type,
    this.remittanceId,
    required this.occurredAt,
    this.payload = const {},
  });

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
    id: json['id'] as String,
    type: SyncActionType.fromCode(json['type'] as String),
    remittanceId: json['remittanceId'] as String?,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
    payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
  );

  final String id;
  final SyncActionType type;

  /// Null for a currency exchange.
  final String? remittanceId;

  /// When it happened on the phone; the server uses it for the history and the cash.
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'remittanceId': remittanceId,
    // UTC with Z: ISO-8601 with a zone, as the backend asks.
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  /// The same action with [payload] changed, keeping its id.
  SyncAction withPayload(Map<String, dynamic> payload) =>
      SyncAction(id: id, type: type, remittanceId: remittanceId, occurredAt: occurredAt, payload: payload);

  // The instant, not the zone: a stored action comes back in UTC.
  @override
  List<Object?> get props => [id, type, remittanceId, occurredAt.microsecondsSinceEpoch, payload];
}

enum SyncResultStatus {
  applied('APPLIED'),
  alreadyApplied('ALREADY_APPLIED'),
  rejected('REJECTED');

  const SyncResultStatus(this.code);

  final String code;

  static SyncResultStatus fromCode(String? code) =>
      values.firstWhere((status) => status.code == code, orElse: () => rejected);
}

/// What the server did with one action of a batch.
class SyncResult {
  const SyncResult({
    required this.id,
    required this.status,
    this.code,
    this.message,
    this.remittance,
    this.exchange,
    this.flaggedForReview = false,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
    id: json['id'] as String,
    status: SyncResultStatus.fromCode(json['status'] as String?),
    code: json['code'] as String?,
    message: json['message'] as String?,
    remittance: json['remittance'] as Map<String, dynamic>?,
    exchange: json['exchange'] as Map<String, dynamic>?,
    flaggedForReview: json['flaggedForReview'] as bool? ?? false,
  );

  final String id;
  final SyncResultStatus status;

  /// Same codes as the online endpoints, plus the sync ones.
  final String? code;
  final String? message;

  /// `RemittanceView` JSON after the action, to refresh the local copy.
  final Map<String, dynamic>? remittance;

  /// `ExchangeView` JSON for a currency exchange.
  final Map<String, dynamic>? exchange;
  final bool flaggedForReview;

  bool get done => status != SyncResultStatus.rejected;

  /// Worth sending again as it is (someone changed it at the same time).
  bool get retryable => code == 'CONCURRENT_UPDATE';
}

class SyncResponse {
  const SyncResponse({required this.serverTime, required this.results});

  factory SyncResponse.fromJson(Map<String, dynamic> json) => SyncResponse(
    serverTime: json['serverTime'] as String,
    results: [
      for (final item in json['results'] as List? ?? const []) SyncResult.fromJson(item as Map<String, dynamic>),
    ],
  );

  final String serverTime;
  final List<SyncResult> results;
}
