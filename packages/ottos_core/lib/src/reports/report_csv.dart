import '../models/report_detail.dart';
import '../utils/csv.dart';
import '../utils/cuba_time.dart';
import '../utils/formatters.dart';
import 'report_pdf.dart';
import 'report_texts.dart';

/// The month's remittances as CSV: one row per remittance, voided ones
/// included and marked, `;`, UTF-8 with BOM and decimal commas, so it opens
/// right in Excel in Spanish. No personal data.
abstract final class ReportCsv {
  static const columns = [
    'Código',
    'Tipo',
    'Estado',
    'Registrada',
    'Completada',
    'Municipio',
    'Repartidor',
    'Moneda de cobro',
    'Enviado',
    'Comisión',
    'Cobrado',
    'Recogido',
    'Moneda de entrega',
    'A entregar',
    'Tasa',
    'Por la casa',
    'Comisión no cobrada',
    'Anulada',
    'Anulada el',
    'Motivo de la anulación',
  ];

  static String encode(MonthlyReportDetail detail) {
    String number(double value) => Formatters.money(value, null);
    String yesNo(bool value) => value ? 'Sí' : 'No';
    return Csv.encode([
      columns,
      for (final row in detail.remittances)
        [
          row.code,
          row.isPickup ? 'Recogida' : 'Entrega',
          reportStatusName(row),
          CubaTime.sortable(row.createdAt),
          CubaTime.sortable(row.completedAt),
          row.municipalityName ?? '',
          row.completedFromBusiness ? 'El negocio' : (row.courierName ?? ''),
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
          CubaTime.sortable(row.voided?.at),
          row.voided?.reason ?? '',
        ],
    ]);
  }
}
