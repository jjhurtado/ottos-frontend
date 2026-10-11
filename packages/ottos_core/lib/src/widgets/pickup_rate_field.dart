import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../remittances/new_remittance_cubit.dart';
import '../utils/formatters.dart';

/// A pickup's rate when registering it: starts at the configured one and
/// may be changed (pickups are usually 1×1). Nothing for a delivery.
class PickupRateField extends StatelessWidget {
  const PickupRateField({super.key, required this.state});

  final NewRemittanceState state;

  @override
  Widget build(BuildContext context) {
    if (state.type != RemittanceType.pickup || state.targetCurrency == null) return const SizedBox.shrink();
    final cubit = context.read<NewRemittanceCubit>();
    final configured = cubit.configuredPickupRate;
    String plain(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        // Another currency starts again at its configured rate.
        key: ValueKey('pickup-rate-${state.targetCurrency}'),
        initialValue: configured == null ? '' : plain(configured),
        enabled: !state.submitting,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,6}'))],
        decoration: InputDecoration(
          labelText: CoreTexts.pickupRate,
          suffixText: '${state.targetCurrency} / 1 USD',
          helperText: configured == null ? null : CoreTexts.pickupRateConfigured(Formatters.money(configured, null)),
        ),
        onChanged: (text) => cubit.pickupRateChanged(double.tryParse(text.trim().replaceAll(',', '.'))),
      ),
    );
  }
}
