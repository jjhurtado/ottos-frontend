part of 'remittance_list_bloc.dart';

sealed class RemittanceListEvent extends Equatable {
  const RemittanceListEvent();

  @override
  List<Object?> get props => [];
}

final class RemittanceListStarted extends RemittanceListEvent {
  const RemittanceListStarted();
}

final class RemittanceListFilterChanged extends RemittanceListEvent {
  const RemittanceListFilterChanged(this.filter);

  final RemittanceFilter filter;

  @override
  List<Object?> get props => [filter];
}

final class RemittanceListPageRequested extends RemittanceListEvent {
  const RemittanceListPageRequested(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}
