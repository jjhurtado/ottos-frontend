import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

/// Number of open remittances in one status.
class StatusCount extends Equatable {
  const StatusCount(this.status, this.count);

  final RemittanceStatus status;
  final int count;

  @override
  List<Object?> get props => [status, count];
}

enum HomeStatus { loading, success, failure }

final class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.loading,
    this.openByStatus = const [],
    this.late = 0,
    this.incidents = 0,
    this.error,
  });

  final HomeStatus status;
  final List<StatusCount> openByStatus;
  final int late;
  final int incidents;
  final String? error;

  @override
  List<Object?> get props => [status, openByStatus, late, incidents, error];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this._remittances}) : super(const HomeState());

  final RemittanceRepository _remittances;

  Future<void> load() async {
    emit(const HomeState());
    try {
      final workflow = await _remittances.workflow();
      final open = workflow.statuses.where((status) => !status.isFinal).toList();
      final counts = await Future.wait([
        for (final status in open) _count(RemittanceFilter(status: status.code)),
        _count(const RemittanceFilter(late: true)),
        _count(const RemittanceFilter(incident: true)),
      ]);
      emit(
        HomeState(
          status: HomeStatus.success,
          openByStatus: [for (var i = 0; i < open.length; i++) StatusCount(open[i], counts[i])],
          late: counts[open.length],
          incidents: counts[open.length + 1],
        ),
      );
    } on ApiException catch (error) {
      emit(HomeState(status: HomeStatus.failure, error: error.message));
    }
  }

  Future<int> _count(RemittanceFilter filter) async => (await _remittances.search(filter, size: 1)).totalItems;
}
