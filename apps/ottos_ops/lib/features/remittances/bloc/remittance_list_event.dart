part of 'remittance_list_bloc.dart';

sealed class RemittanceListEvent extends Equatable {
  const RemittanceListEvent();

  @override
  List<Object?> get props => [];
}

/// Events that load a page; a newer one cancels the one in flight.
sealed class RemittanceListLoadEvent extends RemittanceListEvent {
  const RemittanceListLoadEvent();
}

final class RemittanceListStarted extends RemittanceListLoadEvent {
  const RemittanceListStarted();
}

final class RemittanceListFilterChanged extends RemittanceListLoadEvent {
  const RemittanceListFilterChanged(this.filter);

  final RemittanceFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class RemittanceListPageRequested extends RemittanceListLoadEvent {
  const RemittanceListPageRequested(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

/// The user typed in the beneficiary field; it is applied after a pause.
final class RemittanceListSearchTyped extends RemittanceListEvent {
  const RemittanceListSearchTyped(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// The pause after typing ended: the typed text becomes (or stops being) a filter.
final class RemittanceListSearchApplied extends RemittanceListLoadEvent {
  const RemittanceListSearchApplied();
}

/// «Quitar filtros»: every filter and the typed text go, and a pending search is dropped.
final class RemittanceListFiltersCleared extends RemittanceListLoadEvent {
  const RemittanceListFiltersCleared();
}
