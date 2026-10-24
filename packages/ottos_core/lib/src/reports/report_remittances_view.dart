import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/remittance.dart';
import '../models/report_detail.dart';
import '../theme/ottos_colors.dart';
import '../utils/cuba_time.dart';
import '../utils/formatters.dart';
import '../widgets/async_view.dart';
import '../widgets/remittance_type_badge.dart';
import 'report_pdf.dart';
import 'report_remittances_cubit.dart';
import 'report_texts.dart';
import 'report_totals.dart';
import 'report_widgets.dart';

/// «Remesas del mes»: every remittance of the month without personal data,
/// with filters, the totals of what is shown and pages of 50. A table on wide
/// screens, cards on a phone ([compact]). Reads [ReportRemittancesCubit].
class ReportRemittancesSection extends StatelessWidget {
  const ReportRemittancesSection({super.key, required this.compact, this.onOpen});

  final bool compact;

  /// Opens a remittance's detail; null if the user may not see it.
  final ValueChanged<ReportRemittance>? onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportRemittancesCubit, ReportRemittancesState>(
      builder: (context, state) {
        final cubit = context.read<ReportRemittancesCubit>();
        final Widget body = switch (state.status) {
          ReportDetailStatus.loading => const SizedBox(height: 160, child: LoadingView()),
          ReportDetailStatus.unavailable => const ReportNotice.unavailable(),
          ReportDetailStatus.failure => SizedBox(
            height: 200,
            child: ErrorView(message: state.error ?? '', onRetry: cubit.load),
          ),
          ReportDetailStatus.success => _Content(state: state, compact: compact, onOpen: onOpen),
        };
        final title = Text(
          ReportTexts.monthRemittances,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 8), body],
          );
        }
        return ReportSection(
          title: ReportTexts.monthRemittances,
          help: ReportTexts.monthRemittancesHelp(ReportTexts.monthLower(state.month)),
          child: body,
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.compact, required this.onOpen});

  final ReportRemittancesState state;
  final bool compact;
  final ValueChanged<ReportRemittance>? onOpen;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportRemittancesCubit>();
    final rows = state.pageRows;
    final filtered = state.filtered;
    final first = filtered.isEmpty ? 0 : state.page * ReportRemittancesState.pageSize + 1;
    final last = state.page * ReportRemittancesState.pageSize + rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Filters(state: state, compact: compact),
        const SizedBox(height: 12),
        compact
            ? _TotalsTiles(totals: state.totals, currency: state.detail!.businessCurrency)
            : _TotalsStrip(totals: state.totals, currency: state.detail!.businessCurrency),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const SizedBox(height: 120, child: EmptyView(message: ReportTexts.noRemittancesFound))
        else if (compact)
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, row) in rows.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  _RemittanceCard(row: row, currency: state.detail!.businessCurrency, onOpen: onOpen),
                ],
              ],
            ),
          )
        else
          _Table(rows: rows, newestFirst: state.filter.newestFirst, onOpen: onOpen),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(ReportTexts.pageOf(first, last, filtered.length)),
            IconButton(
              tooltip: ReportTexts.previousPage,
              onPressed: state.page > 0 ? () => cubit.page(state.page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: ReportTexts.nextPage,
              onPressed: state.page + 1 < state.pages ? () => cubit.page(state.page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!compact) Text(ReportTexts.tableHelp, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters({required this.state, required this.compact});

  final ReportRemittancesState state;
  final bool compact;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late final _code = TextEditingController(text: widget.state.filter.code);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportRemittancesCubit>();
    final filter = widget.state.filter;
    final couriers = widget.state.couriers;
    final search = SizedBox(
      width: widget.compact ? double.infinity : 200,
      child: TextField(
        controller: _code,
        decoration: const InputDecoration(
          labelText: ReportTexts.searchCode,
          hintText: 'OT-…',
          prefixIcon: Icon(Icons.search),
          isDense: true,
        ),
        onChanged: (value) => cubit.filter(filter.copyWith(code: value)),
      ),
    );
    Widget dropdown<T>(String label, T value, List<(T, String)> options, ValueChanged<T> onChanged, double width) =>
        SizedBox(
          width: widget.compact ? double.infinity : width,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [
              for (final (option, text) in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(text, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => onChanged(value as T),
          ),
        );
    final others = [
      dropdown<String?>(
        ReportTexts.type,
        filter.type,
        [
          (null, ReportTexts.all),
          (RemittanceType.delivery.code, ReportTexts.deliveries),
          (RemittanceType.pickup.code, ReportTexts.pickups),
        ],
        (value) => cubit.filter(filter.copyWith(type: () => value)),
        150,
      ),
      dropdown<ReportStatusFilter>(
        ReportTexts.status,
        filter.status,
        const [
          (ReportStatusFilter.all, ReportTexts.all),
          (ReportStatusFilter.paid, ReportTexts.statusPaid),
          (ReportStatusFilter.assigned, ReportTexts.statusAssigned),
          (ReportStatusFilter.completed, ReportTexts.statusCompleted),
          (ReportStatusFilter.incident, ReportTexts.statusIncident),
        ],
        (value) => cubit.filter(filter.copyWith(status: value)),
        170,
      ),
      dropdown<String?>(
        ReportTexts.courier,
        couriers.contains(filter.courier) ? filter.courier : null,
        [
          (null, ReportTexts.all),
          for (final name in couriers) (name, name == ReportFilter.withoutCourier ? ReportTexts.withoutCourier : name),
        ],
        (value) => cubit.filter(filter.copyWith(courier: () => value)),
        180,
      ),
      _Check(
        label: ReportTexts.onlyOnTheHouse,
        value: filter.onlyOnTheHouse,
        onChanged: (value) => cubit.filter(filter.copyWith(onlyOnTheHouse: value)),
      ),
      _Check(
        label: ReportTexts.showVoided,
        value: filter.showVoided,
        onChanged: (value) => cubit.filter(filter.copyWith(showVoided: value)),
      ),
    ];
    if (!widget.compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [search, ...others],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        ExpansionTile(
          title: Text(filter.isFiltered ? ReportTexts.filtersActive : ReportTexts.filters),
          subtitle: const Text(ReportTexts.filtersHelp),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final (index, child) in others.indexed) ...[if (index > 0) const SizedBox(height: 8), child],
          ],
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (value) => onChanged(value ?? false)),
          Text(label),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.totals, required this.currency});

  final ReportTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    String money(double value) => Formatters.money(value, currency);
    Widget item(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFEEF7F9), borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        spacing: 20,
        runSpacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${totals.remittances}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: totals.remittances == 1 ? ' remesa' : ' remesas'),
              ],
            ),
          ),
          item(ReportTexts.sent, money(totals.sent)),
          item(ReportTexts.collected, money(totals.collected)),
          item(ReportTexts.picked, money(totals.pickupCollected)),
          item(ReportTexts.fees, money(totals.fees)),
          Text(ReportTexts.filteredTotalsNote(totals.voided), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// How the status reads and its color: voided grey, incident red, completed
/// green, assigned amber, paid teal.
(String, Color) _status(ReportRemittance row) => switch (row) {
  ReportRemittance(isVoided: true) => (ReportTexts.voided, const Color(0xFF44474E)),
  ReportRemittance(withIncident: true) => (
    '${reportStatusName(row)} · ${ReportTexts.statusIncident.toLowerCase()}',
    OttosColors.danger,
  ),
  ReportRemittance(isCompleted: true) => (reportStatusName(row), OttosColors.success),
  ReportRemittance(status: 'ASSIGNED') => (reportStatusName(row), OttosColors.warning),
  _ => (reportStatusName(row), OttosColors.tealDark),
};

String _courier(ReportRemittance row) =>
    row.completedFromBusiness ? 'El negocio' : (row.courierName ?? ReportTexts.withoutCourier);

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.row});

  final ReportRemittance row;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status(row);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.newestFirst, required this.onOpen});

  final List<ReportRemittance> rows;
  final bool newestFirst;
  final ValueChanged<ReportRemittance>? onOpen;

  static const _widths = <double>[120, 96, 96, 170, 120, 150, 96, 88, 96, 136, 64];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportRemittancesCubit>();
    final headerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
    Widget cell(int column, Widget child, {bool numeric = false}) => SizedBox(
      width: _widths[column],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(alignment: numeric ? Alignment.centerRight : Alignment.centerLeft, child: child),
      ),
    );
    Widget text(String value, {TextStyle? style}) =>
        Text(value, overflow: TextOverflow.ellipsis, maxLines: 1, style: style);
    final total = _widths.fold<double>(0, (sum, width) => sum + width) + 24;
    final header = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFF8F9FB),
      child: Row(
        children: [
          cell(0, text(ReportTexts.code, style: headerStyle)),
          cell(1, text(ReportTexts.type, style: headerStyle)),
          cell(
            2,
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => cubit.filter(cubit.state.filter.copyWith(newestFirst: !newestFirst)),
              child: Tooltip(
                message: newestFirst ? ReportTexts.sortNewest : ReportTexts.sortOldest,
                child: Text(
                  '${ReportTexts.registered} ${newestFirst ? '↓' : '↑'}',
                  style: headerStyle?.copyWith(fontWeight: FontWeight.w700, color: OttosColors.navy),
                ),
              ),
            ),
          ),
          cell(3, text(ReportTexts.municipality, style: headerStyle)),
          cell(4, text(ReportTexts.courier, style: headerStyle)),
          cell(5, text(ReportTexts.status, style: headerStyle)),
          cell(6, text(ReportTexts.amount, style: headerStyle), numeric: true),
          cell(7, text(ReportTexts.fee, style: headerStyle), numeric: true),
          cell(8, text(ReportTexts.collected, style: headerStyle), numeric: true),
          cell(9, text(ReportTexts.toDeliver, style: headerStyle), numeric: true),
          cell(10, text(ReportTexts.rate, style: headerStyle), numeric: true),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9DCE3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: total,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const Divider(height: 1), for (final row in rows) _row(context, row, cell, text)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ReportRemittance row,
    Widget Function(int, Widget, {bool numeric}) cell,
    Widget Function(String, {TextStyle? style}) text,
  ) {
    final voided = row.isVoided;
    final grey = voided ? const TextStyle(color: Color(0xFF44474E)) : null;
    final money = voided
        ? const TextStyle(color: Color(0xFF44474E), decoration: TextDecoration.lineThrough)
        : const TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    final open = onOpen;
    return Container(
      decoration: BoxDecoration(
        color: voided ? const Color(0xFFF8F9FB) : null,
        border: const Border(bottom: BorderSide(color: Color(0xFFECEEF2))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                cell(
                  0,
                  open == null
                      ? text(row.code, style: const TextStyle(fontWeight: FontWeight.w500))
                      : InkWell(
                          onTap: () => open(row),
                          child: text(
                            row.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: OttosColors.tealDark,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                ),
                cell(
                  1,
                  text(
                    row.isPickup ? 'Recogida' : (row.onTheHouse ? 'Entrega · casa' : 'Entrega'),
                    style: TextStyle(color: row.type.color),
                  ),
                ),
                cell(2, text(CubaTime.shortDate(row.createdAt), style: grey)),
                cell(3, text(row.municipalityName ?? '—', style: grey)),
                cell(4, text(_courier(row), style: grey)),
                cell(5, _StatusChip(row: row)),
                cell(6, text(Formatters.money(row.amount, null), style: money), numeric: true),
                cell(7, text(Formatters.money(row.fee, null), style: money), numeric: true),
                cell(8, text(row.isPickup ? '—' : Formatters.money(row.collected, null), style: money), numeric: true),
                cell(
                  9,
                  text(row.isPickup ? '—' : Formatters.money(row.amountToDeliver, row.targetCurrency), style: money),
                  numeric: true,
                ),
                cell(10, text(ReportTexts.formatRate(row.rate), style: grey), numeric: true),
              ],
            ),
          ),
          if (row.voided case final voidedBy?)
            Padding(
              padding: const EdgeInsets.only(left: 126, bottom: 10, right: 12),
              child: Text(
                ReportTexts.voidedOn(CubaTime.shortDate(voidedBy.at), voidedBy.reason),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _RemittanceCard extends StatelessWidget {
  const _RemittanceCard({required this.row, required this.currency, required this.onOpen});

  final ReportRemittance row;
  final String currency;
  final ValueChanged<ReportRemittance>? onOpen;

  @override
  Widget build(BuildContext context) {
    final voided = row.isVoided;
    final textTheme = Theme.of(context).textTheme;
    final type = row.isPickup ? 'Recogida' : (row.onTheHouse ? 'Entrega por la casa' : 'Entrega');
    final (status, _) = _status(row);
    final details = [type, CubaTime.shortDate(row.createdAt), ?row.municipalityName, _courier(row), status].join(' · ');
    final open = onOpen;
    return InkWell(
      onTap: open == null ? null : () => open(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.code,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  Formatters.money(row.isPickup ? row.collected : row.total, currency),
                  style: textTheme.titleMedium?.copyWith(
                    decoration: voided ? TextDecoration.lineThrough : null,
                    color: voided ? const Color(0xFF44474E) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              details,
              style: textTheme.bodySmall?.copyWith(color: voided ? null : (row.isPickup ? row.type.color : null)),
            ),
            if (row.voided case final voidedBy?) ...[
              const SizedBox(height: 4),
              Text(ReportTexts.voidedOn(CubaTime.shortDate(voidedBy.at), voidedBy.reason), style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// The totals of what is shown on a phone: a tile per figure, two to a row,
/// each in its own tint, and the note under them.
class _TotalsTiles extends StatelessWidget {
  const _TotalsTiles({required this.totals, required this.currency});

  final ReportTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    String money(double value) => Formatters.money(value, currency);
    Widget tile(String label, String value, Color color, {bool valueFirst = false}) {
      final labelText = Text(label, style: textTheme.bodySmall?.copyWith(color: const Color(0xFF44474E)));
      final valueText = Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: OttosColors.navy),
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: valueFirst
              ? [valueText, const SizedBox(height: 2), labelText]
              : [labelText, const SizedBox(height: 2), valueText],
        ),
      );
    }

    Widget pair(Widget first, Widget second) => Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 8),
        Expanded(child: second),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9DCE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pair(
            tile(
              totals.remittances == 1 ? 'remesa' : 'remesas',
              '${totals.remittances}',
              const Color(0xFFF5F6FA),
              valueFirst: true,
            ),
            tile(ReportTexts.sent, money(totals.sent), const Color(0xFFEEF7F9)),
          ),
          const SizedBox(height: 8),
          pair(
            tile(ReportTexts.collected, money(totals.collected), const Color(0xFFE3F1E6)),
            tile(ReportTexts.picked, money(totals.pickupCollected), const Color(0xFFEDE6F8)),
          ),
          const SizedBox(height: 8),
          tile(ReportTexts.fees, money(totals.fees), const Color(0xFFF7EBD8)),
          const SizedBox(height: 6),
          Text(
            ReportTexts.filteredTotalsNote(totals.voided),
            style: textTheme.bodySmall?.copyWith(fontSize: 11, color: const Color(0xFF6B6F7B)),
          ),
        ],
      ),
    );
  }
}
