import '../models/report_detail.dart';
import '../utils/csv.dart';
import '../utils/business_time.dart';
import '../utils/formatters.dart';
import 'report_pdf.dart';
import 'report_texts.dart';

/// The month's remittances as CSV: one row per remittance, voided ones
/// included and marked, `;`, UTF-8 with BOM and decimal commas, so it opens
/// right in Excel in Spanish. It carries the beneficiary's name (REQ-019
/// AC-3.1, ADR-004): whoever shares the file is responsible for it.
abstract final class ReportCsv {
  static const columns = ReportTexts.csvColumns;

  static String encode(MonthlyReportDetail detail) {
    String number(double value) => Formatters.money(value, null);
    String yesNo(bool value) => value ? ReportTexts.yes : ReportTexts.no;
    return Csv.encode([
      columns,
      for (final row in detail.remittances)
        [
          row.beneficiaryName ?? '',
          row.code,
          row.isPickup ? ReportTexts.pickupType : ReportTexts.deliveryType,
          reportStatusName(row),
          BusinessTime.sortable(row.createdAt),
          BusinessTime.sortable(row.completedAt),
          row.municipalityName ?? '',
          row.completedFromBusiness ? ReportTexts.business : (row.courierName ?? ''),
          row.sourceCurrency,
          row.isPickup ? '' : number(row.amount),
          number(row.fee),
          row.isPickup ? '' : number(row.collected),
          row.isPickup ? number(row.collected) : '',
          row.isPickup ? '' : row.targetCurrency,
          row.isPickup ? '' : number(row.amountToDeliver),
          ReportTexts.formatRate(row.rate),
          yesNo(row.onTheHouse),
          number(row.waivedFee ?? 0),
          yesNo(row.isVoided),
          BusinessTime.sortable(row.voided?.at),
          row.voided?.reason ?? '',
        ],
    ]);
  }
}
