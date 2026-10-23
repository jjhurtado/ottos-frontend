import 'package:flutter/material.dart';

import '../theme/ottos_colors.dart';
import 'report_texts.dart';

/// A card with a title, for the sections of the reports and statistics.
class ReportSection extends StatelessWidget {
  const ReportSection({super.key, required this.title, this.help, required this.child, this.padding = 20});

  final String title;
  final String? help;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (help != null) Text(help!, style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A figure in a box: its name, the value and a line of help.
class ReportFigure extends StatelessWidget {
  const ReportFigure({
    super.key,
    required this.label,
    required this.value,
    this.help,
    this.highlight = false,
    this.trailing,
  });

  final String label;
  final String value;
  final String? help;
  final bool highlight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? OttosColors.success : const Color(0xFFD9DCE3), width: highlight ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(color: highlight ? OttosColors.success : null)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlight ? OttosColors.success : null,
                ),
              ),
              ?trailing,
            ],
          ),
          if (help != null) ...[const SizedBox(height: 4), Text(help!, style: textTheme.bodySmall)],
        ],
      ),
    );
  }
}

/// What a section shows when there is nothing to draw, or the backend does
/// not have it yet.
class ReportNotice extends StatelessWidget {
  const ReportNotice({super.key, required this.title, this.message, this.icon = Icons.bar_chart_outlined});

  /// The friendly notice of a backend without the reports detail or the statistics.
  const ReportNotice.unavailable({super.key})
    : title = ReportTexts.notAvailableYet,
      message = null,
      icon = Icons.update_outlined;

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9A9DA8)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF6B6F7B)),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: textTheme.titleSmall),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, textAlign: TextAlign.center, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// «Exportar» and its menu: the month's summary or detail as PDF, or the
/// remittances as CSV. A null action is shown disabled.
class ReportExportButton extends StatelessWidget {
  const ReportExportButton({super.key, this.onSummaryPdf, this.onDetailPdf, this.onCsv});

  final VoidCallback? onSummaryPdf;
  final VoidCallback? onDetailPdf;
  final VoidCallback? onCsv;

  @override
  Widget build(BuildContext context) {
    final enabled = onSummaryPdf != null || onDetailPdf != null || onCsv != null;
    Widget item(String title, String help, IconData icon, VoidCallback? onPressed) => MenuItemButton(
      onPressed: onPressed,
      leadingIcon: Icon(icon, color: onPressed == null ? null : OttosColors.tealDark),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(help, style: Theme.of(context).textTheme.bodySmall, softWrap: true),
            ],
          ),
        ),
      ),
    );
    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      builder: (context, controller, _) => FilledButton.icon(
        onPressed: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
        icon: const Icon(Icons.download_outlined),
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(ReportTexts.export), Icon(Icons.arrow_drop_down)],
        ),
      ),
      menuChildren: [
        item(ReportTexts.exportSummaryPdf, ReportTexts.exportSummaryPdfHelp, Icons.description_outlined, onSummaryPdf),
        item(ReportTexts.exportDetailPdf, ReportTexts.exportDetailPdfHelp, Icons.table_chart_outlined, onDetailPdf),
        item(ReportTexts.exportCsv, ReportTexts.exportCsvHelp, Icons.grid_on_outlined, onCsv),
      ],
    );
  }
}

/// ‹ Octubre de 2026 ›, never past [latest].
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onMove, required this.isLatest});

  final DateTime month;
  final ValueChanged<int> onMove;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: ReportTexts.previousMonth,
          onPressed: () => onMove(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 160,
          child: Text(
            ReportTexts.monthTitle(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: ReportTexts.nextMonth,
          onPressed: isLatest ? null : () => onMove(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
