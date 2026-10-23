import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

import 'fixtures.dart';

void main() {
  setUpAll(OttosLocalization.initialize);

  final detail = MonthlyReportDetail.fromJson(detailJson);
  final report = MonthlyReport.fromJson(monthlyJson);

  group('model', () {
    test('reads the counts and every row, voided ones marked', () {
      expect(detail.month, '2026-10');
      expect(detail.lines, 5);
      expect(detail.voided, 1);
      expect(detail.total, 4);
      expect(detail.remittances, hasLength(5));

      final voided = detail.remittances.singleWhere((row) => row.isVoided);
      expect(voided.code, 'OT-F9V3GA');
      expect(voided.voided!.reason, reasonWithSeparator);
      expect(voided.voided!.byName, 'Admin');

      final pickup = detail.remittances.singleWhere((row) => row.isPickup);
      expect(pickup.deliveredCurrency, isNull);
      expect(pickup.completedFromBusiness, isTrue);
      expect(pickup.courierName, isNull);

      final onTheHouse = detail.remittances.singleWhere((row) => row.onTheHouse);
      expect(onTheHouse.waivedFee, 23.70);
      expect(onTheHouse.withIncident, isTrue);
    });

    test('a row without optional fields still reads', () {
      final row = ReportRemittance.fromJson(const {'id': 'x', 'code': 'OT-1'});
      expect(row.type, RemittanceType.delivery);
      expect(row.isVoided, isFalse);
      expect(row.amount, 0);
    });
  });

  group('totals', () {
    test('the rows not voided add up to the monthly report', () {
      final totals = ReportTotals.of(detail.remittances);

      expect(totals.remittances, report.remittances);
      expect(totals.deliveries, report.deliveries);
      expect(totals.pickups, report.pickups);
      expect(totals.collected, report.collected);
      expect(totals.fees, report.fees);
      expect(totals.deliveryFees, report.deliveryFees);
      expect(totals.deliveredCurrency, report.deliveredCurrency);
      expect(totals.pickupCollected, report.pickupsCollected);
      expect(totals.pickupFees, report.pickupsFees);
      expect(totals.waivedFees, report.onTheHouse!.waivedFees);
      expect(totals.onTheHouseAmount, report.onTheHouse!.amount);
      expect(totals.sent, report.byCurrency.fold<double>(0, (sum, line) => sum + line.sent));
      expect(totals.voided, 1, reason: 'listed apart, never added');
    });

    test('the detail counts match the summary', () {
      expect(detail.total, report.remittances);
      expect(detail.deliveries, report.deliveries);
      expect(detail.completed, report.completed);
      expect(detail.open, report.open);
      expect(detail.withIncident, report.withIncident);
    });
  });

  group('filter', () {
    List<String> codes(ReportFilter filter) => [for (final row in filter.apply(detail.remittances)) row.code];

    test('newest first by default, voided ones shown', () {
      expect(codes(const ReportFilter()), ['OT-H2N6LC', 'OT-F9V3GA', 'OT-R9T4BW', 'OT-P3X8RA', 'OT-K7Q2MA']);
      expect(codes(const ReportFilter(newestFirst: false)).first, 'OT-K7Q2MA');
    });

    test('by code, type, status, courier, on the house and voided', () {
      expect(codes(const ReportFilter(code: 'p3x')), ['OT-P3X8RA']);
      expect(codes(const ReportFilter(type: 'PICKUP')), ['OT-P3X8RA']);
      expect(codes(const ReportFilter(status: ReportStatusFilter.completed)), ['OT-P3X8RA', 'OT-K7Q2MA']);
      expect(codes(const ReportFilter(status: ReportStatusFilter.paid)), ['OT-H2N6LC'], reason: 'voided apart');
      expect(codes(const ReportFilter(status: ReportStatusFilter.incident)), ['OT-R9T4BW']);
      expect(codes(const ReportFilter(courier: 'Pedro Díaz')), ['OT-F9V3GA', 'OT-K7Q2MA']);
      expect(codes(const ReportFilter(courier: ReportFilter.withoutCourier)), ['OT-H2N6LC', 'OT-P3X8RA']);
      expect(codes(const ReportFilter(onlyOnTheHouse: true)), ['OT-R9T4BW']);
      expect(codes(const ReportFilter(showVoided: false)), isNot(contains('OT-F9V3GA')));
    });
  });

  group('CSV', () {
    final csv = ReportCsv.encode(detail);
    final rows = Csv.decode(csv);

    test('a header and one row per remittance, voided included', () {
      expect(csv.startsWith(Csv.bom), isTrue);
      expect(rows.first, ReportCsv.columns);
      expect(rows, hasLength(1 + 5));
      expect(rows.first.any((column) => column.toLowerCase().contains('nombre')), isFalse, reason: 'no personal data');
    });

    test('dates in Cuba time, decimal commas and the void reason as typed', () {
      final first = rows[1];
      expect(first[0], 'OT-K7Q2MA');
      // 16:30 UTC in October is 12:30 in Havana (UTC−4).
      expect(first[3], '2026-10-01 12:30');
      expect(first[8], '100,00');
      expect(first[10], '110,00');
      expect(first[13], '41.000,00');
      expect(first[14], '410');
      expect(first[17], 'No');

      final voided = rows.singleWhere((row) => row[0] == 'OT-F9V3GA');
      expect(voided[2], 'Anulada');
      expect(voided[17], 'Sí');
      expect(voided[18], '2026-10-12 09:03');
      expect(voided[19], reasonWithSeparator);

      final pickup = rows.singleWhere((row) => row[0] == 'OT-P3X8RA');
      expect(pickup[1], 'Recogida');
      expect(pickup[6], 'El negocio');
      expect(pickup[8], '', reason: 'nothing sent in a pickup');
      expect(pickup[11], '200,00');
    });

    test('its columns add up to the summary, voided ones aside', () {
      double sum(int column, bool Function(List<String>) where) => rows
          .skip(1)
          .where((row) => row[17] == 'No' && where(row))
          .fold(
            0,
            (total, row) => total + (double.tryParse(row[column].replaceAll('.', '').replaceAll(',', '.')) ?? 0),
          );
      bool all(List<String> _) => true;

      expect(sum(10, all), report.collected);
      expect(sum(9, all), report.fees);
      expect(sum(11, all), report.pickupsCollected);
      expect(sum(16, all), report.onTheHouse!.waivedFees);
    });

    test('UTF-8 keeps the accents', () {
      expect(utf8.decode(utf8.encode(csv)), contains('Plaza de la Revolución'));
    });
  });

  group('PDF', () {
    test('the detail is A4 landscape, a page per part', () async {
      final bytes = await buildMonthlyDetailPdf(report, detail, month: DateTime(2026, 10));
      final text = String.fromCharCodes(bytes);

      expect(text.startsWith('%PDF-'), isTrue);
      // Summary, deliveries, pickups and voided ones.
      expect(text.contains('/Count 4'), isTrue);
      expect(text.contains('/MediaBox[0 0 841'), isTrue, reason: 'landscape');
    });

    test('many remittances spread over several pages', () async {
      final many = MonthlyReportDetail.fromJson({
        ...detailJson,
        'remittances': [
          for (var i = 0; i < 120; i++)
            {...(detailJson['remittances'] as List).first as Map<String, dynamic>, 'code': 'OT-$i'},
        ],
      });
      final bytes = await buildMonthlyDetailPdf(report, many, month: DateTime(2026, 10));

      final pages = int.parse(RegExp(r'/Count (\d+)').firstMatch(String.fromCharCodes(bytes))!.group(1)!);
      expect(pages, greaterThan(4), reason: '120 deliveries do not fit in one page');
    });

    test('the summary is still one A4 page', () async {
      final bytes = await buildMonthlyReportPdf(report, month: DateTime(2026, 10));
      expect(String.fromCharCodes(bytes).contains('/Count 1'), isTrue);
    });

    test('text outside the PDF font becomes something it can draw', () {
      expect(pdfSafe('Cobrado − entregado — ok… ✓ 🙂 ñ'), 'Cobrado - entregado - ok... ? ? ñ');
    });
  });
}
