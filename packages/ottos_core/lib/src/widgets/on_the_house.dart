import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/can_do.dart';
import '../auth/permissions.dart';
import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../remittances/new_remittance_cubit.dart';
import '../theme/ottos_colors.dart';

/// "Por la casa": a delivery sent without a fee. Shown wherever the
/// remittance shows, to couriers too.
class OnTheHouseBadge extends StatelessWidget {
  const OnTheHouseBadge({super.key, this.onDark = false});

  /// White on a colored header.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : OttosColors.onTheHouse;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.18) : OttosColors.onTheHouse.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_outlined, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            CoreTexts.onTheHouse,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// The "Por la casa (sin comisión)" box of a new remittance and, when
/// marked, its required reason. Only for deliveries and only for who has
/// `remittances:on-the-house`; nothing otherwise.
class OnTheHouseField extends StatefulWidget {
  const OnTheHouseField({super.key, required this.state});

  final NewRemittanceState state;

  @override
  State<OnTheHouseField> createState() => _OnTheHouseFieldState();
}

class _OnTheHouseFieldState extends State<OnTheHouseField> {
  final _reason = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.type != RemittanceType.delivery || !context.canDo(Permissions.remittancesOnTheHouse)) {
      return const SizedBox.shrink();
    }
    final cubit = context.read<NewRemittanceCubit>();
    final enabled = !state.submitting;
    String? error;
    if (state.onTheHouseReasonTooLong) {
      error = CoreTexts.onTheHouseReasonTooLong(NewRemittanceState.onTheHouseReasonMaxLength);
    } else if (_touched && state.onTheHouseReasonMissing) {
      error = CoreTexts.onTheHouseReasonRequired;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // A Material, not a colored box: the tile paints its ink on it.
      child: Material(
        color: state.onTheHouse ? OttosColors.onTheHouse.withValues(alpha: 0.06) : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: state.onTheHouse
                ? OttosColors.onTheHouse.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: state.onTheHouse,
              onChanged: enabled ? (value) => cubit.onTheHouseChanged(value ?? false) : null,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: OttosColors.onTheHouse,
              secondary: const Icon(Icons.home_outlined, color: OttosColors.onTheHouse),
              title: const Text(CoreTexts.onTheHouseCheckbox),
              subtitle: const Text(CoreTexts.onTheHouseCheckboxHelp),
            ),
            if (state.onTheHouse)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _reason,
                  enabled: enabled,
                  maxLines: 2,
                  maxLength: NewRemittanceState.onTheHouseReasonMaxLength,
                  decoration: InputDecoration(
                    labelText: CoreTexts.onTheHouseReason,
                    hintText: CoreTexts.onTheHouseReasonHint,
                    errorText: error,
                  ),
                  onChanged: (text) {
                    if (!_touched) setState(() => _touched = true);
                    cubit.onTheHouseReasonChanged(text);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
