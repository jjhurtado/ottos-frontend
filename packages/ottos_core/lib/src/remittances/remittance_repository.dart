import 'package:equatable/equatable.dart';

import '../api/api_client.dart';
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
  final String? courierId;
  final String? customerId;
  final String? beneficiaryId;
  final String? municipality;
  final DateTime? from;
  final DateTime? to;

  static const _keep = Object();

  /// Copies the filter; pass `null` explicitly to clear a field.
  RemittanceFilter copyWith({Object? status = _keep, Object? type = _keep, Object? late = _keep}) => RemittanceFilter(
    status: status == _keep ? this.status : status as String?,
    type: type == _keep ? this.type : type as RemittanceType?,
    late: late == _keep ? this.late : late as bool?,
    courierId: courierId,
    customerId: customerId,
    beneficiaryId: beneficiaryId,
    municipality: municipality,
    from: from,
    to: to,
  );

  bool get isEmpty => toQuery().values.every((value) => value == null);

  @override
  List<Object?> get props => [status, type, late, courierId, customerId, beneficiaryId, municipality, from, to];

  Map<String, dynamic> toQuery() => {
    'status': status,
    'type': type?.code,
    'late': late,
    'courierId': courierId,
    'customerId': customerId,
    'beneficiaryId': beneficiaryId,
    'municipality': municipality,
    'from': from == null ? null : Formatters.apiDate(from!),
    'to': to == null ? null : Formatters.apiDate(to!),
  };
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

  Future<Remittance> postpone(String id, {required DateTime newDate, required String reason}) async =>
      Remittance.fromJson(
        await _api.post<Map<String, dynamic>>(
          '/remittances/$id/postpone',
          body: {'newDate': Formatters.apiDate(newDate), 'reason': reason},
        ),
      );
}
