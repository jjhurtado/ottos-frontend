import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CashOverviewStatus { loading, success, failure }

final class CashOverviewState extends Equatable {
  const CashOverviewState({
    this.status = CashOverviewStatus.loading,
    this.balances = const [],
    this.couriers = const [],
    this.movements = const [],
    this.error,
  });

  final CashOverviewStatus status;

  /// The business cash box, per currency.
  final List<Balance> balances;
  final List<CourierCash> couriers;

  /// Latest business movements, newest first.
  final List<CashMovement> movements;
  final String? error;

  /// Currencies the business works with, USD first: the ones in the box,
  /// or USD and CUP while it is empty.
  List<String> get currencies {
    final codes = {for (final balance in balances) balance.currency};
    if (codes.isEmpty) codes.addAll(const ['USD', 'CUP']);
    return codes.toList()..sort((a, b) => a == 'USD' ? -1 : (b == 'USD' ? 1 : a.compareTo(b)));
  }

  @override
  List<Object?> get props => [status, balances, couriers, movements, error];
}

/// The business cash box, the cash each courier carries and the latest movements.
class CashOverviewCubit extends Cubit<CashOverviewState> {
  CashOverviewCubit({required this._cash}) : super(const CashOverviewState());

  final CashRepository _cash;

  /// Loads everything; after an operation it refreshes in place, keeping the page.
  Future<void> load() async {
    if (state.status != CashOverviewStatus.success) emit(const CashOverviewState());
    try {
      final results = await Future.wait<Object>([
        _cash.businessBalances(),
        _cash.couriers(),
        _cash.businessMovements(),
      ], eagerError: true);
      emit(
        CashOverviewState(
          status: CashOverviewStatus.success,
          balances: results[0] as List<Balance>,
          couriers: [...results[1] as List<CourierCash>]
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
          movements: results[2] as List<CashMovement>,
        ),
      );
    } on ApiException catch (error) {
      emit(CashOverviewState(status: CashOverviewStatus.failure, error: error.message));
    }
  }
}
