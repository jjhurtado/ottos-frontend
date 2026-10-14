import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../widgets/pagination_bar.dart';
import '../cubit/beneficiary_list_cubit.dart';

/// Every beneficiary, including those without a customer (imported or created
/// alone), which the customer page cannot reach.
class BeneficiaryListPage extends StatelessWidget {
  const BeneficiaryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BeneficiaryListCubit(customers: context.read<CustomerRepository>())..load(),
      child: const _BeneficiaryListView(),
    );
  }
}

class _BeneficiaryListView extends StatelessWidget {
  const _BeneficiaryListView();

  @override
  Widget build(BuildContext context) {
    final canWrite = context.canDo(Permissions.customersWrite);
    final cubit = context.read<BeneficiaryListCubit>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(OpsTexts.beneficiaries, style: Theme.of(context).textTheme.headlineMedium)),
              if (canWrite)
                FilledButton.icon(
                  onPressed: () async {
                    final created = await showBeneficiaryFormDialog(context);
                    if (created != null) cubit.saved(created);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(OpsTexts.newBeneficiary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(OpsTexts.beneficiariesHelp, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 360,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: OpsTexts.searchBeneficiary,
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: cubit.queryChanged,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: BlocBuilder<BeneficiaryListCubit, BeneficiaryListState>(
                builder: (context, state) {
                  if (state.status == BeneficiaryListStatus.failure) {
                    return ErrorView(message: state.error!, onRetry: cubit.load);
                  }
                  if (state.status == BeneficiaryListStatus.loading && state.beneficiaries.isEmpty) {
                    return const LoadingView();
                  }
                  return Column(
                    children: [
                      if (state.status == BeneficiaryListStatus.loading) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: state.beneficiaries.isEmpty
                            ? EmptyView(
                                message: state.query.trim().isEmpty
                                    ? OpsTexts.noBeneficiariesYet
                                    : OpsTexts.noBeneficiariesFound,
                              )
                            : _BeneficiaryTable(beneficiaries: state.beneficiaries, canWrite: canWrite),
                      ),
                      if (state.result case final result?) ...[
                        const Divider(height: 1),
                        PaginationBar(
                          result: result,
                          onPage: (page) => cubit.load(page: page),
                        ),
                      ],
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

class _BeneficiaryTable extends StatelessWidget {
  const _BeneficiaryTable({required this.beneficiaries, required this.canWrite});

  final List<Beneficiary> beneficiaries;
  final bool canWrite;

  Future<void> _edit(BuildContext context, Beneficiary beneficiary) async {
    final cubit = context.read<BeneficiaryListCubit>();
    final saved = await showBeneficiaryFormDialog(context, beneficiary: beneficiary);
    if (saved != null) cubit.saved(saved);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: [
            const DataColumn(label: Text(OpsTexts.fullName)),
            const DataColumn(label: Text(OpsTexts.phone)),
            const DataColumn(label: Text(OpsTexts.address)),
            if (canWrite) const DataColumn(label: SizedBox.shrink()),
          ],
          rows: [
            for (final beneficiary in beneficiaries)
              DataRow(
                onSelectChanged: canWrite ? (_) => _edit(context, beneficiary) : null,
                cells: [
                  DataCell(Text(beneficiary.fullName)),
                  DataCell(
                    Text(
                      [
                        beneficiary.phone,
                        beneficiary.alternatePhone,
                      ].whereType<String>().where((phone) => phone.isNotEmpty).join(' · '),
                    ),
                  ),
                  DataCell(Text(beneficiary.address, overflow: TextOverflow.ellipsis)),
                  if (canWrite)
                    DataCell(
                      IconButton(
                        tooltip: OpsTexts.edit,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, beneficiary),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
