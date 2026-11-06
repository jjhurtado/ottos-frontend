import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

/// REQ-010: the refactor must not change a visible text. Expected values are
/// the literals the code had before the move, written out here on purpose
/// (never read back from ReportTexts or ReportCsv).
void main() {
  test('REQ-010 CR-1: the PDF labels have their own constants, same words as before', () {
    expect(ReportTexts.voidedOnColumn, 'Anulada el');
    expect(ReportTexts.voidedReasonColumn, 'Motivo de la anulación');
    expect(ReportTexts.detailTitle, 'Resumen a detalle');
    expect(ReportTexts.yes, 'Sí');
  });

  setUpAll(OttosLocalization.initialize);

  final detail = MonthlyReportDetail.fromJson(detailJson);
  final report = MonthlyReport.fromJson(monthlyJson);

  test('REQ-010: the moved labels keep their exact text', () {
    expect(ReportTexts.brand, "Otto's Bussines");
    expect(ReportTexts.summaryFooter, "Otto's Bussines · Panel de operaciones");
    expect(ReportTexts.detailFooter('octubre de 2026'), "Otto's Bussines · Resumen a detalle de octubre de 2026");
    expect(ReportTexts.pageNumber(2, 5), 'Página 2 de 5');
    expect(ReportTexts.pageNumber(1, 1), 'Página 1 de 1');
    expect(ReportTexts.monthEndStatusShort, 'Estado al cierre');
    expect(ReportTexts.yes, 'Sí');
    expect(ReportTexts.no, 'No');
    expect(ReportTexts.business, 'El negocio');
    expect(ReportTexts.deliveryType, 'Entrega');
    expect(ReportTexts.pickupType, 'Recogida');
    expect(ReportTexts.onTheHouseDelivery, 'Entrega por la casa');
    expect(ReportTexts.onTheHouseDeliveryShort, 'Entrega · casa');
  });

  test('REQ-010: the CSV header is the same columns in the same order, led by the REQ-019 beneficiary', () {
    const before = [
      'Beneficiario',
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
    expect(ReportCsv.columns, before);
    expect(Csv.decode(ReportCsv.encode(detail)).first, before);
  });

  test('REQ-010: CSV cells for type, courier and yes/no keep their text', () {
    final rows = Csv.decode(ReportCsv.encode(detail)).skip(1).toList();
    expect(rows.map((r) => r[2]).toSet(), {'Entrega', 'Recogida'});
    expect(rows.map((r) => r[18]).toSet(), {'Sí', 'No'});
    final pickup = detail.remittances.indexWhere((r) => r.isPickup);
    expect(rows[pickup][2], 'Recogida');
    expect(rows[pickup][7], 'El negocio');
  });

  test('REQ-010: both PDFs still carry the same author', () async {
    final summary = latin1.decode(await buildMonthlyReportPdf(report, month: DateTime(2026, 10)));
    final full = latin1.decode(await buildMonthlyDetailPdf(report, detail, month: DateTime(2026, 10)));
    for (final pdf in [summary, full]) {
      expect(pdf, contains("Otto's Bussines"));
    }
  });
}
