import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum RatesStatus { loading, success, failure }

final class RatesState extends Equatable {
  const RatesState({this.status = RatesStatus.loading, this.corridors = const [], this.error});

  final RatesStatus status;
  final List<Corridor> corridors;
  final String? error;

  @override
  List<Object?> get props => [status, corridors, error];
}

/// Corridors with the rate and fee rule in force.
class RatesCubit extends Cubit<RatesState> {
  RatesCubit({required this._rates}) : super(const RatesState());

  final RateRepository _rates;

  /// Loads the corridors; after a change it refreshes in place, keeping the page.
  Future<void> load() async {
    if (state.status != RatesStatus.success) emit(const RatesState());
    try {
      final corridors = await _rates.corridors();
      // Active first, then by code.
      corridors.sort((a, b) => a.active == b.active ? a.code.compareTo(b.code) : (a.active ? -1 : 1));
      emit(RatesState(status: RatesStatus.success, corridors: corridors));
    } on ApiException catch (error) {
      emit(RatesState(status: RatesStatus.failure, error: error.message));
    }
  }
}
