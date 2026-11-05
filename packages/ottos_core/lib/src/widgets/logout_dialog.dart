import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/bloc/auth_bloc.dart';
import '../auth/login/login_memory.dart';
import '../l10n/core_texts.dart';
import '../theme/ottos_colors.dart';

/// Logs out, asking first when there is something to decide: the [warning]
/// (e.g. actions not sent yet) and, where a fingerprint login is saved on this
/// device, whether to forget it (SEC-1). Without either it logs out at once.
/// [beforeLogout] runs once confirmed, before the session closes.
Future<void> confirmLogout(
  BuildContext context, {
  String? warning,
  String confirmLabel = CoreTexts.logout,
  Future<void> Function()? beforeLogout,
}) async {
  final auth = context.read<AuthBloc>();
  final biometricEmail = await _memoryOf(context)?.biometricEmail();
  if (!context.mounted) return;
  var forget = false;
  if (warning != null || biometricEmail != null) {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutDialog(warning: warning, confirmLabel: confirmLabel, biometricEmail: biometricEmail),
    );
    if (choice == null) return;
    forget = choice;
  }
  await beforeLogout?.call();
  auth.add(AuthLogoutRequested(forgetBiometricLogin: forget));
}

LoginMemory? _memoryOf(BuildContext context) {
  try {
    return context.read<LoginMemory>();
  } catch (_) {
    return null;
  }
}

/// Pops null when cancelled, otherwise whether to forget the fingerprint login.
class _LogoutDialog extends StatefulWidget {
  const _LogoutDialog({required this.warning, required this.confirmLabel, required this.biometricEmail});

  final String? warning;
  final String confirmLabel;
  final String? biometricEmail;

  @override
  State<_LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<_LogoutDialog> {
  bool _forget = false;

  @override
  Widget build(BuildContext context) {
    final warning = widget.warning;
    final email = widget.biometricEmail;
    return AlertDialog(
      title: const Text(CoreTexts.logout),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(warning ?? CoreTexts.logoutQuestion),
          if (email != null) ...[
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _forget,
              onChanged: (value) => setState(() => _forget = value ?? false),
              title: Text(CoreTexts.forgetBiometricLogin(email)),
              subtitle: const Text(CoreTexts.forgetBiometricLoginHelp),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        TextButton(
          style: warning == null ? null : TextButton.styleFrom(foregroundColor: OttosColors.danger),
          onPressed: () => Navigator.of(context).pop(_forget),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
