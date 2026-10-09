import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum CashStatus { loading, success, failure }

final class CashState extends Equatable {
  const CashState({this.status = CashStatus.loading, this.statement, this.error});

  final CashStatus status;
  final CourierStatement? statement;
  final String? error;

  @override
  List<Object?> get props => [status, statement, error];
}

class CashCubit extends Cubit<CashState> {
  CashCubit({required this._cash}) : super(const CashState());

  final CashRepository _cash;

  Future<void> load() async {
    try {
      emit(CashState(status: CashStatus.success, statement: await _cash.myStatement()));
    } on ApiException catch (error) {
      emit(CashState(status: CashStatus.failure, statement: state.statement, error: error.message));
    }
  }
}
