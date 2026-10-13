import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../cubit/audit_cubit.dart';

/// Who changed users and roles, and when (`audit:read`).
class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuditCubit(audit: context.read<AuditRepository>())..load(),
      child: BlocBuilder<AuditCubit, AuditState>(
        builder: (context, state) {
          final cubit = context.read<AuditCubit>();
          final result = state.result;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(OpsTexts.audit, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text(OpsTexts.auditSubtitle),
                const SizedBox(height: 16),
                _Filters(filter: state.filter),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: switch ((state.status, result)) {
                      (AuditStatus.failure, null) => ErrorView(message: state.error!, onRetry: cubit.load),
                      (_, null) => const LoadingView(),
                      (_, final page?) when page.items.isEmpty => const EmptyView(message: OpsTexts.noAuditEntries),
                      (_, final page?) => Column(
                        children: [
                          if (state.status == AuditStatus.loading) const LinearProgressIndicator(),
                          Expanded(child: _Entries(items: page.items)),
                          const Divider(height: 1),
                          _Pagination(result: page),
                        ],
                      ),
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.filter});

  final AuditFilter filter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuditCubit>();
    final actions = filter.targetType == null
        ? OpsTexts.auditActions.values.expand((codes) => codes).toList()
        : OpsTexts.auditActions[filter.targetType] ?? const <String>[];

    Future<void> pickDate({required bool from}) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: (from ? filter.from : filter.to) ?? now,
        firstDate: DateTime(2026),
        lastDate: now,
      );
      if (picked == null) return;
      await cubit.filter(from ? filter.copyWith(from: picked) : filter.copyWith(to: picked));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('target-${filter.targetType}'),
            initialValue: filter.targetType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: OpsTexts.target, isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text(OpsTexts.allTargets)),
              for (final type in OpsTexts.auditActions.keys)
                DropdownMenuItem(value: type, child: Text(OpsTexts.auditTarget(type))),
            ],
            // Another target type has other actions: the chosen one may not apply.
            onChanged: (type) => cubit.filter(filter.copyWith(targetType: type, action: null)),
          ),
        ),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('action-${filter.targetType}-${filter.action}'),
            initialValue: actions.contains(filter.action) ? filter.action : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: OpsTexts.action, isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text(OpsTexts.allActions)),
              for (final action in actions) DropdownMenuItem(value: action, child: Text(OpsTexts.auditAction(action))),
            ],
            onChanged: (action) => cubit.filter(filter.copyWith(action: action)),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => pickDate(from: true),
          icon: const Icon(Icons.event_outlined),
          label: Text(filter.from == null ? OpsTexts.fromDate : '${OpsTexts.fromDate} ${Formatters.date(filter.from)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => pickDate(from: false),
          icon: const Icon(Icons.event_outlined),
          label: Text(filter.to == null ? OpsTexts.toDate : '${OpsTexts.toDate} ${Formatters.date(filter.to)}'),
        ),
        if (!filter.isEmpty)
          TextButton.icon(
            onPressed: () => cubit.filter(const AuditFilter()),
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text(OpsTexts.clearFilters),
          ),
      ],
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({required this.items});

  final List<AuditEntry> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = items[index];
              return ListTile(
                leading: Icon(_icon(entry)),
                title: Text('${OpsTexts.auditAction(entry.action)} · ${OpsTexts.auditTargetLabel(entry)}'),
                subtitle: Text(
                  [
                    '${Formatters.dateTime(entry.occurredAt)} · ${entry.actorName ?? OpsTexts.system}',
                    ...OpsTexts.auditDetails(entry),
                  ].join('\n'),
                ),
                isThreeLine: true,
              );
            },
          );
        }
        return SingleChildScrollView(
          child: DataTable(
            dataRowMaxHeight: double.infinity,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: OttosColors.navy),
            columns: const [
              DataColumn(label: Text(OpsTexts.when)),
              DataColumn(label: Text(OpsTexts.who)),
              DataColumn(label: Text(OpsTexts.action)),
              DataColumn(label: Text(OpsTexts.target)),
              DataColumn(label: Text(OpsTexts.detail)),
            ],
            rows: [
              for (final entry in items)
                DataRow(
                  cells: [
                    // Without softWrap the table squeezes the date into one word per line.
                    DataCell(Text(Formatters.dateTime(entry.occurredAt), softWrap: false)),
                    DataCell(Text(entry.actorName ?? OpsTexts.system)),
                    DataCell(Text(OpsTexts.auditAction(entry.action))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(entry), size: 18, color: OttosColors.navy),
                          const SizedBox(width: 6),
                          Text(OpsTexts.auditTargetLabel(entry)),
                        ],
                      ),
                    ),
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(OpsTexts.auditDetails(entry).join('\n')),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  static IconData _icon(AuditEntry entry) => switch (entry.targetType) {
    'ROLE' => Icons.admin_panel_settings_outlined,
    'REMITTANCE' => Icons.send_outlined,
    _ => Icons.person_outline,
  };
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.result});

  final PageResult<AuditEntry> result;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuditCubit>();
    final first = result.totalItems == 0 ? 0 : result.page * result.size + 1;
    final last = result.page * result.size + result.items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(OpsTexts.pageOf(first, last, result.totalItems)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: OpsTexts.previousPage,
            onPressed: result.page > 0 ? () => cubit.load(page: result.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: OpsTexts.nextPage,
            onPressed: result.page + 1 < result.totalPages ? () => cubit.load(page: result.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
