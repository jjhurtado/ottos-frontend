import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';

/// Creates a staff user; returns it, or null if cancelled.
Future<StaffUser?> showNewUserDialog(BuildContext context) {
  final users = context.read<UserRepository>();
  final roles = context.read<RoleRepository>().list();
  return showDialog<StaffUser>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UserFormDialog(
      title: OpsTexts.newUser,
      roles: roles,
      save: (form) => users.create(
        NewStaffUser(email: form.email, name: form.name, password: form.password, roleIds: form.roleIds),
      ),
    ),
  );
}

/// Changes a user's name and roles; returns the user as saved, or null if cancelled.
Future<StaffUser?> showEditUserDialog(BuildContext context, StaffUser user) {
  final users = context.read<UserRepository>();
  final roles = context.read<RoleRepository>().list();
  return showDialog<StaffUser>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UserFormDialog(
      title: OpsTexts.editUser,
      user: user,
      roles: roles,
      save: (form) async {
        var saved = user;
        if (form.name.trim() != user.name) saved = await users.rename(user.id, form.name);
        final current = {for (final role in user.roles) role.id};
        if (current.length != form.roleIds.length || !current.containsAll(form.roleIds)) {
          saved = await users.replaceRoles(user.id, form.roleIds);
        }
        return saved;
      },
    ),
  );
}

typedef _UserForm = ({String email, String name, String password, Set<String> roleIds});

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.title, required this.roles, required this.save, this.user});

  final String title;
  final Future<List<Role>> roles;
  final Future<StaffUser> Function(_UserForm form) save;

  /// The user being edited; null when creating one.
  final StaffUser? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.user?.email);
  late final _name = TextEditingController(text: widget.user?.name);
  final _password = TextEditingController();
  late final Set<String> _roleIds = {for (final role in widget.user?.roles ?? const <RoleSummary>[]) role.id};
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  bool get _creating => widget.user == null;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rolesValid = _roleIds.isNotEmpty;
    if (!_formKey.currentState!.validate() || !rolesValid) {
      if (!rolesValid) setState(() => _error = OpsTexts.chooseRole);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save((
        email: _email.text,
        name: _name.text,
        password: _password.text,
        roleIds: _roleIds,
      ));
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  enabled: _creating && !_saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '${OpsTexts.email} *'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return OpsTexts.requiredField;
                    return email.contains('@') ? null : CoreTexts.emailInvalid;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  autofocus: !_creating,
                  decoration: const InputDecoration(labelText: '${OpsTexts.fullName} *'),
                  validator: (value) => (value ?? '').trim().isEmpty ? OpsTexts.requiredField : null,
                ),
                if (_creating) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    enabled: !_saving,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '${OpsTexts.initialPassword} *',
                      helperText: CoreTexts.passwordHint,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? CoreTexts.showPassword : CoreTexts.hidePassword,
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: passwordError,
                  ),
                ],
                const SizedBox(height: 16),
                Text(OpsTexts.userRoles, style: Theme.of(context).textTheme.labelLarge),
                FutureBuilder<List<Role>>(
                  future: widget.roles,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return Text(
                        error is ApiException ? error.message : CoreTexts.unexpectedError,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      );
                    }
                    final roles = snapshot.data;
                    if (roles == null) return const LinearProgressIndicator();
                    return Column(
                      children: [
                        for (final role in roles)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _roleIds.contains(role.id),
                            title: Text(role.displayName),
                            subtitle: role.displayDescription == null ? null : Text(role.displayDescription!),
                            onChanged: _saving
                                ? null
                                : (checked) =>
                                      setState(() => checked! ? _roleIds.add(role.id) : _roleIds.remove(role.id)),
                          ),
                      ],
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text(CoreTexts.cancel)),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(OpsTexts.save),
        ),
      ],
    );
  }
}

/// Sets a new password for [user]; returns true when saved.
Future<bool> showResetPasswordDialog(BuildContext context, StaffUser user) async {
  final users = context.read<UserRepository>();
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResetPasswordDialog(user: user, users: users),
      ) ??
      false;
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.user, required this.users});

  final StaffUser user;
  final UserRepository users;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.users.resetPassword(widget.user.id, _password.text);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(OpsTexts.resetPasswordTitle(widget.user.displayName)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(OpsTexts.resetPasswordHelp),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                enabled: !_saving,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '${CoreTexts.newPassword} *',
                  helperText: CoreTexts.passwordHint,
                ),
                validator: passwordError,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text(CoreTexts.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _submit, child: const Text(OpsTexts.save)),
      ],
    );
  }
}
