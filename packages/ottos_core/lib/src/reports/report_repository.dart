import '../api/api_client.dart';
import '../models/monthly_report.dart';

/// Business reports (`reports:read`).
class ReportRepository {
  ReportRepository({required this._api});

  final ApiClient _api;

  /// The sales of [year]-[month], in Cuba time.
  Future<MonthlyReport> monthly(int year, int month) async => MonthlyReport.fromJson(
    await _api.get<Map<String, dynamic>>(
      '/reports/monthly',
      query: {'month': '$year-${month.toString().padLeft(2, '0')}'},
    ),
  );
}
