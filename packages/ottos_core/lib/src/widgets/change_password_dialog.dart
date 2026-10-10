import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../auth/auth_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../l10n/core_texts.dart';

/// Passwords must have 8 to 72 characters (the backend's rule).
String? passwordError(String? password) {
  final length = password?.length ?? 0;
  if (length == 0) return CoreTexts.requiredField;
  if (length < 8) return CoreTexts.passwordTooShort;
  if (length > 72) return CoreTexts.passwordTooLong;
  return null;
}

/// Lets the logged-in user change their password. The backend then signs
/// them out everywhere, so on success the app logs out and the login page
/// says why. Expects an [AuthRepository] and an [AuthBloc] above [context].
Future<void> showChangePasswordDialog(BuildContext context) async {
  final authBloc = context.read<AuthBloc>();
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ChangePasswordDialog(auth: context.read<AuthRepository>()),
  );
  if (changed ?? false) authBloc.add(const AuthPasswordChanged());
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.auth});

  final AuthRepository auth;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  Widget _field(TextEditingController controller, String label, String? Function(String?) validator, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        obscureText: _obscure,
        autofillHints: controller == _current ? const [AutofillHints.password] : const [AutofillHints.newPassword],
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(CoreTexts.changePassword),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(CoreTexts.changePasswordHelp),
                  const SizedBox(height: 16),
                  _field(
                    _current,
                    CoreTexts.currentPassword,
                    (value) => (value ?? '').isEmpty ? CoreTexts.requiredField : null,
                  ),
                  _field(_new, CoreTexts.newPassword, helper: CoreTexts.passwordHint, (value) {
                    final error = passwordError(value);
                    if (error != null) return error;
                    return value == _current.text ? CoreTexts.samePassword : null;
                  }),
                  _field(
                    _repeat,
                    CoreTexts.repeatPassword,
                    (value) => value == _new.text ? null : CoreTexts.passwordsDiffer,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      label: Text(_obscure ? CoreTexts.showPassword : CoreTexts.hidePassword),
                    ),
                  ),
                  if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text(CoreTexts.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(CoreTexts.changePassword),
        ),
      ],
    );
  }
}
