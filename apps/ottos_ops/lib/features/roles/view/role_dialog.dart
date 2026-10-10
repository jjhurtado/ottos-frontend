import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';

/// Codes are UPPER_SNAKE_CASE, 2 to 50 characters (the backend's rule).
String? roleCodeError(String? code) {
  final value = code?.trim() ?? '';
  if (value.isEmpty) return OpsTexts.requiredField;
  return RegExp(r'^[A-Z][A-Z0-9_]{1,49}$').hasMatch(value) ? null : OpsTexts.roleCodeInvalid;
}

/// Creates a role, or edits [role]; returns the role as saved, or null if cancelled.
///
/// Only permissions in [grantable] (the ones the user has) can be ticked or
/// unticked: the backend refuses to grant or remove any other.
Future<Role?> showRoleDialog(
  BuildContext context, {
  required List<PermissionInfo> catalog,
  required Set<String> grantable,
  Role? role,
}) {
  final roles = context.read<RoleRepository>();
  return showDialog<Role>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RoleDialog(roles: roles, catalog: catalog, grantable: grantable, role: role),
  );
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.roles, required this.catalog, required this.grantable, this.role});

  final RoleRepository roles;
  final List<PermissionInfo> catalog;
  final Set<String> grantable;
  final Role? role;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.role?.code);
  late final _name = TextEditingController(text: widget.role?.name);
  late final _description = TextEditingController(text: widget.role?.description);
  late final Set<String> _permissions = {...?widget.role?.permissions};
  bool _saving = false;
  String? _error;

  bool get _creating => widget.role == null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final role = widget.role;
      final Role saved;
      if (role == null) {
        saved = await widget.roles.create(
          NewRole(code: _code.text, name: _name.text, description: _description.text, permissions: _permissions),
        );
      } else {
        var current = role;
        if (_name.text.trim() != role.name || _description.text.trim() != (role.description ?? '')) {
          current = await widget.roles.describe(role.id, name: _name.text, description: _description.text);
        }
        final before = role.permissions.toSet();
        if (before.length != _permissions.length || !before.containsAll(_permissions)) {
          current = await widget.roles.replacePermissions(role.id, _permissions);
        }
        saved = current;
      }
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
    final modules = <String, List<PermissionInfo>>{};
    for (final permission in widget.catalog) {
      modules.putIfAbsent(permission.module, () => []).add(permission);
    }
    return AlertDialog(
      title: Text(_creating ? OpsTexts.newRole : OpsTexts.editRole(widget.role!.name)),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _code,
                        enabled: _creating && !_saving,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_]')),
                          TextInputFormatter.withFunction((_, value) => value.copyWith(text: value.text.toUpperCase())),
                        ],
                        decoration: const InputDecoration(
                          labelText: '${OpsTexts.roleCode} *',
                          helperText: OpsTexts.roleCodeHint,
                        ),
                        validator: _creating ? roleCodeError : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: '${OpsTexts.roleName} *'),
                        validator: (value) => (value ?? '').trim().isEmpty ? OpsTexts.requiredField : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: OpsTexts.roleDescription),
                ),
                const SizedBox(height: 16),
                Text(OpsTexts.permissions, style: Theme.of(context).textTheme.titleSmall),
                if (widget.catalog.any((permission) => !widget.grantable.contains(permission.code)))
                  Text(OpsTexts.onlyYourPermissions, style: Theme.of(context).textTheme.bodySmall),
                for (final MapEntry(key: module, value: permissions) in modules.entries) ...[
                  const SizedBox(height: 12),
                  Text(OpsTexts.permissionModule(module), style: Theme.of(context).textTheme.labelLarge),
                  for (final permission in permissions)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _permissions.contains(permission.code),
                      title: Text(OpsTexts.permissionLabel(permission)),
                      subtitle: Text(permission.code),
                      onChanged: _saving || !widget.grantable.contains(permission.code)
                          ? null
                          : (checked) => setState(
                              () => checked! ? _permissions.add(permission.code) : _permissions.remove(permission.code),
                            ),
                    ),
                ],
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
