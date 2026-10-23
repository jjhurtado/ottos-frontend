import '../api/api_client.dart';
import '../models/monthly_report.dart';
import '../models/report_detail.dart';
import '../models/statistics.dart';
import '../utils/formatters.dart';

/// Business reports (`reports:read`).
class ReportRepository {
  ReportRepository({required this._api});

  final ApiClient _api;

  static String _month(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  /// The sales of [year]-[month], in Cuba time.
  Future<MonthlyReport> monthly(int year, int month) async => MonthlyReport.fromJson(
    await _api.get<Map<String, dynamic>>('/reports/monthly', query: {'month': _month(year, month)}),
  );

  /// Every remittance registered in [year]-[month], voided ones included, without
  /// personal data. A backend from before it answers 404.
  Future<MonthlyReportDetail> monthlyRemittances(int year, int month) async => MonthlyReportDetail.fromJson(
    await _api.get<Map<String, dynamic>>('/reports/monthly/remittances', query: {'month': _month(year, month)}),
  );

  /// The sales from [from] to [to], both days included, Cuba time; at most 366
  /// days. A backend from before it answers 404.
  Future<Statistics> statistics(DateTime from, DateTime to) async => Statistics.fromJson(
    await _api.get<Map<String, dynamic>>(
      '/reports/statistics',
      query: {'from': Formatters.apiDate(from), 'to': Formatters.apiDate(to)},
    ),
  );
}
