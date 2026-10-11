import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum AuditStatus { loading, success, failure }

final class AuditState extends Equatable {
  const AuditState({this.status = AuditStatus.loading, this.filter = const AuditFilter(), this.result, this.error});

  final AuditStatus status;
  final AuditFilter filter;

  /// The page shown; kept while the next one loads.
  final PageResult<AuditEntry>? result;
  final String? error;

  @override
  List<Object?> get props => [status, filter, result?.page, result?.items, error];
}

/// The audit log, newest first, filtered and a page at a time.
class AuditCubit extends Cubit<AuditState> {
  AuditCubit({required this._audit}) : super(const AuditState());

  final AuditRepository _audit;

  static const pageSize = 50;

  Future<void> load({int page = 0}) async {
    emit(AuditState(filter: state.filter, result: state.result));
    try {
      final result = await _audit.search(state.filter, page: page, size: pageSize);
      emit(AuditState(status: AuditStatus.success, filter: state.filter, result: result));
    } on ApiException catch (error) {
      emit(AuditState(status: AuditStatus.failure, filter: state.filter, result: state.result, error: error.message));
    }
  }

  /// A new filter starts again at the first page.
  Future<void> filter(AuditFilter filter) {
    emit(AuditState(filter: filter, result: state.result));
    return load();
  }
}
