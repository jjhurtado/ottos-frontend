import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../models/monthly_report.dart';
import 'report_repository.dart';

enum ReportsStatus { loading, success, failure }

final class ReportsState extends Equatable {
  const ReportsState({required this.month, this.status = ReportsStatus.loading, this.report, this.error});

  /// The first day of the month shown.
  final DateTime month;
  final ReportsStatus status;
  final MonthlyReport? report;
  final String? error;

  /// The current month is the last one with sales so far.
  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  @override
  List<Object?> get props => [month, status, report, error];
}

/// The monthly summary of sales, one month at a time; starts at the current one.
class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit({required this._reports, DateTime? now})
    : super(ReportsState(month: DateTime((now ?? DateTime.now()).year, (now ?? DateTime.now()).month)));

  final ReportRepository _reports;

  Future<void> load() async {
    final month = state.month;
    emit(ReportsState(month: month));
    try {
      final report = await _reports.monthly(month.year, month.month);
      if (state.month == month) emit(ReportsState(month: month, status: ReportsStatus.success, report: report));
    } on ApiException catch (error) {
      if (state.month == month) emit(ReportsState(month: month, status: ReportsStatus.failure, error: error.message));
    }
  }

  /// [delta] months back (negative) or forward; never past the current month.
  Future<void> moveMonth(int delta) {
    final month = DateTime(state.month.year, state.month.month + delta);
    final now = DateTime.now();
    if (month.isAfter(DateTime(now.year, now.month))) return Future.value();
    emit(ReportsState(month: month));
    return load();
  }
}
