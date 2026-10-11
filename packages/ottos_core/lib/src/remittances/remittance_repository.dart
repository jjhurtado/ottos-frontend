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

  static const _keep = Object();

  /// Copies the filter; pass `null` explicitly to clear a field.
  RemittanceFilter copyWith({
    Object? status = _keep,
    Object? type = _keep,
    Object? late = _keep,
    Object? incident = _keep,
    Object? review = _keep,
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
  };
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
  });

  final RemittanceType type;
  final String customerId;
  final String beneficiaryId;
  final double amount;
  final String targetCurrency;
  final String? notes;

  /// A pickup's own rate (units of [targetCurrency] per 1 USD); null uses the
  /// configured one. Deliveries never send it.
  final double? rate;

  Map<String, dynamic> toJson() => {
    'type': type.code,
    'customerId': customerId,
    'beneficiaryId': beneficiaryId,
    'amount': amount,
    'targetCurrency': targetCurrency,
    'notes': notes,
    'rate': ?rate,
  };

  @override
  List<Object?> get props => [type, customerId, beneficiaryId, amount, targetCurrency, notes, rate];
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
}
