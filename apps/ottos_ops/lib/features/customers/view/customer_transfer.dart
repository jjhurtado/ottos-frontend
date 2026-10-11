import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../customer_csv.dart';

/// Downloads every customer with their beneficiaries as CSV (`customers:export`).
Future<void> exportCustomers(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final customers = await context.read<CustomerRepository>().exportAll();
    final today = Formatters.apiDate(DateTime.now());
    await FilePicker.saveFile(
      fileName: OpsTexts.customersFileName(today),
      bytes: utf8.encode(CustomerCsv.export(customers)),
      mimeType: 'text/csv',
    );
  } on ApiException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  }
}

/// Picks a CSV, shows what importing it would do, and imports it on
/// confirmation (`customers:import`). True if something was imported.
Future<bool> importCustomers(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = context.read<CustomerRepository>();
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
  if (files.isEmpty) return false;
  final List<ImportCustomer> customers;
  try {
    customers = CustomerCsv.parse(utf8.decode(await files.single.readAsBytes(), allowMalformed: true));
  } on FormatException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  }
  if (customers.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text(OpsTexts.importEmpty)));
    return false;
  }
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportDialog(customers: customers, repository: repository),
  );
  return confirmed ?? false;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.customers, required this.repository});

  final List<ImportCustomer> customers;
  final CustomerRepository repository;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late Future<ImportResult> _result = widget.repository.import(widget.customers, dryRun: true);
  var _importing = false;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _result = widget.repository.import(widget.customers, dryRun: false);
    });
    try {
      await _result;
    } on ApiException {
      // Shown by the builder.
    }
    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImportResult>(
      future: _result,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final done = result != null && !result.dryRun;
        return AlertDialog(
          title: Text(done ? OpsTexts.importDone : OpsTexts.importPreview),
          content: SizedBox(
            width: 560,
            child: switch (snapshot) {
              AsyncSnapshot(hasError: true, :final error) => Text(
                error is ApiException ? error.message : CoreTexts.unexpectedError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              AsyncSnapshot(connectionState: ConnectionState.waiting) => const SizedBox(
                height: 120,
                child: LoadingView(),
              ),
              _ => _Summary(result: result!),
            },
          ),
          actions: [
            if (done)
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(OpsTexts.close))
            else ...[
              TextButton(
                onPressed: _importing ? null : () => Navigator.of(context).pop(false),
                child: const Text(CoreTexts.cancel),
              ),
              FilledButton(
                onPressed:
                    _importing ||
                        result == null ||
                        result.customersCreated + result.beneficiariesCreated + result.linksCreated == 0
                    ? null
                    : _import,
                child: const Text(OpsTexts.importConfirm),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final rejected = result.rejected;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.dryRun) const Text(OpsTexts.importPreviewHelp),
          const SizedBox(height: 12),
          InfoRow(
            label: OpsTexts.customers,
            value: OpsTexts.importCounts(result.customersCreated, result.customersExisting, result.customersRejected),
          ),
          InfoRow(
            label: OpsTexts.beneficiaries,
            value: OpsTexts.importCounts(
              result.beneficiariesCreated,
              result.beneficiariesExisting,
              result.beneficiariesRejected,
            ),
          ),
          InfoRow(label: OpsTexts.importLinks, value: '${result.linksCreated}'),
          if (rejected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(OpsTexts.importRejected, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final item in rejected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${item.ref ?? ''}: ${CoreTexts.errorCodes[item.code] ?? item.message ?? item.code ?? ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
