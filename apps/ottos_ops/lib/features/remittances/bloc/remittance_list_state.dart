part of 'remittance_list_bloc.dart';

enum RemittanceListStatus { loading, success, failure }

final class RemittanceListState extends Equatable {
  const RemittanceListState({
    required this.filter,
    this.status = RemittanceListStatus.loading,
    this.statuses = const [],
    this.result,
    this.error,
  });

  final RemittanceListStatus status;
  final RemittanceFilter filter;

  /// Workflow statuses, for the status filter.
  final List<RemittanceStatus> statuses;
  final PageResult<Remittance>? result;
  final String? error;

  RemittanceListState copyWith({
    RemittanceListStatus? status,
    RemittanceFilter? filter,
    List<RemittanceStatus>? statuses,
    PageResult<Remittance>? result,
    String? error,
  }) => RemittanceListState(
    status: status ?? this.status,
    filter: filter ?? this.filter,
    statuses: statuses ?? this.statuses,
    result: result ?? this.result,
    error: error,
  );

  @override
  List<Object?> get props => [status, filter, statuses, result, error];
}
