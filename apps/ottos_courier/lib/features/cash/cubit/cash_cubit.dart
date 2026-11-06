import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CashStatus { loading, success, failure }

final class CashState extends Equatable {
  const CashState({this.status = CashStatus.loading, this.statement, this.couriers, this.pending, this.error});

  final CashStatus status;

  /// The user's own cash; null for who carries none (sales).
  final CourierStatement? statement;

  /// The cash each courier carries; null for who cannot see it.
  final List<CourierCash>? couriers;

  /// What the courier still has to deliver and to collect of their own
  /// remittances (REQ-021 US-3); null for who has none assigned (sales).
  final PendingTotals? pending;
  final String? error;

  bool get loaded => statement != null || couriers != null;

  @override
  List<Object?> get props => [status, statement, couriers, pending, error];
}

/// The user's own cash and, for who manages it, the couriers' cash.
class CashCubit extends Cubit<CashState> {
  CashCubit({
    required this._cash,
    required this.ownCash,
    required this.couriersCash,
    this._ownStatement,
    this._assigned,
  }) : super(const CashState());

  final CashRepository _cash;

  /// Where the own cash comes from: the phone for couriers, who work offline.
  final Future<CourierStatement?> Function()? _ownStatement;
  final bool ownCash;
  final bool couriersCash;

  /// The courier's open remittances as the phone has them, with the actions
  /// not sent yet applied, to sum what is pending (BR-7); null shows nothing.
  final Future<List<Remittance>> Function()? _assigned;

  Future<void> load() async {
    try {
      final statement = !ownCash ? null : await (_ownStatement ?? _cash.myStatement)();
      final couriers = couriersCash
          ? ([...await _cash.couriers()]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
          : null;
      final assigned = _assigned;
      final pending = assigned == null ? null : PendingTotals.sum(await assigned());
      emit(CashState(status: CashStatus.success, statement: statement, couriers: couriers, pending: pending));
    } on ApiException catch (error) {
      emit(
        CashState(
          status: CashStatus.failure,
          statement: state.statement,
          couriers: state.couriers,
          pending: state.pending,
          error: error.message,
        ),
      );
    }
  }

  Future<CashMovement> fund(CourierCash courier, CashInput input) => _cash.fundCourier(courier.courierId, input);

  Future<CashMovement> registerReturn(CourierCash courier, CashInput input) =>
      _cash.courierReturn(courier.courierId, input);
}
