import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CashStatus { loading, success, failure }

final class CashState extends Equatable {
  const CashState({this.status = CashStatus.loading, this.statement, this.couriers, this.error});

  final CashStatus status;

  /// The user's own cash; null for who carries none (sales).
  final CourierStatement? statement;

  /// The cash each courier carries; null for who cannot see it.
  final List<CourierCash>? couriers;
  final String? error;

  bool get loaded => statement != null || couriers != null;

  @override
  List<Object?> get props => [status, statement, couriers, error];
}

/// The user's own cash and, for who manages it, the couriers' cash.
class CashCubit extends Cubit<CashState> {
  CashCubit({required this._cash, required this.ownCash, required this.couriersCash, this._ownStatement})
    : super(const CashState());

  final CashRepository _cash;

  /// Where the own cash comes from: the phone for couriers, who work offline.
  final Future<CourierStatement?> Function()? _ownStatement;
  final bool ownCash;
  final bool couriersCash;

  Future<void> load() async {
    try {
      final statement = !ownCash ? null : await (_ownStatement ?? _cash.myStatement)();
      final couriers = couriersCash
          ? ([...await _cash.couriers()]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
          : null;
      emit(CashState(status: CashStatus.success, statement: statement, couriers: couriers));
    } on ApiException catch (error) {
      emit(
        CashState(
          status: CashStatus.failure,
          statement: state.statement,
          couriers: state.couriers,
          error: error.message,
        ),
      );
    }
  }

  Future<CashMovement> fund(CourierCash courier, CashInput input) => _cash.fundCourier(courier.courierId, input);

  Future<CashMovement> registerReturn(CourierCash courier, CashInput input) =>
      _cash.courierReturn(courier.courierId, input);
}
