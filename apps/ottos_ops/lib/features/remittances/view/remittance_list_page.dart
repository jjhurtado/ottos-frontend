import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../bloc/remittance_list_bloc.dart';

class RemittanceListPage extends StatelessWidget {
  const RemittanceListPage({super.key, this.initialFilter = const RemittanceFilter()});

  final RemittanceFilter initialFilter;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Rebuild the bloc when the query string changes (e.g. from home).
      key: ValueKey(initialFilter),
      create: (context) =>
          RemittanceListBloc(remittances: context.read<RemittanceRepository>(), initialFilter: initialFilter)
            ..add(const RemittanceListStarted()),
      child: const _RemittanceListView(),
    );
  }
}

class _RemittanceListView extends StatelessWidget {
  const _RemittanceListView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(OpsTexts.remittances, style: Theme.of(context).textTheme.headlineMedium)),
              if (context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.remittancesCreate)))
                FilledButton.icon(
                  onPressed: () => context.go(Routes.newRemittance),
                  icon: const Icon(Icons.add),
                  label: const Text(OpsTexts.newRemittance),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _FilterBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: BlocBuilder<RemittanceListBloc, RemittanceListState>(
                builder: (context, state) {
                  final result = state.result;
                  if (state.status == RemittanceListStatus.failure) {
                    return ErrorView(
                      message: state.error!,
                      onRetry: () =>
                          context.read<RemittanceListBloc>().add(RemittanceListPageRequested(result?.page ?? 0)),
                    );
                  }
                  if (result == null) return const LoadingView();
                  return Column(
                    children: [
                      if (state.status == RemittanceListStatus.loading) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: result.items.isEmpty
                            ? const EmptyView(message: OpsTexts.noRemittances)
                            : _RemittanceTable(items: result.items),
                      ),
                      const Divider(height: 1),
                      _Pagination(result: result),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RemittanceListBloc>();
    return BlocBuilder<RemittanceListBloc, RemittanceListState>(
      buildWhen: (previous, current) => previous.filter != current.filter || previous.statuses != current.statuses,
      builder: (context, state) {
        final filter = state.filter;
        void change(RemittanceFilter next) => bloc.add(RemittanceListFilterChanged(next));
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SizedBox(width: 260, child: _CodeSearchField()),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                // Rebuilt with the type too: it names the final status.
                key: ValueKey('status-${filter.status}-${filter.type}'),
                initialValue: filter.status,
                decoration: const InputDecoration(labelText: OpsTexts.status, isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text(OpsTexts.allStatuses)),
                  for (final status in state.statuses)
                    DropdownMenuItem(
                      value: status.code,
                      child: Text(CoreTexts.statusName(status.code, type: filter.type, fallback: status.name)),
                    ),
                ],
                onChanged: (status) => change(filter.copyWith(status: status)),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<RemittanceType?>(
                key: ValueKey('type-${filter.type}'),
                initialValue: filter.type,
                decoration: const InputDecoration(labelText: OpsTexts.type, isDense: true),
                items: const [
                  DropdownMenuItem(value: null, child: Text(OpsTexts.allTypes)),
                  DropdownMenuItem(value: RemittanceType.delivery, child: Text(CoreTexts.delivery)),
                  DropdownMenuItem(value: RemittanceType.pickup, child: Text(CoreTexts.pickup)),
                ],
                onChanged: (type) => change(filter.copyWith(type: type)),
              ),
            ),
            FilterChip(
              label: const Text(OpsTexts.onlyLate),
              selected: filter.late == true,
              onSelected: (selected) => change(filter.copyWith(late: selected ? true : null)),
            ),
            FilterChip(
              label: const Text(OpsTexts.onlyIncidents),
              selected: filter.incident == true,
              onSelected: (selected) => change(filter.copyWith(incident: selected ? true : null)),
            ),
            if (!filter.isEmpty)
              TextButton.icon(
                onPressed: () => change(const RemittanceFilter()),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text(OpsTexts.clearFilters),
              ),
          ],
        );
      },
    );
  }
}

/// Opens a remittance by its tracking code.
class _CodeSearchField extends StatefulWidget {
  const _CodeSearchField();

  @override
  State<_CodeSearchField> createState() => _CodeSearchFieldState();
}

class _CodeSearchFieldState extends State<_CodeSearchField> {
  final _controller = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _searching) return;
    setState(() => _searching = true);
    try {
      final remittance = await context.read<RemittanceRepository>().getByCode(code);
      if (mounted) context.go(Routes.remittance(remittance.id));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        labelText: OpsTexts.searchByCode,
        isDense: true,
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(icon: const Icon(Icons.search), onPressed: _search),
      ),
    );
  }
}

class _RemittanceTable extends StatelessWidget {
  const _RemittanceTable({required this.items});

  final List<Remittance> items;

  @override
  Widget build(BuildContext context) {
    void open(Remittance remittance) => context.go(Routes.remittance(remittance.id));
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final remittance = items[index];
              return ListTile(
                onTap: () => open(remittance),
                title: Text('${remittance.code} · ${remittance.beneficiaryName ?? ''}'),
                subtitle: Text('${remittance.municipalityName ?? ''} · ${Formatters.date(remittance.expectedDate)}'),
                trailing: _StatusCell(remittance: remittance),
              );
            },
          );
        }
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: OttosColors.navy),
                columns: const [
                  DataColumn(label: Text(OpsTexts.code)),
                  DataColumn(label: Text(OpsTexts.type)),
                  DataColumn(label: Text(OpsTexts.status)),
                  DataColumn(label: Text(OpsTexts.customer)),
                  DataColumn(label: Text(OpsTexts.beneficiary)),
                  DataColumn(label: Text(OpsTexts.municipality)),
                  DataColumn(label: Text(OpsTexts.amount), numeric: true),
                  DataColumn(label: Text(OpsTexts.expectedDate)),
                  DataColumn(label: Text(OpsTexts.courier)),
                ],
                rows: [
                  for (final remittance in items)
                    DataRow(
                      onSelectChanged: (_) => open(remittance),
                      cells: [
                        DataCell(Text(remittance.code, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(remittance.isPickup ? CoreTexts.pickup : CoreTexts.delivery)),
                        DataCell(_StatusCell(remittance: remittance)),
                        DataCell(Text(remittance.customerName ?? '')),
                        DataCell(Text(remittance.beneficiaryName ?? '')),
                        DataCell(Text(remittance.municipalityName ?? '')),
                        DataCell(Text(Formatters.money(remittance.amount, remittance.sourceCurrency))),
                        DataCell(Text(Formatters.date(remittance.expectedDate))),
                        DataCell(Text(remittance.courierName ?? OpsTexts.noCourier)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.result});

  final PageResult<Remittance> result;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RemittanceListBloc>();
    final first = result.totalItems == 0 ? 0 : result.page * result.size + 1;
    final last = result.page * result.size + result.items.length;
    final hasPrevious = result.page > 0;
    final hasNext = result.page + 1 < result.totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(OpsTexts.pageOf(first, last, result.totalItems)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: OpsTexts.previousPage,
            onPressed: hasPrevious ? () => bloc.add(RemittanceListPageRequested(result.page - 1)) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: OpsTexts.nextPage,
            onPressed: hasNext ? () => bloc.add(RemittanceListPageRequested(result.page + 1)) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Status chip plus a warning mark when a courier reported an incident.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.remittance});

  final Remittance remittance;

  @override
  Widget build(BuildContext context) {
    final incident = remittance.incident;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RemittanceStatusChip(remittance: remittance),
        if (incident != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: '${CoreTexts.incident}: ${CoreTexts.incidentReason(incident.reason)}',
            child: const Icon(Icons.error_outline, color: OttosColors.danger, size: 20),
          ),
        ],
      ],
    );
  }
}
