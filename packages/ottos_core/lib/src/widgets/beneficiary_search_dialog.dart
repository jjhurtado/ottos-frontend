import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../l10n/core_texts.dart';
import '../models/customer.dart';

/// Searches every beneficiary (linked to a customer or not) and returns the
/// one picked; null if cancelled.
Future<Beneficiary?> showBeneficiarySearchDialog(
  BuildContext context, {
  required Future<List<Beneficiary>> Function(String query) search,
}) => showDialog<Beneficiary>(
  context: context,
  builder: (_) => _BeneficiarySearchDialog(search: search),
);

class _BeneficiarySearchDialog extends StatefulWidget {
  const _BeneficiarySearchDialog({required this.search});

  final Future<List<Beneficiary>> Function(String query) search;

  @override
  State<_BeneficiarySearchDialog> createState() => _BeneficiarySearchDialogState();
}

class _BeneficiarySearchDialogState extends State<_BeneficiarySearchDialog> {
  Timer? _debounce;
  var _query = '';
  Future<List<Beneficiary>>? _results;

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = value.trim();
      setState(() {
        _query = query;
        _results = query.length < 2 ? null : widget.search(query);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text(CoreTexts.searchOtherBeneficiary),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(CoreTexts.searchBeneficiaryHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: CoreTexts.searchBeneficiaryHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _changed,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results == null
                  ? Center(child: Text(_query.isEmpty ? '' : CoreTexts.typeToSearch))
                  : FutureBuilder<List<Beneficiary>>(
                      future: _results,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          final error = snapshot.error;
                          return Center(
                            child: Text(
                              error is ApiException ? error.message : CoreTexts.unexpectedError,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          );
                        }
                        final found = snapshot.data;
                        if (found == null) return const Center(child: CircularProgressIndicator());
                        if (found.isEmpty) return const Center(child: Text(CoreTexts.noBeneficiariesFound));
                        return ListView(
                          children: [
                            for (final beneficiary in found)
                              ListTile(
                                title: Text(beneficiary.fullName),
                                subtitle: Text(
                                  [beneficiary.phone, beneficiary.address].where((part) => part.isNotEmpty).join(' · '),
                                ),
                                onTap: () => Navigator.of(context).pop(beneficiary),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel))],
    );
  }
}
