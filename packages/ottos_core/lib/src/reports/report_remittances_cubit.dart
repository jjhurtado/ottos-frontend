import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../models/report_detail.dart';
import 'report_repository.dart';
import 'report_totals.dart';

/// [unavailable]: the backend does not have the detail yet (404).
enum ReportDetailStatus { loading, success, failure, unavailable }

final class ReportRemittancesState extends Equatable {
  const ReportRemittancesState({
    required this.month,
    this.status = ReportDetailStatus.loading,
    this.detail,
    this.error,
    this.filter = const ReportFilter(),
    this.page = 0,
  });

  /// The first day of the month shown.
  final DateTime month;
  final ReportDetailStatus status;
  final MonthlyReportDetail? detail;
  final String? error;
  final ReportFilter filter;

  /// From 0, [pageSize] rows each.
  final int page;

  static const pageSize = 50;

  /// The rows that pass the filter, in its order.
  List<ReportRemittance> get filtered => detail == null ? const [] : filter.apply(detail!.remittances);

  /// The sums of [filtered], voided ones aside.
  ReportTotals get totals => ReportTotals.of(filtered);

  List<ReportRemittance> get pageRows => filtered.skip(page * pageSize).take(pageSize).toList();

  int get pages => (filtered.length / pageSize).ceil();

  /// The couriers in the month, by name; [ReportFilter.withoutCourier] first
  /// if some remittance has none.
  List<String> get couriers {
    final rows = detail?.remittances ?? const <ReportRemittance>[];
    final names = {for (final row in rows) ?row.courierName}.toList()..sort();
    return [if (rows.any((row) => row.courierName == null)) ReportFilter.withoutCourier, ...names];
  }

  ReportRemittancesState copyWith({ReportFilter? filter, int? page}) => ReportRemittancesState(
    month: month,
    status: status,
    detail: detail,
    error: error,
    filter: filter ?? this.filter,
    page: page ?? this.page,
  );

  @override
  List<Object?> get props => [month, status, detail, error, filter, page];
}

/// Every remittance of a month, filtered and paged in the app; the filters
/// stay when the month changes.
class ReportRemittancesCubit extends Cubit<ReportRemittancesState> {
  ReportRemittancesCubit({required this._reports, required DateTime month})
    : super(ReportRemittancesState(month: DateTime(month.year, month.month)));

  final ReportRepository _reports;

  Future<void> load([DateTime? month]) async {
    final shown = month == null ? state.month : DateTime(month.year, month.month);
    final filter = state.filter;
    emit(ReportRemittancesState(month: shown, filter: filter));
    try {
      final detail = await _reports.monthlyRemittances(shown.year, shown.month);
      if (isClosed || state.month != shown) return;
      emit(ReportRemittancesState(month: shown, status: ReportDetailStatus.success, detail: detail, filter: filter));
    } on ApiException catch (error) {
      if (isClosed || state.month != shown) return;
      emit(
        ReportRemittancesState(
          month: shown,
          status: error.statusCode == 404 ? ReportDetailStatus.unavailable : ReportDetailStatus.failure,
          error: error.message,
          filter: filter,
        ),
      );
    }
  }

  void filter(ReportFilter filter) => emit(state.copyWith(filter: filter, page: 0));

  void page(int page) => emit(state.copyWith(page: page.clamp(0, state.pages == 0 ? 0 : state.pages - 1)));
}
