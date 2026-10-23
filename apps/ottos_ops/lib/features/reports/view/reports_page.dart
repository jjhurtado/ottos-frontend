import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:printing/printing.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../../../widgets/page_header.dart';

/// The monthly summary of sales and every remittance of the month, exportable
/// as PDF (summary or detail) and CSV (`reports:read`).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ReportRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ReportsCubit(reports: repository)..load()),
        BlocProvider(
          create: (context) =>
              ReportRemittancesCubit(reports: repository, month: context.read<ReportsCubit>().state.month)..load(),
        ),
      ],
      child: BlocListener<ReportsCubit, ReportsState>(
        listenWhen: (previous, current) => previous.month != current.month,
        listener: (context, state) => context.read<ReportRemittancesCubit>().load(state.month),
        child: BlocBuilder<ReportsCubit, ReportsState>(
          builder: (context, state) {
            final cubit = context.read<ReportsCubit>();
            final report = state.report;
            final canOpen = context.canDo(Permissions.remittancesRead);
            return ListView(
              padding: pagePadding(context),
              children: [
                _Header(state: state),
                const SizedBox(height: 4),
                if (report != null)
                  Text(
                    OpsTexts.reportPeriod(
                      Formatters.date(report.from),
                      Formatters.date(report.to),
                      report.businessCurrency,
                    ),
                  ),
                const SizedBox(height: 16),
                switch (state.status) {
                  ReportsStatus.loading => const SizedBox(height: 240, child: LoadingView()),
                  ReportsStatus.failure => SizedBox(
                    height: 240,
                    child: ErrorView(message: state.error!, onRetry: cubit.load),
                  ),
                  ReportsStatus.success when report!.remittances == 0 => const SizedBox(
                    height: 240,
                    child: EmptyView(message: OpsTexts.noSales),
                  ),
                  ReportsStatus.success => _ReportView(report: report!),
                },
                const SizedBox(height: 16),
                ReportRemittancesSection(
                  compact: isCompact(context),
                  onOpen: canOpen ? (row) => context.go(Routes.remittance(row.id)) : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportsCubit>();
    final detailState = context.watch<ReportRemittancesCubit>().state;
    final report = state.report;
    final detail = detailState.status == ReportDetailStatus.success && detailState.month == state.month
        ? detailState.detail
        : null;
    final hasSales = report != null && report.remittances > 0;
    final hasRows = detail != null && detail.lines > 0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(OpsTexts.monthlyReport, style: Theme.of(context).textTheme.headlineMedium),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonthSwitcher(month: state.month, isLatest: state.isCurrentMonth, onMove: cubit.moveMonth),
            ReportExportButton(
              onSummaryPdf: hasSales
                  ? () => _export(
                      context,
                      () async => Printing.sharePdf(
                        bytes: await buildMonthlyReportPdf(report, month: state.month),
                        filename: ReportTexts.summaryFileName(report.month),
                      ),
                    )
                  : null,
              onDetailPdf: report != null && hasRows
                  ? () => _export(
                      context,
                      () async => Printing.sharePdf(
                        bytes: await buildMonthlyDetailPdf(report, detail, month: state.month),
                        filename: ReportTexts.detailFileName(detail.month),
                      ),
                    )
                  : null,
              onCsv: hasRows
                  ? () => _export(
                      context,
                      () => FilePicker.saveFile(
                        fileName: ReportTexts.csvFileName(detail.month),
                        bytes: utf8.encode(ReportCsv.encode(detail)),
                        mimeType: 'text/csv',
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  /// On the web the file downloads; a failure says so instead of failing quietly.
  static Future<void> _export(BuildContext context, Future<Object?> Function() save) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await save();
    } on Exception {
      messenger.showSnackBar(const SnackBar(content: Text(ReportTexts.exportFailed)));
    }
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    String usd(double amount) => Formatters.money(amount, report.businessCurrency);
    final delivered = report.delivered.map((money) => Formatters.money(money.amount, money.currency)).join(' · ');
    final compact = isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Total(
              label: OpsTexts.reportRemittances,
              value: '${report.remittances}',
              help: OpsTexts.deliveriesAndPickups(report.deliveries, report.pickups),
            ),
            _Total(label: OpsTexts.totalCollected, value: usd(report.collected), help: OpsTexts.totalCollectedHelp),
            _Total(label: OpsTexts.totalDelivered, value: usd(report.deliveredCurrency), help: delivered),
            _Total(
              label: OpsTexts.difference,
              value: usd(report.difference),
              help: OpsTexts.differenceHelp,
              dark: true,
            ),
            _Total(
              label: OpsTexts.pickupsCollected,
              value: usd(report.pickupsCollected),
              help: OpsTexts.pickupsHelp(report.pickups, usd(report.pickupsFees)),
            ),
            _Total(
              label: OpsTexts.earnings,
              value: usd(report.fees),
              help: OpsTexts.earningsHelp(
                usd(report.deliveryFees),
                usd(report.pickupsFees),
                usd(report.roundingMargin),
              ),
              highlight: true,
            ),
            // Only with a backend that sends it; it always does since its V3.
            if (report.onTheHouse case final onTheHouse?)
              _Total(
                label: OpsTexts.onTheHouseReport,
                value: usd(onTheHouse.waivedFees),
                help: OpsTexts.onTheHouseHelp(onTheHouse.remittances, usd(onTheHouse.amount)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: OpsTexts.byCurrency,
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in report.byCurrency)
                      _Lines(
                        title: line.currency,
                        lines: [
                          (OpsTexts.reportRemittances, '${line.remittances}'),
                          (OpsTexts.sent, usd(line.sent)),
                          (OpsTexts.fees, usd(line.fees)),
                          (OpsTexts.collected, usd(line.collected)),
                          (OpsTexts.delivered, Formatters.money(line.delivered, line.currency)),
                          (OpsTexts.deliveredIn(report.businessCurrency), usd(line.deliveredCurrency)),
                        ],
                      ),
                    _Lines(
                      title: OpsTexts.totalRow,
                      lines: [
                        (OpsTexts.reportRemittances, '${report.deliveries}'),
                        (OpsTexts.sent, usd(report.byCurrency.fold(0, (sum, line) => sum + line.sent))),
                        (OpsTexts.fees, usd(report.deliveryFees)),
                        (OpsTexts.collected, usd(report.collected)),
                        (OpsTexts.deliveredIn(report.businessCurrency), usd(report.deliveredCurrency)),
                      ],
                    ),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Moneda')),
                      const DataColumn(label: Text(OpsTexts.reportRemittances), numeric: true),
                      const DataColumn(label: Text(OpsTexts.sent), numeric: true),
                      const DataColumn(label: Text(OpsTexts.fees), numeric: true),
                      const DataColumn(label: Text(OpsTexts.collected), numeric: true),
                      const DataColumn(label: Text(OpsTexts.delivered), numeric: true),
                      DataColumn(label: Text(OpsTexts.deliveredIn(report.businessCurrency)), numeric: true),
                    ],
                    rows: [
                      for (final line in report.byCurrency)
                        DataRow(
                          cells: [
                            DataCell(Text(line.currency)),
                            DataCell(Text('${line.remittances}')),
                            DataCell(Text(usd(line.sent))),
                            DataCell(Text(usd(line.fees))),
                            DataCell(Text(usd(line.collected))),
                            DataCell(Text(Formatters.money(line.delivered, line.currency))),
                            DataCell(Text(usd(line.deliveredCurrency))),
                          ],
                        ),
                      DataRow(
                        cells: [
                          const DataCell(Text(OpsTexts.totalRow, style: TextStyle(fontWeight: FontWeight.w700))),
                          // Only deliveries go by currency: their count and fees.
                          DataCell(Text('${report.deliveries}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(
                            Text(
                              usd(report.byCurrency.fold(0, (sum, line) => sum + line.sent)),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(Text(usd(report.deliveryFees), style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(usd(report.collected), style: const TextStyle(fontWeight: FontWeight.w700))),
                          const DataCell(Text('—')),
                          DataCell(
                            Text(usd(report.deliveredCurrency), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: compact ? double.infinity : 560,
              child: _Section(
                title: OpsTexts.byType,
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in report.byType)
                            _Lines(
                              title: line.type == RemittanceType.pickup ? 'Recogidas' : 'Entregas',
                              color: line.type.color,
                              lines: [
                                (OpsTexts.reportRemittances, '${line.remittances}'),
                                (OpsTexts.collectedOrPicked, usd(line.collected)),
                                (OpsTexts.fees, usd(line.fees)),
                              ],
                            ),
                        ],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text(OpsTexts.type)),
                            DataColumn(label: Text(OpsTexts.reportRemittances), numeric: true),
                            DataColumn(label: Text(OpsTexts.collectedOrPicked), numeric: true),
                            DataColumn(label: Text(OpsTexts.fees), numeric: true),
                          ],
                          rows: [
                            for (final line in report.byType)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      line.type == RemittanceType.pickup ? 'Recogidas' : 'Entregas',
                                      style: TextStyle(color: line.type.color, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  DataCell(Text('${line.remittances}')),
                                  DataCell(Text(usd(line.collected))),
                                  DataCell(Text(usd(line.fees))),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 420,
              child: _Section(
                title: OpsTexts.monthEndStatus,
                child: Column(
                  children: [
                    InfoRow(
                      label: OpsTexts.completedLabel,
                      value: '${report.completed}',
                      labelWidth: compact ? 200 : 260,
                    ),
                    InfoRow(label: OpsTexts.openLabel, value: '${report.open}', labelWidth: compact ? 200 : 260),
                    InfoRow(
                      label: OpsTexts.withIncidentLabel,
                      value: '${report.withIncident}',
                      labelWidth: compact ? 200 : 260,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.help,
    this.dark = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String help;
  final bool dark;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final accent = highlight ? OttosColors.success : (dark ? OttosColors.cream : null);
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? OttosColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: dark
            ? null
            : Border.all(color: highlight ? OttosColors.success : const Color(0xFFDFE1EA), width: highlight ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: accent, fontWeight: highlight ? FontWeight.w500 : null),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : (highlight ? OttosColors.success : null),
            ),
          ),
          const SizedBox(height: 6),
          Text(help, style: textTheme.bodySmall?.copyWith(color: dark ? OttosColors.cream : null)),
        ],
      ),
    );
  }
}

/// A table row on a phone: its name, then one line per column.
class _Lines extends StatelessWidget {
  const _Lines({required this.title, required this.lines, this.color});

  final String title;
  final List<(String, String)> lines;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          for (final (label, value) in lines) InfoRow(label: label, value: value, labelWidth: 170),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
