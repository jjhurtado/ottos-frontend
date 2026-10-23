import 'package:equatable/equatable.dart';

import 'dart:math';

import '../api/api_client.dart';
import '../models/courier.dart';
import '../models/event.dart';
import '../models/page_result.dart';
import '../models/remittance.dart';
import '../models/workflow.dart';
import '../utils/formatters.dart';

/// Filters for `GET /remittances`. Null fields are not sent.
class RemittanceFilter extends Equatable {
  const RemittanceFilter({
    this.status,
    this.type,
    this.late,
    this.incident,
    this.review,
    this.courierId,
    this.customerId,
    this.beneficiaryId,
    this.municipality,
    this.from,
    this.to,
    this.voided,
    this.onTheHouse,
  });

  final String? status;
  final RemittanceType? type;
  final bool? late;

  /// true: only remittances with an open incident.
  final bool? incident;

  /// true: only remittances marked for review.
  final bool? review;
  final String? courierId;
  final String? customerId;
  final String? beneficiaryId;
  final String? municipality;
  final DateTime? from;
  final DateTime? to;

  /// true: only voided remittances; false: without them; null: all.
  final bool? voided;

  /// true: only deliveries on the house; false: without them; null: all.
  final bool? onTheHouse;

  static const _keep = Object();

  /// Copies the filter; pass `null` explicitly to clear a field.
  RemittanceFilter copyWith({
    Object? status = _keep,
    Object? type = _keep,
    Object? late = _keep,
    Object? incident = _keep,
    Object? review = _keep,
    Object? voided = _keep,
    Object? onTheHouse = _keep,
  }) => RemittanceFilter(
    status: status == _keep ? this.status : status as String?,
    type: type == _keep ? this.type : type as RemittanceType?,
    late: late == _keep ? this.late : late as bool?,
    incident: incident == _keep ? this.incident : incident as bool?,
    review: review == _keep ? this.review : review as bool?,
    courierId: courierId,
    customerId: customerId,
    beneficiaryId: beneficiaryId,
    municipality: municipality,
    from: from,
    to: to,
    voided: voided == _keep ? this.voided : voided as bool?,
    onTheHouse: onTheHouse == _keep ? this.onTheHouse : onTheHouse as bool?,
  );

  bool get isEmpty => toQuery().values.every((value) => value == null);

  @override
  List<Object?> get props => [
    status,
    type,
    late,
    incident,
    courierId,
    customerId,
    beneficiaryId,
    municipality,
    from,
    to,
    voided,
    onTheHouse,
  ];

  Map<String, dynamic> toQuery() => {
    'status': status,
    'type': type?.code,
    'late': late,
    'incident': incident,
    'review': review,
    'courierId': courierId,
    'customerId': customerId,
    'beneficiaryId': beneficiaryId,
    'municipality': municipality,
    'from': from == null ? null : Formatters.apiDate(from!),
    'to': to == null ? null : Formatters.apiDate(to!),
    'voided': voided,
    'onTheHouse': onTheHouse,
  };
}

/// An old remittance typed in by hand from its ticket (`POST /remittances/historical`):
/// registered as completed on [occurredAt], with no courier and moving no cash.
/// Amounts and the fee are in USD; in CUP the ticket's [rate] and
/// [amountToDeliver] are required and kept as they were.
class HistoricalRemittance extends Equatable {
  const HistoricalRemittance({
    required this.type,
    required this.customerId,
    required this.beneficiaryId,
    required this.occurredAt,
    required this.amount,
    required this.fee,
    this.targetCurrency = 'USD',
    this.rate,
    this.amountToDeliver,
    this.notes,
  });

  final RemittanceType type;
  final String customerId;
  final String beneficiaryId;

  /// Cuba's wall-clock time, sent without a zone.
  final DateTime occurredAt;
  final double amount;
  final double fee;
  final String targetCurrency;
  final double? rate;
  final double? amountToDeliver;
  final String? notes;

  bool get inCup => targetCurrency == 'CUP';

  Map<String, dynamic> toJson() => {
    'type': type.code,
    'customerId': customerId,
    'beneficiaryId': beneficiaryId,
    'occurredAt': Formatters.apiLocalDateTime(occurredAt),
    'targetCurrency': targetCurrency,
    'amount': amount,
    'fee': fee,
    if (inCup) 'rate': rate,
    if (inCup) 'amountToDeliver': amountToDeliver,
    'notes': notes == null || notes!.trim().isEmpty ? null : notes!.trim(),
  };

  @override
  List<Object?> get props => [
    type,
    customerId,
    beneficiaryId,
    occurredAt,
    amount,
    fee,
    targetCurrency,
    rate,
    amountToDeliver,
    notes,
  ];
}

/// Data to register a remittance (`POST /remittances`). The source currency is
/// always USD; the backend quotes the amount at today's rate.
class NewRemittance extends Equatable {
  const NewRemittance({
    required this.type,
    required this.customerId,
    required this.beneficiaryId,
    required this.amount,
    required this.targetCurrency,
    this.notes,
    this.rate,
    this.fee,
    this.onTheHouse = false,
    this.onTheHouseReason,
  });

  final RemittanceType type;
  final String customerId;
  final String beneficiaryId;
  final double amount;
  final String targetCurrency;
  final String? notes;

  /// A delivery on the house: no fee (`remittances:on-the-house`), with
  /// [onTheHouseReason] required. False sends neither field, as before.
  final bool onTheHouse;
  final String? onTheHouseReason;

  /// A pickup's own rate (units of [targetCurrency] per 1 USD); null uses the
  /// configured one. Deliveries never send it.
  final double? rate;

  /// A pickup's own fee in USD (may be 0); null uses the configured rule.
  /// Deliveries never send it.
  final double? fee;

  Map<String, dynamic> toJson() => {
    'type': type.code,
    'customerId': customerId,
    'beneficiaryId': beneficiaryId,
    'amount': amount,
    'targetCurrency': targetCurrency,
    'notes': notes,
    'rate': ?rate,
    'fee': ?fee,
    if (onTheHouse) 'onTheHouse': true,
    if (onTheHouse) 'onTheHouseReason': onTheHouseReason?.trim(),
  };

  @override
  List<Object?> get props => [
    type,
    customerId,
    beneficiaryId,
    amount,
    targetCurrency,
    notes,
    rate,
    fee,
    onTheHouse,
    onTheHouseReason,
  ];
}

class RemittanceRepository {
  RemittanceRepository({required this._api});

  final ApiClient _api;
  Future<Workflow>? _workflow;

  Future<PageResult<Remittance>> search(RemittanceFilter filter, {int page = 0, int size = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/remittances',
      query: {...filter.toQuery(), 'page': page, 'size': size},
    );
    return PageResult.fromJson(json, Remittance.fromJson);
  }

  /// Registers a remittance. Sending the same [idempotencyKey] again (a retry
  /// or a double click) returns the first remittance instead of a second one.
  Future<Remittance> register(NewRemittance remittance, {required String idempotencyKey}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/remittances',
      body: remittance.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    ),
  );

  /// A random key for [register], one per remittance being filled in.
  static String newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Staff who can be assigned remittances, by name (`remittances:assign`).
  Future<List<Courier>> couriers() async {
    final json = await _api.get<List<dynamic>>('/couriers');
    return json.map((item) => Courier.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Remittance> get(String id) async =>
      Remittance.fromJson(await _api.get<Map<String, dynamic>>('/remittances/$id'));

  Future<Remittance> getByCode(String code) async =>
      Remittance.fromJson(await _api.get<Map<String, dynamic>>('/remittances/code/${Uri.encodeComponent(code)}'));

  Future<List<RemittanceEvent>> events(String id) async {
    final json = await _api.get<List<dynamic>>('/remittances/$id/events');
    return json.map((event) => RemittanceEvent.fromJson(event as Map<String, dynamic>)).toList();
  }

  /// Statuses and transitions, loaded once per session.
  Future<Workflow> workflow() => _workflow ??= _api
      .get<Map<String, dynamic>>('/remittance-workflow')
      .then(Workflow.fromJson)
      .catchError((Object error) {
        _workflow = null;
        throw error;
      });

  /// Remittances the server recorded as completed after [since] (its own
  /// clock, the `serverTime` of the previous call). Without [since] it only
  /// says where to start.
  Future<CompletedFeed> completed({String? since}) async =>
      CompletedFeed.fromJson(await _api.get<Map<String, dynamic>>('/remittances/completed', query: {'since': since}));

  /// Open remittances assigned to the logged-in courier.
  Future<List<Remittance>> assignedToMe() async {
    final json = await _api.get<List<dynamic>>('/remittances/assigned');
    return json.map((item) => Remittance.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Remittance> deliver(String id, {String? note}) async =>
      Remittance.fromJson(await _api.post<Map<String, dynamic>>('/remittances/$id/deliver', body: {'note': note}));

  Future<Remittance> deliverWithPin(String id, {required String pin, String? note}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>('/remittances/$id/deliver-with-pin', body: {'pin': pin, 'note': note}),
  );

  Future<Remittance> assign(String id, {required String courierId, String? note}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>('/remittances/$id/assign', body: {'courierId': courierId, 'note': note}),
  );

  /// Reports why the delivery or pickup could not be done; the note is
  /// required for [IncidentReason.other] (`INCIDENT_NOTE_REQUIRED`).
  Future<Remittance> reportIncident(String id, {required IncidentReason reason, String? note}) async =>
      Remittance.fromJson(
        await _api.post<Map<String, dynamic>>(
          '/remittances/$id/incidents',
          body: {'reason': reason.code, 'note': note == null || note.trim().isEmpty ? null : note.trim()},
        ),
      );

  /// Clears the review of a remittance, leaving [note] in its history (`remittances:review`).
  Future<Remittance> resolveReview(String id, {required String note}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>('/remittances/$id/review/resolve', body: {'note': note.trim()}),
  );

  Future<Remittance> postpone(String id, {required DateTime newDate, required String reason}) async =>
      Remittance.fromJson(
        await _api.post<Map<String, dynamic>>(
          '/remittances/$id/postpone',
          body: {'newDate': Formatters.apiDate(newDate), 'reason': reason},
        ),
      );

  /// Voids a remittance for good, with [reason] (`remittances:void`): the cash it
  /// moved is reversed and it stops counting, but stays visible.
  Future<Remittance> voidRemittance(String id, {required String reason}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>('/remittances/$id/void', body: {'reason': reason.trim()}),
  );

  /// Delivers (or collects) it from the business, without a courier
  /// (`remittances:complete-from-business`): the business's cash pays it out
  /// or takes it in, and an assigned courier loses it.
  Future<Remittance> completeFromBusiness(String id, {String? note}) async => Remittance.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/remittances/$id/complete-from-business',
      body: {'note': note == null || note.trim().isEmpty ? null : note.trim()},
    ),
  );

  /// Registers an old remittance from its ticket (`remittances:historical`).
  Future<Remittance> registerHistorical(HistoricalRemittance remittance) async =>
      Remittance.fromJson(await _api.post<Map<String, dynamic>>('/remittances/historical', body: remittance.toJson()));
}
