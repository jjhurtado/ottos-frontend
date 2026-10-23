import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/core_texts.dart';
import '../models/monthly_report.dart';
import '../models/report_detail.dart';
import '../utils/cuba_time.dart';
import '../utils/formatters.dart';
import 'report_texts.dart';
import 'report_totals.dart';

const _navy = PdfColor.fromInt(0xFF040A30);
const _green = PdfColor.fromInt(0xFF1F6B42);
const _grey = PdfColor.fromInt(0xFF44474E);
const _lightGrey = PdfColor.fromInt(0xFF6B6F7B);
const _rule = PdfColor.fromInt(0xFFC9CBD3);

/// The PDFs' built-in font only has Latin-1: anything else (a "−", an emoji in
/// a void reason…) becomes its nearest Latin-1 text or "?".
String pdfSafe(String text) {
  const replacements = {
    '−': '-',
    '–': '-',
    '—': '-',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
    '…': '...',
    '€': 'EUR',
    ' ': ' ',
    ' ': ' ',
  };
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final replacement = replacements[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if ((rune >= 0x20 && rune <= 0x7E) || (rune >= 0xA0 && rune <= 0xFF)) {
      buffer.write(char);
    } else if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
      buffer.write(' ');
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

/// Amounts with the Spanish separators, without currency.
String _number(double amount) => pdfSafe(Formatters.money(amount, null));

String _money(double amount, String currency) => pdfSafe(Formatters.money(amount, currency));

pw.Widget _box(String label, String value, String help, {bool highlight = false, double valueSize = 16}) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: highlight ? _green : _rule, width: highlight ? 2 : 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(pdfSafe(label), style: pw.TextStyle(fontSize: 9, color: highlight ? _green : _grey)),
          pw.SizedBox(height: 4),
          pw.Text(
            pdfSafe(value),
            style: pw.TextStyle(
              fontSize: valueSize,
              fontWeight: pw.FontWeight.bold,
              color: highlight ? _green : PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(pdfSafe(help), style: const pw.TextStyle(fontSize: 9, color: _grey)),
        ],
      ),
    );

/// A table with the first [leftColumns] columns (and any in [alsoLeft]) aligned left and the rest right.
pw.Widget _table(
  List<String> headers,
  List<List<String>> rows, {
  int leftColumns = 1,
  Set<int> alsoLeft = const {},
  double fontSize = 9.5,
  Map<int, pw.TableColumnWidth>? widths,
  Set<int> boldRows = const {},
  PdfColor? textColor,
}) => pw.TableHelper.fromTextArray(
  headers: [for (final header in headers) pdfSafe(header)],
  data: [
    for (final row in rows) [for (final cell in row) pdfSafe(cell)],
  ],
  border: null,
  columnWidths: widths,
  headerStyle: pw.TextStyle(fontSize: fontSize - 0.5, fontWeight: pw.FontWeight.bold),
  cellStyle: pw.TextStyle(fontSize: fontSize, color: textColor),
  headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
  rowDecoration: const pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _rule)),
  ),
  cellAlignments: {
    for (var i = 0; i < headers.length; i++)
      i: i < leftColumns || alsoLeft.contains(i) ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
  },
  headerAlignments: {
    for (var i = 0; i < headers.length; i++)
      i: i < leftColumns || alsoLeft.contains(i) ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
  },
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  textStyleBuilder: boldRows.isEmpty
      ? null
      : (index, data, row) => boldRows.contains(row - 1)
            ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
            : pw.TextStyle(fontSize: fontSize, color: textColor),
);

/// Boxes four to a row.
List<pw.Widget> _boxRows(List<pw.Widget> boxes) => [
  for (var start = 0; start < boxes.length; start += 4) ...[
    if (start > 0) pw.SizedBox(height: 8),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = start; i < start + 4; i++) ...[
          if (i > start) pw.SizedBox(width: 8),
          pw.Expanded(child: i < boxes.length ? boxes[i] : pw.SizedBox()),
        ],
      ],
    ),
  ],
];

pw.Widget _heading(String text, {PdfColor color = _navy, double size = 12}) => pw.Text(
  pdfSafe(text),
  style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: color),
);

List<List<String>> _currencyRows(MonthlyReport report) => [
  for (final line in report.byCurrency)
    [
      line.currency,
      '${line.remittances}',
      _number(line.sent),
      _number(line.fees),
      _number(line.collected),
      _money(line.delivered, line.currency),
      _number(line.deliveredCurrency),
    ],
  [
    ReportTexts.totalRow,
    '${report.deliveries}',
    _number(report.byCurrency.fold(0, (sum, line) => sum + line.sent)),
    _number(report.deliveryFees),
    _number(report.collected),
    '-',
    _number(report.deliveredCurrency),
  ],
];

List<String> _currencyHeaders(MonthlyReport report) => [
  'Moneda',
  ReportTexts.reportRemittances,
  ReportTexts.sent,
  ReportTexts.fees,
  ReportTexts.collected,
  ReportTexts.delivered,
  'En ${report.businessCurrency}',
];

List<List<String>> _typeRows(MonthlyReport report) => [
  for (final line in report.byType)
    [
      line.type.code == 'PICKUP' ? ReportTexts.pickups : ReportTexts.deliveries,
      '${line.remittances}',
      _number(line.collected),
      _number(line.fees),
    ],
];

const _typeHeaders = ['Tipo', ReportTexts.reportRemittances, ReportTexts.collectedOrPicked, ReportTexts.fees];

/// The month's summary on one A4 page, made on the device (no load on the server).
Future<Uint8List> buildMonthlyReportPdf(MonthlyReport report, {required DateTime month, DateTime? now}) {
  final document = pw.Document(
    title: pdfSafe('${ReportTexts.monthlyReport} ${ReportTexts.monthTitle(month)}'),
    author: "Otto's Bussines",
  );
  final generated = Formatters.dateTime(report.generatedAt ?? now ?? DateTime.now());
  final period = ReportTexts.reportPeriod(
    Formatters.date(report.from),
    Formatters.date(report.to),
    report.businessCurrency,
  );
  String usd(double amount) => _number(amount);
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
                      '${ReportTexts.monthlyReport} de ventas',
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                    pw.Text(
                      pdfSafe(ReportTexts.generatedOn(generated)),
                      style: const pw.TextStyle(fontSize: 9, color: _grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            pdfSafe(ReportTexts.monthTitle(month)),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
          pw.Text(pdfSafe(period), style: const pw.TextStyle(fontSize: 9, color: _grey)),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _box(
                  ReportTexts.reportRemittances,
                  '${report.remittances}',
                  ReportTexts.deliveriesAndPickups(report.deliveries, report.pickups),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _box(ReportTexts.totalCollected, usd(report.collected), 'Entregas: enviado + comisión'),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _box(ReportTexts.totalDelivered, usd(report.deliveredCurrency), delivered)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _box(ReportTexts.difference, usd(report.difference), 'Cobrado - entregado, solo entregas'),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _box(
                  ReportTexts.pickupsCollected,
                  usd(report.pickupsCollected),
                  ReportTexts.pickupsHelp(report.pickups, usd(report.pickupsFees)),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _box(
                  ReportTexts.earnings,
                  usd(report.fees),
                  ReportTexts.earningsHelp(
                    usd(report.deliveryFees),
                    usd(report.pickupsFees),
                    usd(report.roundingMargin),
                  ),
                  highlight: true,
                ),
              ),
            ],
          ),
          if (report.onTheHouse case final onTheHouse?) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _box(
                    ReportTexts.onTheHouseReport,
                    usd(onTheHouse.waivedFees),
                    ReportTexts.onTheHouseHelp(onTheHouse.remittances, usd(onTheHouse.amount)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.SizedBox()),
                pw.SizedBox(width: 8),
                pw.Expanded(child: pw.SizedBox()),
              ],
            ),
          ],
          pw.SizedBox(height: 18),
          _heading(ReportTexts.byCurrency),
          pw.SizedBox(height: 6),
          _table(_currencyHeaders(report), _currencyRows(report)),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _heading(ReportTexts.byType),
                    pw.SizedBox(height: 6),
                    _table(_typeHeaders, _typeRows(report)),
                  ],
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _heading('Estado al cierre'),
                    pw.SizedBox(height: 6),
                    _table(
                      ['', ReportTexts.reportRemittances],
                      [
                        [ReportTexts.completedLabel, '${report.completed}'],
                        [ReportTexts.openLabel, '${report.open}'],
                        [ReportTexts.withIncidentLabel, '${report.withIncident}'],
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

/// The status of a row as the report shows it.
String reportStatusName(ReportRemittance row) =>
    row.isVoided ? ReportTexts.voided : CoreTexts.statusName(row.status, type: row.type, fallback: row.statusName);

/// The month's summary and every remittance in it, A4 landscape: the summary,
/// then the deliveries, the pickups and the voided ones, each from a new page.
/// No personal data: each remittance by its code.
Future<Uint8List> buildMonthlyDetailPdf(
  MonthlyReport report,
  MonthlyReportDetail detail, {
  required DateTime month,
  DateTime? now,
}) {
  final title = ReportTexts.monthTitle(month);
  final document = pw.Document(title: pdfSafe('Resumen a detalle $title'), author: "Otto's Bussines");
  final generated = CubaTime.dateTime(detail.generatedAt ?? report.generatedAt ?? now ?? DateTime.now());
  final rows = detail.remittances;
  final deliveries = [
    for (final row in rows)
      if (!row.isVoided && !row.isPickup) row,
  ];
  final pickups = [
    for (final row in rows)
      if (!row.isVoided && row.isPickup) row,
  ];
  final voided = [
    for (final row in rows)
      if (row.isVoided) row,
  ];
  final deliveryTotals = ReportTotals.of(deliveries);
  final pickupTotals = ReportTotals.of(pickups);
  final currency = detail.businessCurrency;
  String date(DateTime? instant) => instant == null ? '-' : CubaTime.shortDate(instant);
  String courier(ReportRemittance row) => row.completedFromBusiness ? 'El negocio' : (row.courierName ?? '-');

  pw.Widget header(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 3)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "OTTO'S",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy),
            ),
            pw.SizedBox(width: 14),
            pw.Text(
              pdfSafe('Resumen a detalle · $title'),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _navy),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              pdfSafe(
                'Del ${Formatters.date(detail.from ?? report.from)} al ${Formatters.date(detail.to ?? report.to)} · '
                'hora de Cuba · importes en $currency salvo que se indique',
              ),
              style: const pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
            pw.Text(
              pdfSafe('${ReportTexts.generatedOn(generated)} · sin datos personales'),
              style: const pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
          ],
        ),
      ],
    ),
  );

  pw.Widget footer(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _rule)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          pdfSafe("Otto's Bussines · Resumen a detalle de ${ReportTexts.monthLower(month)}"),
          style: const pw.TextStyle(fontSize: 8.5, color: _grey),
        ),
        pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8.5, color: _grey),
        ),
      ],
    ),
  );

  final delivered = report.delivered.map((money) => Formatters.money(money.amount, money.currency)).join(' · ');
  final onTheHouse = report.onTheHouse;
  final sections = <String>[
    if (deliveries.isNotEmpty) 'entregas (${deliveries.length})',
    if (pickups.isNotEmpty) 'recogidas (${pickups.length})',
    if (voided.isNotEmpty) 'anuladas (${voided.length}), con el motivo de cada una, que no suman en ningún total',
  ];
  var section = 1;

  final content = <pw.Widget>[
    _heading('${section++} · Resumen del mes', size: 15),
    pw.SizedBox(height: 10),
    ..._boxRows([
      _box(
        ReportTexts.reportRemittances,
        '${report.remittances}',
        '${ReportTexts.deliveriesAndPickups(report.deliveries, report.pickups)}'
            '${detail.voided == 0 ? '' : ' · ${detail.voided} anuladas aparte'}',
      ),
      _box(ReportTexts.totalCollected, _number(report.collected), 'Entregas: enviado + comisión'),
      _box(ReportTexts.totalDelivered, _number(report.deliveredCurrency), delivered),
      _box(ReportTexts.difference, _number(report.difference), 'Cobrado - entregado'),
      _box(
        ReportTexts.pickupsCollected,
        _number(report.pickupsCollected),
        ReportTexts.pickupsHelp(report.pickups, _number(report.pickupsFees)),
      ),
      _box(
        ReportTexts.earnings,
        _number(report.fees),
        'Entregas ${_number(report.deliveryFees)} · recogidas ${_number(report.pickupsFees)}',
        highlight: true,
      ),
      _box(
        ReportTexts.onTheHouseReport,
        _number(onTheHouse?.waivedFees ?? 0),
        ReportTexts.onTheHouseHelp(onTheHouse?.remittances ?? 0, _number(onTheHouse?.amount ?? 0)),
      ),
      _box(
        'Estado al cierre',
        '${report.completed} / ${report.open}',
        'Completadas / abiertas · ${report.withIncident} con incidencia',
      ),
    ]),
    pw.SizedBox(height: 14),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _heading('Por moneda de entrega'),
              pw.SizedBox(height: 4),
              _table(
                _currencyHeaders(report),
                _currencyRows(report),
                fontSize: 9,
                boldRows: {report.byCurrency.length},
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _heading(ReportTexts.byType),
              pw.SizedBox(height: 4),
              _table(_typeHeaders, _typeRows(report), fontSize: 9),
            ],
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 14),
    _heading('Contenido'),
    pw.SizedBox(height: 4),
    pw.Text(
      pdfSafe(
        sections.isEmpty
            ? 'No hay remesas en el mes.'
            : 'Después del resumen: ${sections.join(' · ')}. Cada parte empieza en una página nueva.',
      ),
      style: const pw.TextStyle(fontSize: 9.5, color: _grey),
    ),
    pw.Text(
      pdfSafe(
        'Cada remesa se identifica por su código. El informe no incluye nombres, teléfonos, direcciones ni PIN. '
        'El motivo de una anulación se copia tal cual lo escribió quien la anuló.',
      ),
      style: const pw.TextStyle(fontSize: 9.5, color: _grey),
    ),
  ];

  if (deliveries.isNotEmpty) {
    content.addAll([
      pw.NewPage(),
      _heading('${section++} · Entregas (${deliveries.length})', size: 15),
      pw.SizedBox(height: 6),
      _table(
        [
          ReportTexts.code,
          ReportTexts.registered,
          ReportTexts.completed,
          ReportTexts.municipality,
          ReportTexts.courier,
          ReportTexts.status,
          ReportTexts.sent,
          ReportTexts.fee,
          ReportTexts.collected,
          ReportTexts.toDeliver,
          ReportTexts.rate,
          'Casa',
        ],
        [
          for (final row in deliveries)
            [
              row.code,
              date(row.createdAt),
              date(row.completedAt),
              row.municipalityName ?? '-',
              courier(row),
              '${reportStatusName(row)}${row.withIncident ? ' · incidencia' : ''}',
              _number(row.amount),
              _number(row.fee),
              _number(row.collected),
              _money(row.amountToDeliver, row.targetCurrency),
              ReportTexts.formatRate(row.rate),
              row.onTheHouse ? 'Sí' : '',
            ],
          [
            ReportTexts.totalRow,
            '',
            '',
            '',
            '',
            '',
            _number(deliveryTotals.sent),
            _number(deliveryTotals.deliveryFees),
            _number(deliveryTotals.collected),
            '-',
            '',
            '',
          ],
        ],
        leftColumns: 6,
        fontSize: 8.5,
        boldRows: {deliveries.length},
        widths: const {
          0: pw.FixedColumnWidth(70),
          1: pw.FixedColumnWidth(52),
          2: pw.FixedColumnWidth(58),
          3: pw.FlexColumnWidth(1.6),
          4: pw.FlexColumnWidth(1.1),
          5: pw.FlexColumnWidth(1.2),
          6: pw.FixedColumnWidth(60),
          7: pw.FixedColumnWidth(54),
          8: pw.FixedColumnWidth(60),
          9: pw.FixedColumnWidth(86),
          10: pw.FixedColumnWidth(40),
          11: pw.FixedColumnWidth(34),
        },
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        pdfSafe(
          'Por fecha de registro. «A entregar» en la moneda de entrega. «Casa» = entrega por la casa, sin comisión.',
        ),
        style: const pw.TextStyle(fontSize: 8.5, color: _grey),
      ),
    ]);
  }

  if (pickups.isNotEmpty) {
    content.addAll([
      pw.NewPage(),
      _heading('${section++} · Recogidas (${pickups.length})', size: 15),
      pw.SizedBox(height: 6),
      _table(
        [
          ReportTexts.code,
          ReportTexts.registered,
          ReportTexts.completed,
          ReportTexts.municipality,
          ReportTexts.courier,
          ReportTexts.status,
          ReportTexts.picked,
          ReportTexts.fee,
          'Tasa (informativa)',
        ],
        [
          for (final row in pickups)
            [
              row.code,
              date(row.createdAt),
              date(row.completedAt),
              row.municipalityName ?? '-',
              courier(row),
              '${reportStatusName(row)}${row.withIncident ? ' · incidencia' : ''}',
              _number(row.collected),
              _number(row.fee),
              ReportTexts.formatRate(row.rate),
            ],
          [
            ReportTexts.totalRow,
            '',
            '',
            '',
            '',
            '',
            _number(pickupTotals.pickupCollected),
            _number(pickupTotals.pickupFees),
            '',
          ],
        ],
        leftColumns: 6,
        fontSize: 8.5,
        boldRows: {pickups.length},
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        pdfSafe(
          'En una recogida no se entrega nada: lo recogido no entra en cobrado ni en entregado; su comisión sí suma a '
          'las ganancias.',
        ),
        style: const pw.TextStyle(fontSize: 8.5, color: _grey),
      ),
    ]);
  }

  if (voided.isNotEmpty) {
    content.addAll([
      pw.NewPage(),
      _heading('${section++} · Anuladas (${voided.length}) · no suman en ningún total', color: _lightGrey, size: 15),
      pw.SizedBox(height: 6),
      _table(
        [
          ReportTexts.code,
          ReportTexts.type,
          ReportTexts.registered,
          'Anulada el',
          ReportTexts.municipality,
          ReportTexts.courier,
          ReportTexts.amount,
          ReportTexts.fee,
          'Motivo de la anulación',
        ],
        [
          for (final row in voided)
            [
              row.code,
              row.isPickup ? 'Recogida' : 'Entrega',
              date(row.createdAt),
              date(row.voided!.at),
              row.municipalityName ?? '-',
              row.courierName ?? '-',
              _number(row.amount),
              _number(row.fee),
              row.voided!.reason,
            ],
        ],
        leftColumns: 6,
        alsoLeft: const {8},
        fontSize: 8.5,
        textColor: _grey,
        widths: const {
          0: pw.FixedColumnWidth(70),
          1: pw.FixedColumnWidth(52),
          2: pw.FixedColumnWidth(52),
          3: pw.FixedColumnWidth(52),
          4: pw.FlexColumnWidth(1.2),
          5: pw.FlexColumnWidth(1),
          6: pw.FixedColumnWidth(56),
          7: pw.FixedColumnWidth(50),
          8: pw.FlexColumnWidth(2.6),
        },
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        pdfSafe(
          'Se muestran para cuadrar con los tickets, pero no cuentan en el resumen ni en las tablas anteriores. El '
          'motivo se copia tal cual lo escribió quien anuló.',
        ),
        style: const pw.TextStyle(fontSize: 8.5, color: _grey),
      ),
    ]);
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 22),
      maxPages: 400,
      header: header,
      footer: footer,
      build: (context) => content,
    ),
  );
  return document.save();
}
