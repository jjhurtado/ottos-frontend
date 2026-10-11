import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:printing/printing.dart';

import '../../../app/ops_texts.dart';
import '../cubit/reports_cubit.dart';
import 'monthly_report_pdf.dart';

/// The monthly summary of sales, exportable as a PDF (`reports:read`).
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportsCubit(reports: context.read<ReportRepository>())..load(),
      child: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          final cubit = context.read<ReportsCubit>();
          final report = state.report;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _Header(state: state),
              const SizedBox(height: 4),
              if (report != null) Text(OpsTexts.reportPeriod(Formatters.date(report.from), Formatters.date(report.to))),
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
            ],
          );
        },
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
    final report = state.report;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(OpsTexts.monthlyReport, style: Theme.of(context).textTheme.headlineMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: OpsTexts.previousMonth,
              onPressed: () => cubit.moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            SizedBox(
              width: 160,
              child: Text(
                monthTitle(state.month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: OpsTexts.nextMonth,
              onPressed: state.isCurrentMonth ? null : () => cubit.moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: report == null || report.remittances == 0
                  ? null
                  : () async {
                      final bytes = await buildMonthlyReportPdf(report, month: state.month);
                      // On the web this downloads the file.
                      await Printing.sharePdf(bytes: bytes, filename: OpsTexts.reportFileName(report.month));
                    },
              icon: const Icon(Icons.download_outlined),
              label: const Text(OpsTexts.exportPdf),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    String usd(double amount) => Formatters.money(amount, 'USD');
    final delivered = report.delivered.map((money) => Formatters.money(money.amount, money.currency)).join(' · ');
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
            _Total(label: OpsTexts.totalDelivered, value: usd(report.deliveredUsd), help: delivered),
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
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: OpsTexts.byCurrency,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Moneda')),
                DataColumn(label: Text(OpsTexts.reportRemittances), numeric: true),
                DataColumn(label: Text(OpsTexts.sent), numeric: true),
                DataColumn(label: Text(OpsTexts.fees), numeric: true),
                DataColumn(label: Text(OpsTexts.collected), numeric: true),
                DataColumn(label: Text(OpsTexts.delivered), numeric: true),
                DataColumn(label: Text(OpsTexts.deliveredUsd), numeric: true),
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
                      DataCell(Text(usd(line.deliveredUsd))),
                    ],
                  ),
                DataRow(
                  cells: [
                    const DataCell(Text(OpsTexts.totalRow, style: TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text('${report.remittances}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(
                      Text(
                        usd(report.byCurrency.fold(0, (sum, line) => sum + line.sent)),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataCell(Text(usd(report.fees), style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(usd(report.collected), style: const TextStyle(fontWeight: FontWeight.w700))),
                    const DataCell(Text('—')),
                    DataCell(Text(usd(report.deliveredUsd), style: const TextStyle(fontWeight: FontWeight.w700))),
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
              width: 560,
              child: _Section(
                title: OpsTexts.byType,
                child: SingleChildScrollView(
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
              width: 420,
              child: _Section(
                title: OpsTexts.monthEndStatus,
                child: Column(
                  children: [
                    InfoRow(label: OpsTexts.completedLabel, value: '${report.completed}', labelWidth: 260),
                    InfoRow(label: OpsTexts.openLabel, value: '${report.open}', labelWidth: 260),
                    InfoRow(label: OpsTexts.withIncidentLabel, value: '${report.withIncident}', labelWidth: 260),
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
