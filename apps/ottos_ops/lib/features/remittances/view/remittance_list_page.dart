import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../../../widgets/pagination_bar.dart';
import '../bloc/remittance_list_bloc.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/refresh_on_return.dart';

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
      // Back from registering, voiding or changing one: reload the page shown.
      child: Builder(
        builder: (context) => RefreshOnReturn(
          onReturn: () {
            final bloc = context.read<RemittanceListBloc>();
            bloc.add(RemittanceListPageRequested(bloc.state.result?.page ?? 0));
          },
          child: const _RemittanceListView(),
        ),
      ),
    );
  }
}

class _RemittanceListView extends StatelessWidget {
  const _RemittanceListView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: OpsTexts.remittances,
            actions: [
              if (context.canDo(Permissions.remittancesHistorical)) ...[
                TextButton.icon(
                  onPressed: () => context.go(Routes.historicalRemittance),
                  icon: const Icon(Icons.history_edu_outlined),
                  label: const Text(OpsTexts.historicalAction),
                ),
              ],
              if (context.canDo(Permissions.remittancesCreate))
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
                      message: state.error ?? CoreTexts.networkError,
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
                            ? EmptyView(
                                message: state.filter.beneficiaryQuery != null
                                    ? OpsTexts.noRemittancesSearch
                                    : OpsTexts.noRemittances,
                              )
                            : _RemittanceTable(items: result.items),
                      ),
                      const Divider(height: 1),
                      PaginationBar(
                        result: result,
                        onPage: (page) => context.read<RemittanceListBloc>().add(RemittanceListPageRequested(page)),
                      ),
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
        final compact = isCompact(context);
        final filters = [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              // Rebuilt with the type too: it names the final status.
              key: ValueKey('status-${filter.status}-${filter.type}'),
              initialValue: filter.status,
              isExpanded: true,
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
              isExpanded: true,
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
            label: const Text(OpsTexts.onlyToReview),
            selected: filter.review == true,
            onSelected: (selected) => change(filter.copyWith(review: selected ? true : null)),
          ),
          FilterChip(
            label: const Text(OpsTexts.onlyIncidents),
            selected: filter.incident == true,
            onSelected: (selected) => change(filter.copyWith(incident: selected ? true : null)),
          ),
          FilterChip(
            label: const Text(OpsTexts.onlyVoided),
            selected: filter.voided == true,
            onSelected: (selected) => change(filter.copyWith(voided: selected ? true : null)),
          ),
          FilterChip(
            avatar: const Icon(Icons.home_outlined, size: 18, color: OttosColors.onTheHouse),
            label: const Text(OpsTexts.onlyOnTheHouse),
            selected: filter.onTheHouse == true,
            onSelected: (selected) => change(filter.copyWith(onTheHouse: selected ? true : null)),
          ),
          if (!filter.isEmpty)
            TextButton.icon(
              onPressed: () => change(const RemittanceFilter()),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text(OpsTexts.clearFilters),
            ),
        ];
        if (!compact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(width: 320, child: _BeneficiarySearchField()),
              ...filters,
            ],
          );
        }
        // On a phone the filters fold away, so the list keeps most of the screen.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BeneficiarySearchField(),
            ExpansionTile(
              key: ValueKey('filters-${filter.isEmpty}'),
              title: Text(filter.isEmpty ? OpsTexts.filters : OpsTexts.filtersOn),
              initiallyExpanded: !filter.isEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              expandedAlignment: Alignment.centerLeft,
              children: [
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: filters),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Searches the list by the beneficiary's name or phone. The text lives in the
/// bloc and the API call only, never in the panel's URL.
class _BeneficiarySearchField extends StatefulWidget {
  const _BeneficiarySearchField();

  @override
  State<_BeneficiarySearchField> createState() => _BeneficiarySearchFieldState();
}

class _BeneficiarySearchFieldState extends State<_BeneficiarySearchField> {
  late final _controller = TextEditingController(text: context.read<RemittanceListBloc>().state.typed);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RemittanceListBloc, RemittanceListState>(
      // The bloc empties the text when the filters are removed.
      listenWhen: (previous, current) => previous.typed != current.typed,
      listener: (context, state) {
        if (_controller.text != state.typed) _controller.text = state.typed;
      },
      buildWhen: (previous, current) => previous.searchTooShort != current.searchTooShort,
      builder: (context, state) => TextField(
        controller: _controller,
        maxLength: 100,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        textInputAction: TextInputAction.search,
        onChanged: (text) => context.read<RemittanceListBloc>().add(RemittanceListSearchTyped(text)),
        decoration: InputDecoration(
          labelText: OpsTexts.searchByBeneficiary,
          helperText: state.searchTooShort ? OpsTexts.searchTooShort : null,
          isDense: true,
          prefixIcon: const Icon(Icons.search),
        ),
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
                title: RemittanceTitle(name: remittance.beneficiaryName, code: remittance.code),
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
                  DataColumn(label: Text(OpsTexts.beneficiary)),
                  DataColumn(label: Text(OpsTexts.type)),
                  DataColumn(label: Text(OpsTexts.status)),
                  DataColumn(label: Text(OpsTexts.customer)),
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
                        DataCell(
                          RemittanceTitle(
                            name: remittance.beneficiaryName,
                            code: remittance.code,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(remittance.isPickup ? CoreTexts.pickup : CoreTexts.delivery)),
                        DataCell(_StatusCell(remittance: remittance)),
                        DataCell(Text(remittance.customerName ?? '')),
                        DataCell(Text(remittance.municipalityName ?? '')),
                        DataCell(Text(Formatters.money(remittance.amount, remittance.sourceCurrency))),
                        DataCell(Text(Formatters.date(remittance.expectedDate))),
                        DataCell(
                          Text(
                            remittance.completedFromBusiness
                                ? OpsTexts.byBusiness
                                : remittance.courierName ?? OpsTexts.noCourier,
                          ),
                        ),
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
        if (remittance.onTheHouse) ...[const SizedBox(width: 6), const OnTheHouseBadge()],
        if (remittance.review case final review?) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: '${CoreTexts.toReview}: ${CoreTexts.reviewReason(review.reason)}',
            child: const Icon(Icons.flag_outlined, color: OttosColors.warning, size: 20),
          ),
        ],
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
