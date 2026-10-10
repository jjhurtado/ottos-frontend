import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../cubit/user_list_cubit.dart';
import 'user_dialogs.dart';

class UserListPage extends StatelessWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserListCubit(users: context.read<UserRepository>())..load(),
      child: const _UserListView(),
    );
  }
}

class _UserListView extends StatelessWidget {
  const _UserListView();

  @override
  Widget build(BuildContext context) {
    final canWrite = context.select((AuthBloc bloc) => bloc.state.user!.can(Permissions.usersWrite));
    final cubit = context.read<UserListCubit>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(OpsTexts.users, style: Theme.of(context).textTheme.headlineMedium)),
              if (canWrite)
                FilledButton.icon(
                  onPressed: () async {
                    final user = await showNewUserDialog(context);
                    if (user == null || !context.mounted) return;
                    _notify(context, OpsTexts.userCreated(user.displayName));
                    await cubit.load();
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text(OpsTexts.newUser),
                ),
            ],
          ),
          const SizedBox(height: 16),
          BlocBuilder<UserListCubit, UserListState>(
            buildWhen: (previous, current) =>
                previous.showInactive != current.showInactive || previous.inactiveCount != current.inactiveCount,
            builder: (context, state) => Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: OpsTexts.searchUser,
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: cubit.queryChanged,
                  ),
                ),
                FilterChip(
                  label: Text(OpsTexts.showInactive(state.inactiveCount)),
                  selected: state.showInactive,
                  onSelected: cubit.showInactiveChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: BlocBuilder<UserListCubit, UserListState>(
                builder: (context, state) => switch (state.status) {
                  UserListStatus.loading => const LoadingView(),
                  UserListStatus.failure => ErrorView(message: state.error!, onRetry: cubit.load),
                  UserListStatus.success =>
                    state.visible.isEmpty
                        ? const EmptyView(message: OpsTexts.noUsers)
                        : _UserTable(users: state.visible, canWrite: canWrite),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _notify(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

enum _UserAction { edit, resetPassword, deactivate, activate }

class _UserTable extends StatelessWidget {
  const _UserTable({required this.users, required this.canWrite});

  final List<StaffUser> users;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final me = context.select((AuthBloc bloc) => bloc.state.user!.id);
    final outline = Theme.of(context).colorScheme.outline;
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: [
            const DataColumn(label: Text(OpsTexts.fullName)),
            const DataColumn(label: Text(OpsTexts.email)),
            const DataColumn(label: Text(OpsTexts.userRoles)),
            const DataColumn(label: Text(OpsTexts.status)),
            if (canWrite) const DataColumn(label: Text('')),
          ],
          rows: [
            for (final user in users)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      user.id == me ? '${user.displayName} (${OpsTexts.you})' : user.displayName,
                      style: TextStyle(color: user.active ? null : outline),
                    ),
                  ),
                  DataCell(Text(user.email, style: TextStyle(color: user.active ? null : outline))),
                  DataCell(
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final role in user.roles)
                          Chip(label: Text(role.displayName), visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ),
                  DataCell(Text(user.active ? OpsTexts.active : OpsTexts.inactive)),
                  if (canWrite)
                    DataCell(
                      PopupMenuButton<_UserAction>(
                        tooltip: OpsTexts.actions,
                        onSelected: (action) => _run(context, user, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: _UserAction.edit, child: Text(OpsTexts.edit)),
                          const PopupMenuItem(value: _UserAction.resetPassword, child: Text(OpsTexts.resetPassword)),
                          if (user.active && user.id != me)
                            const PopupMenuItem(value: _UserAction.deactivate, child: Text(OpsTexts.deactivate)),
                          if (!user.active)
                            const PopupMenuItem(value: _UserAction.activate, child: Text(OpsTexts.activate)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _run(BuildContext context, StaffUser user, _UserAction action) async {
    final cubit = context.read<UserListCubit>();
    final users = context.read<UserRepository>();
    String? message;
    try {
      switch (action) {
        case _UserAction.edit:
          if (await showEditUserDialog(context, user) != null) message = OpsTexts.userSaved;
        case _UserAction.resetPassword:
          if (await showResetPasswordDialog(context, user)) message = OpsTexts.passwordReset;
        case _UserAction.deactivate:
          if (await _confirm(context, OpsTexts.deactivateTitle, OpsTexts.deactivateMessage(user.displayName))) {
            await users.deactivate(user.id);
            message = OpsTexts.userDeactivated;
          }
        case _UserAction.activate:
          await users.activate(user.id);
          message = OpsTexts.userActivated;
      }
    } on ApiException catch (error) {
      message = error.message;
    }
    if (message == null || !context.mounted) return;
    _notify(context, message);
    await cubit.load();
  }

  static Future<bool> _confirm(BuildContext context, String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(CoreTexts.cancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(OpsTexts.deactivate)),
          ],
        ),
      ) ??
      false;
}
