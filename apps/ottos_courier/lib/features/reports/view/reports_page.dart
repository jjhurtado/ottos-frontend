import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';

/// Sales › Reportes: every remittance of the month without personal data,
/// with filters, and «Exportar» to share the summary or the detail as PDF or
/// the remittances as CSV through the phone's share sheet (`reports:read`).
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
        child: Builder(
          builder: (context) => RefreshIndicator(
            onRefresh: () =>
                Future.wait([context.read<ReportsCubit>().load(), context.read<ReportRemittancesCubit>().load()]),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: [
                const _Header(),
                const SizedBox(height: 8),
                ReportRemittancesSection(compact: true, onOpen: (row) => context.push(Routes.remittance(row.id))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReportsCubit>().state;
    final detailState = context.watch<ReportRemittancesCubit>().state;
    final report = state.report;
    final detail = detailState.status == ReportDetailStatus.success && detailState.month == state.month
        ? detailState.detail
        : null;
    final hasSales = report != null && report.remittances > 0;
    final hasRows = detail != null && detail.lines > 0;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        MonthSwitcher(
          month: state.month,
          isLatest: state.isCurrentMonth,
          onMove: context.read<ReportsCubit>().moveMonth,
        ),
        ReportExportButton(
          onSummaryPdf: hasSales
              ? () => _share(
                  context,
                  () => buildMonthlyReportPdf(report, month: state.month),
                  ReportTexts.summaryFileName(report.month),
                  'application/pdf',
                )
              : null,
          onDetailPdf: report != null && hasRows
              ? () => _share(
                  context,
                  () => buildMonthlyDetailPdf(report, detail, month: state.month),
                  ReportTexts.detailFileName(detail.month),
                  'application/pdf',
                )
              : null,
          onCsv: hasRows
              ? () => _share(
                  context,
                  () async => Uint8List.fromList(utf8.encode(ReportCsv.encode(detail))),
                  ReportTexts.csvFileName(detail.month),
                  'text/csv',
                )
              : null,
        ),
      ],
    );
  }

  /// The phone's share sheet (WhatsApp, Drive, Files…) with the file made here.
  static Future<void> _share(
    BuildContext context,
    Future<Uint8List> Function() build,
    String fileName,
    String mimeType,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await build();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
          fileNameOverrides: [fileName],
        ),
      );
    } on Exception {
      messenger.showSnackBar(const SnackBar(content: Text(ReportTexts.exportFailed)));
    }
  }
}
