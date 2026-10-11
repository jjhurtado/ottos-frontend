import 'package:equatable/equatable.dart';

import '../api/api_client.dart';
import '../models/audit.dart';
import '../models/page_result.dart';
import '../utils/formatters.dart';

/// Filters of the audit log; null fields do not filter.
class AuditFilter extends Equatable {
  const AuditFilter({this.targetType, this.action, this.actorId, this.from, this.to});

  final String? targetType;
  final String? action;
  final String? actorId;

  /// Days, both included (Cuba time on the server).
  final DateTime? from;
  final DateTime? to;

  static const _keep = Object();

  /// Copies the filter; pass `null` explicitly to clear a field.
  AuditFilter copyWith({
    Object? targetType = _keep,
    Object? action = _keep,
    Object? from = _keep,
    Object? to = _keep,
  }) => AuditFilter(
    targetType: targetType == _keep ? this.targetType : targetType as String?,
    action: action == _keep ? this.action : action as String?,
    actorId: actorId,
    from: from == _keep ? this.from : from as DateTime?,
    to: to == _keep ? this.to : to as DateTime?,
  );

  bool get isEmpty => targetType == null && action == null && actorId == null && from == null && to == null;

  Map<String, dynamic> toQuery() => {
    'targetType': targetType,
    'action': action,
    'actorId': actorId,
    'from': from == null ? null : Formatters.apiDate(from!),
    'to': to == null ? null : Formatters.apiDate(to!),
  };

  @override
  List<Object?> get props => [targetType, action, actorId, from, to];
}

/// Who changed users and roles, and when (`GET /audit`, `audit:read`).
class AuditRepository {
  AuditRepository({required this._api});

  final ApiClient _api;

  /// Newest first.
  Future<PageResult<AuditEntry>> search(AuditFilter filter, {int page = 0, int size = 50}) async => PageResult.fromJson(
    await _api.get<Map<String, dynamic>>('/audit', query: {...filter.toQuery(), 'page': page, 'size': size}),
    AuditEntry.fromJson,
  );
}
