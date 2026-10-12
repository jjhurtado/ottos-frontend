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
  final repository = context.read<CustomerRepository>();
  final customers = await _pickCsv(context, CustomerCsv.parse, OpsTexts.importEmpty);
  if (customers == null || !context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportDialog<ImportResult>(
      run: (dryRun) => repository.import(customers, dryRun: dryRun),
      isDone: (result) => !result.dryRun,
      hasChanges: (result) => result.customersCreated + result.beneficiariesCreated + result.linksCreated > 0,
      summary: (result) => _Summary(
        preview: result.dryRun,
        rejected: result.rejected,
        rows: [
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
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// Imports beneficiaries without a customer (the list from WhatsApp); each
/// one is linked to its customer by the first remittance.
Future<bool> importBeneficiaries(BuildContext context) async {
  final repository = context.read<CustomerRepository>();
  final beneficiaries = await _pickCsv(context, BeneficiaryCsv.parse, OpsTexts.importNoBeneficiaries);
  if (beneficiaries == null || !context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportDialog<BeneficiaryImportResult>(
      run: (dryRun) => repository.importBeneficiaries(beneficiaries, dryRun: dryRun),
      isDone: (result) => !result.dryRun,
      hasChanges: (result) => result.created > 0,
      summary: (result) => _Summary(
        preview: result.dryRun,
        help: OpsTexts.importBeneficiariesHelp,
        rejected: result.rejected,
        rows: [
          InfoRow(
            label: OpsTexts.beneficiaries,
            value: OpsTexts.importCounts(result.created, result.existing, result.rejectedCount),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

/// The rows of the CSV the user picks; null if cancelled, empty or unreadable.
Future<List<T>?> _pickCsv<T>(BuildContext context, List<T> Function(String text) parse, String emptyMessage) async {
  final messenger = ScaffoldMessenger.of(context);
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
  if (files.isEmpty) return null;
  final List<T> items;
  try {
    items = parse(utf8.decode(await files.single.readAsBytes(), allowMalformed: true));
  } on FormatException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return null;
  }
  if (items.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(emptyMessage)));
    return null;
  }
  return items;
}

/// Shows the preview ([run] with dry run) and imports on confirmation.
class _ImportDialog<T> extends StatefulWidget {
  const _ImportDialog({required this.run, required this.isDone, required this.hasChanges, required this.summary});

  final Future<T> Function(bool dryRun) run;
  final bool Function(T result) isDone;
  final bool Function(T result) hasChanges;
  final Widget Function(T result) summary;

  @override
  State<_ImportDialog<T>> createState() => _ImportDialogState<T>();
}

class _ImportDialogState<T> extends State<_ImportDialog<T>> {
  late Future<T> _result = widget.run(true);
  var _importing = false;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _result = widget.run(false);
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
    return FutureBuilder<T>(
      future: _result,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final done = result != null && widget.isDone(result);
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
              _ => widget.summary(result as T),
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
                onPressed: _importing || result == null || !widget.hasChanges(result) ? null : _import,
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
  const _Summary({required this.preview, required this.rows, required this.rejected, this.help});

  final bool preview;
  final List<Widget> rows;
  final List<ImportItemResult> rejected;

  /// Said under the preview's warning.
  final String? help;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview) const Text(OpsTexts.importPreviewHelp),
          if (help != null) ...[const SizedBox(height: 4), Text(help!)],
          const SizedBox(height: 12),
          ...rows,
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
