import 'package:equatable/equatable.dart';

import '../models/report_detail.dart';
import '../utils/business_time.dart';
import 'report_totals.dart';

/// One registration day of the month's list (REQ-026): the rows of that day on
/// the page shown and the summary of the whole day (BR-2).
class ReportDay extends Equatable {
  const ReportDay({required this.date, required this.rows, required this.totals});

  /// The registration date in business time (BR-1), time 00:00; null for rows
  /// without a registration time.
  final DateTime? date;

  /// The day's rows on the page, in the list's order.
  final List<ReportRemittance> rows;

  /// Of every row of the day that passes the filters, on any page: the live
  /// ones summed, the voided ones only counted ([ReportTotals.voided]).
  final ReportTotals totals;

  @override
  List<Object?> get props => [date, rows, totals];
}

/// The business date a row was registered on (BR-1).
DateTime? reportDayOf(ReportRemittance row) {
  final createdAt = row.createdAt;
  return createdAt == null ? null : BusinessTime.today(createdAt);
}

/// Groups [shown] (the page, already filtered and sorted) by registration day,
/// keeping its order, so the days follow the list's sort (BR-3). Each day's
/// summary is computed over [all] (every filtered row; default [shown]), so a
/// day split across pages shows the same summary on both (AC-1.4).
List<ReportDay> groupReportDays(List<ReportRemittance> shown, {List<ReportRemittance>? all}) {
  final byDay = <DateTime?, List<ReportRemittance>>{};
  for (final row in all ?? shown) {
    (byDay[reportDayOf(row)] ??= []).add(row);
  }
  final totals = <DateTime?, ReportTotals>{};
  final days = <ReportDay>[];
  List<ReportRemittance>? current;
  DateTime? currentDate;
  for (final row in shown) {
    final date = reportDayOf(row);
    if (current == null || date != currentDate) {
      current = [];
      currentDate = date;
      days.add(ReportDay(date: date, rows: current, totals: totals[date] ??= ReportTotals.of(byDay[date] ?? const [])));
    }
    current.add(row);
  }
  return [for (final day in days) ReportDay(date: day.date, rows: List.unmodifiable(day.rows), totals: day.totals)];
}
