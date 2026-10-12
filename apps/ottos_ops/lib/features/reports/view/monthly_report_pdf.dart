import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../app/ops_texts.dart';

const _navy = PdfColor.fromInt(0xFF040A30);
const _green = PdfColor.fromInt(0xFF1F6B42);
const _grey = PdfColor.fromInt(0xFF44474E);
const _rule = PdfColor.fromInt(0xFFC9CBD3);

/// "Octubre de 2026".
String monthTitle(DateTime month) {
  final text = DateFormat.yMMMM('es').format(month);
  return text[0].toUpperCase() + text.substring(1);
}

/// Amounts with the Spanish separators. The PDF's built-in font has no "−",
/// so negatives use "-".
String _usd(double amount) => Formatters.money(amount, null).replaceAll('−', '-');

/// The month's summary on one A4 page, made in the panel (no load on the server).
Future<Uint8List> buildMonthlyReportPdf(MonthlyReport report, {required DateTime month, DateTime? now}) {
  final document = pw.Document(title: '${OpsTexts.monthlyReport} ${monthTitle(month)}', author: "Otto's Bussines");
  final generated = Formatters.dateTime(report.generatedAt ?? now ?? DateTime.now());
  final period = OpsTexts.reportPeriod(Formatters.date(report.from), Formatters.date(report.to));

  pw.Widget box(String label, String value, String help, {bool highlight = false}) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: highlight ? _green : _rule, width: highlight ? 2 : 1),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: highlight ? _green : _grey)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: highlight ? _green : PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(help, style: const pw.TextStyle(fontSize: 9, color: _grey)),
      ],
    ),
  );

  pw.Widget table(List<String> headers, List<List<String>> rows, {bool boldLast = false}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        border: null,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule)),
        ),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
        },
        headerAlignments: {
          0: pw.Alignment.centerLeft,
          for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight,
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      );

  pw.Widget heading(String text) => pw.Text(
    text,
    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy),
  );

  final delivered = report.delivered.map((money) => Formatters.money(money.amount, money.currency)).join(' · ');

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "OTTO'S",
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy),
                    ),
                    pw.Text('BUSSINES', style: const pw.TextStyle(fontSize: 7, letterSpacing: 3, color: _navy)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${OpsTexts.monthlyReport} de ventas',
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                    pw.Text(OpsTexts.generatedOn(generated), style: const pw.TextStyle(fontSize: 9, color: _grey)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            monthTitle(month),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
          pw.Text(period, style: const pw.TextStyle(fontSize: 9, color: _grey)),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: box(
                  OpsTexts.reportRemittances,
                  '${report.remittances}',
                  OpsTexts.deliveriesAndPickups(report.deliveries, report.pickups),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: box(OpsTexts.totalCollected, _usd(report.collected), 'Entregas: enviado + comisión')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: box(OpsTexts.totalDelivered, _usd(report.deliveredUsd), delivered)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: box(OpsTexts.difference, _usd(report.difference), 'Cobrado - entregado, solo entregas'),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: box(
                  OpsTexts.pickupsCollected,
                  _usd(report.pickupsCollected),
                  OpsTexts.pickupsHelp(report.pickups, _usd(report.pickupsFees)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: box(
                  OpsTexts.earnings,
                  _usd(report.fees),
                  OpsTexts.earningsHelp(
                    _usd(report.deliveryFees),
                    _usd(report.pickupsFees),
                    _usd(report.roundingMargin),
                  ),
                  highlight: true,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          heading(OpsTexts.byCurrency),
          pw.SizedBox(height: 6),
          table(
            ['Moneda', 'Remesas', OpsTexts.sent, OpsTexts.fees, OpsTexts.collected, OpsTexts.delivered, 'En USD'],
            [
              for (final line in report.byCurrency)
                [
                  line.currency,
                  '${line.remittances}',
                  _usd(line.sent),
                  _usd(line.fees),
                  _usd(line.collected),
                  Formatters.money(line.delivered, line.currency),
                  _usd(line.deliveredUsd),
                ],
              [
                OpsTexts.totalRow,
                '${report.deliveries}',
                _usd(report.byCurrency.fold(0, (sum, line) => sum + line.sent)),
                _usd(report.deliveryFees),
                _usd(report.collected),
                '-',
                _usd(report.deliveredUsd),
              ],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    heading(OpsTexts.byType),
                    pw.SizedBox(height: 6),
                    table(
                      ['Tipo', 'Remesas', OpsTexts.collectedOrPicked, OpsTexts.fees],
                      [
                        for (final line in report.byType)
                          [
                            line.type == RemittanceType.pickup ? 'Recogidas' : 'Entregas',
                            '${line.remittances}',
                            _usd(line.collected),
                            _usd(line.fees),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    heading('Estado al cierre'),
                    pw.SizedBox(height: 6),
                    table(
                      ['', 'Remesas'],
                      [
                        [OpsTexts.completedLabel, '${report.completed}'],
                        [OpsTexts.openLabel, '${report.open}'],
                        [OpsTexts.withIncidentLabel, '${report.withIncident}'],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _rule)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Otto's Bussines · Panel de operaciones", style: const pw.TextStyle(fontSize: 9, color: _grey)),
                pw.Text('Página 1 de 1', style: const pw.TextStyle(fontSize: 9, color: _grey)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return document.save();
}
