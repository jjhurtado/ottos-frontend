part of 'remittance_list_bloc.dart';

enum RemittanceListStatus { loading, success, failure }

final class RemittanceListState extends Equatable {
  const RemittanceListState({
    required this.filter,
    this.status = RemittanceListStatus.loading,
    this.statuses = const [],
    this.result,
    this.typed = '',
    this.error,
  });

  final RemittanceListStatus status;
  final RemittanceFilter filter;

  /// Workflow statuses, for the status filter.
  final List<RemittanceStatus> statuses;
  final PageResult<Remittance>? result;

  /// What the beneficiary field holds now (it may not be sent yet).
  final String typed;
  final String? error;

  /// The typed text is too short to be sent, so a hint is shown.
  bool get searchTooShort => typed.trim().isNotEmpty && !isSearchable(typed);

  RemittanceListState copyWith({
    RemittanceListStatus? status,
    RemittanceFilter? filter,
    List<RemittanceStatus>? statuses,
    PageResult<Remittance>? result,
    String? typed,
    String? error,
  }) => RemittanceListState(
    status: status ?? this.status,
    filter: filter ?? this.filter,
    statuses: statuses ?? this.statuses,
    result: result ?? this.result,
    typed: typed ?? this.typed,
    error: error,
  );

  @override
  List<Object?> get props => [status, filter, statuses, result, typed, error];
}

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');

/// A search is sent from 2 letters (a name) or 4 digits (the end of a phone).
bool isSearchable(String text) {
  final trimmed = text.trim();
  return _letter.allMatches(trimmed).length >= 2 || _digit.allMatches(trimmed).length >= 4;
}
