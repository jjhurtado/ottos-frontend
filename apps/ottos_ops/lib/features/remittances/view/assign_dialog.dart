import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';

typedef AssignInput = ({String courierId, String? note});

/// Asks for the courier (and an optional note) to assign a remittance to.
Future<AssignInput?> showAssignDialog(BuildContext context, {String? currentCourierId}) {
  final remittances = context.read<RemittanceRepository>();
  return showDialog<AssignInput>(
    context: context,
    builder: (_) => _AssignDialog(couriers: remittances.couriers(), currentCourierId: currentCourierId),
  );
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.couriers, this.currentCourierId});

  final Future<List<Courier>> couriers;
  final String? currentCourierId;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late Future<List<Courier>> _couriers = widget.couriers;
  late String? _courierId = widget.currentCourierId;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _courierId != null && _courierId != widget.currentCourierId;
    return AlertDialog(
      title: Text(widget.currentCourierId == null ? OpsTexts.assignCourier : OpsTexts.reassignCourier),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Courier>>(
          future: _couriers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              final error = snapshot.error;
              return ErrorView(
                message: error is ApiException ? error.message : CoreTexts.unexpectedError,
                onRetry: () => setState(() {
                  _couriers = context.read<RemittanceRepository>().couriers();
                }),
              );
            }
            final couriers = snapshot.data;
            if (couriers == null) return const SizedBox(height: 120, child: LoadingView());
            if (couriers.isEmpty) return const EmptyView(message: OpsTexts.noCouriers);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: couriers.any((courier) => courier.id == _courierId) ? _courierId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: OpsTexts.courier),
                  items: [
                    for (final courier in couriers)
                      DropdownMenuItem(
                        value: courier.id,
                        child: Text('${courier.displayName} · ${OpsTexts.openRemittances(courier.openRemittances)}'),
                      ),
                  ],
                  onChanged: (id) => setState(() => _courierId = id),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: CoreTexts.note),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: canSubmit
              ? () =>
                    Navigator.of(context)
                        .pop((courierId: _courierId!, note: _note.text.trim().isEmpty ? null : _note.text.trim()))
              : null,
          child: const Text(OpsTexts.assign),
        ),
      ],
    );
  }
}
