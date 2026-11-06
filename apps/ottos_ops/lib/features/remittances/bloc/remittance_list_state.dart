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
    this.canRetry = true,
  });

  final RemittanceListStatus status;
  final RemittanceFilter filter;

  /// Workflow statuses, for the status filter.
  final List<RemittanceStatus> statuses;
  final PageResult<Remittance>? result;

  /// What the beneficiary field holds now (it may not be sent yet).
  final String typed;

  /// Why the load failed; set only while [status] is failure.
  final String? error;

  /// A retry can work (a network or server failure); false for a 400, because
  /// the same text would be refused again.
  final bool canRetry;

  /// The typed text is too short to be sent, so a hint is shown.
  bool get searchTooShort => typed.trim().isNotEmpty && !isSearchable(typed);

  RemittanceListState copyWith({
    RemittanceListStatus? status,
    RemittanceFilter? filter,
    List<RemittanceStatus>? statuses,
    PageResult<Remittance>? result,
    String? typed,
    String? error,
    bool? canRetry,
  }) {
    final next = status ?? this.status;
    // Error and status go together: the error is kept while the status stays
    // failure (typing does not hide it) and dropped with any other status.
    final failed = next == RemittanceListStatus.failure;
    return RemittanceListState(
      status: next,
      filter: filter ?? this.filter,
      statuses: statuses ?? this.statuses,
      result: result ?? this.result,
      typed: typed ?? this.typed,
      error: failed ? (error ?? this.error) : null,
      canRetry: failed ? (canRetry ?? this.canRetry) : true,
    );
  }

  @override
  List<Object?> get props => [status, filter, statuses, result, typed, error, canRetry];
}

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');

/// A search is sent from 2 letters (a name) or 4 digits (the end of a phone).
bool isSearchable(String text) {
  final trimmed = text.trim();
  return _letter.allMatches(trimmed).length >= 2 || _digit.allMatches(trimmed).length >= 4;
}
