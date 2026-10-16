import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../app/router.dart';
import '../../../widgets/pagination_bar.dart';
import '../cubit/customer_list_cubit.dart';
import 'customer_transfer.dart';
import '../../../widgets/page_header.dart';

class CustomerListPage extends StatelessWidget {
  const CustomerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerListCubit(customers: context.read<CustomerRepository>())..load(),
      child: const _CustomerListView(),
    );
  }
}

class _CustomerListView extends StatelessWidget {
  const _CustomerListView();

  @override
  Widget build(BuildContext context) {
    final canWrite = context.canDo(Permissions.customersWrite);
    final cubit = context.read<CustomerListCubit>();
    return Padding(
      padding: pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: OpsTexts.customers,
            actions: [
              if (context.canDo(Permissions.customersExport)) ...[
                TextButton.icon(
                  onPressed: () => exportCustomers(context),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text(OpsTexts.exportCsv),
                ),
              ],
              if (context.canDo(Permissions.customersImport)) ...[
                TextButton.icon(
                  onPressed: () async {
                    final cubit = context.read<CustomerListCubit>();
                    if (await importCustomers(context)) await cubit.load();
                  },
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text(OpsTexts.importCsv),
                ),
                TextButton.icon(
                  onPressed: () => importBeneficiaries(context),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text(OpsTexts.importBeneficiariesCsv),
                ),
              ],
              if (canWrite)
                FilledButton.icon(
                  onPressed: () async {
                    final customer = await showCustomerFormDialog(context);
                    if (customer != null && context.mounted) context.go(Routes.customer(customer.id));
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text(OpsTexts.newCustomer),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 360,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: OpsTexts.searchCustomer,
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
              child: BlocBuilder<CustomerListCubit, CustomerListState>(
                builder: (context, state) {
                  if (state.status == CustomerListStatus.failure) {
                    return ErrorView(message: state.error!, onRetry: cubit.load);
                  }
                  if (state.status == CustomerListStatus.loading && state.customers.isEmpty) {
                    return const LoadingView();
                  }
                  return Column(
                    children: [
                      if (state.status == CustomerListStatus.loading) const LinearProgressIndicator(minHeight: 2),
                      Expanded(
                        child: state.customers.isEmpty
                            ? EmptyView(
                                message: state.query.trim().isEmpty ? OpsTexts.noCustomersYet : OpsTexts.noCustomers,
                              )
                            : _CustomerTable(customers: state.customers),
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

class _CustomerTable extends StatelessWidget {
  const _CustomerTable({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    if (isCompact(context)) {
      return ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            onTap: () => context.go(Routes.customer(customer.id)),
            title: Text(customer.fullName),
            subtitle: Text([customer.phone, ?customer.address].join('\n')),
            isThreeLine: customer.address != null,
            trailing: customer.active ? null : const Text(OpsTexts.inactive),
          );
        },
      );
    }
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text(OpsTexts.fullName)),
            DataColumn(label: Text(OpsTexts.phone)),
            DataColumn(label: Text(OpsTexts.address)),
            DataColumn(label: Text(OpsTexts.document)),
            DataColumn(label: Text(OpsTexts.createdAt)),
          ],
          rows: [
            for (final customer in customers)
              DataRow(
                onSelectChanged: (_) => context.go(Routes.customer(customer.id)),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        Text(customer.fullName),
                        if (!customer.active) ...[
                          const SizedBox(width: 8),
                          const Chip(label: Text(OpsTexts.inactive), visualDensity: VisualDensity.compact),
                        ],
                      ],
                    ),
                  ),
                  DataCell(Text(customer.phone)),
                  // Two customers may share name and phone: the address tells them apart.
                  DataCell(Text(customer.address ?? '', overflow: TextOverflow.ellipsis)),
                  DataCell(Text([customer.documentType, customer.documentNumber].whereType<String>().join(' '))),
                  DataCell(Text(Formatters.date(customer.createdAt))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
