import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../cubit/roles_cubit.dart';
import 'role_dialog.dart';
import '../../../widgets/page_header.dart';

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RolesCubit(roles: context.read<RoleRepository>())..load(),
      child: BlocBuilder<RolesCubit, RolesState>(
        builder: (context, state) => switch (state.status) {
          RolesStatus.loading => const LoadingView(),
          RolesStatus.failure => ErrorView(message: state.error!, onRetry: context.read<RolesCubit>().load),
          RolesStatus.success => _RolesView(state: state),
        },
      ),
    );
  }
}

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

class _RolesView extends StatelessWidget {
  const _RolesView({required this.state});

  final RolesState state;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    // No user while logging out: the page goes before the redirect.
    if (user == null) return const SizedBox.shrink();
    final canWrite = user.can(Permissions.rolesWrite);
    final cubit = context.read<RolesCubit>();
    return ListView(
      padding: pagePadding(context),
      children: [
        PageHeader(
          title: OpsTexts.roles,
          actions: [
            if (canWrite)
              FilledButton.icon(
                onPressed: () async {
                  final role = await showRoleDialog(context, catalog: state.catalog, grantable: user.permissions);
                  if (role == null || !context.mounted) return;
                  _notify(context, OpsTexts.roleCreated(role.displayName));
                  await cubit.load();
                },
                icon: const Icon(Icons.add),
                label: const Text(OpsTexts.newRole),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final role in state.roles)
          _RoleCard(role: role, catalog: state.catalog, canWrite: canWrite && !role.builtIn),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.catalog, required this.canWrite});

  final Role role;
  final List<PermissionInfo> catalog;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    // No user while logging out: the page goes before the redirect.
    if (user == null) return const SizedBox.shrink();
    final cubit = context.read<RolesCubit>();
    final textTheme = Theme.of(context).textTheme;
    final byCode = {for (final permission in catalog) permission.code: permission};
    final modules = <String, List<String>>{};
    for (final code in role.permissions) {
      modules.putIfAbsent(byCode[code]?.module ?? '', () => []).add(code);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(role.displayName, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text(role.code, style: textTheme.bodySmall),
                if (role.builtIn) const Chip(label: Text(OpsTexts.builtIn), visualDensity: VisualDensity.compact),
              ],
            ),
            if (role.displayDescription case final description? when description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description),
            ],
            if (canWrite) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final saved = await showRoleDialog(
                        context,
                        catalog: catalog,
                        grantable: user.permissions,
                        role: role,
                      );
                      if (saved == null || !context.mounted) return;
                      _notify(context, OpsTexts.roleSaved);
                      await cubit.load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(OpsTexts.edit),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(OpsTexts.delete),
                  ),
                ],
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(OpsTexts.permissionCount(role.permissions.length)),
              children: [
                for (final MapEntry(key: module, value: codes) in modules.entries)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(OpsTexts.permissionModule(module), style: textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final code in codes)
                                Chip(
                                  label: Text(byCode[code] == null ? code : OpsTexts.permissionLabel(byCode[code]!)),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<RolesCubit>();
    final roles = context.read<RoleRepository>();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(OpsTexts.deleteRoleTitle),
            content: Text(OpsTexts.deleteRoleMessage(role.displayName)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(CoreTexts.cancel)),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(OpsTexts.delete)),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await roles.delete(role.id);
      if (!context.mounted) return;
      _notify(context, OpsTexts.roleDeleted);
      await cubit.load();
    } on ApiException catch (error) {
      if (context.mounted) _notify(context, error.message);
    }
  }
}
