import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/courier_texts.dart';
import '../app/router.dart';
import '../offline/sync_bar.dart';
import '../offline/sync_cubit.dart';

/// App bar with the account menu and bottom navigation between the courier's sections.
class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  /// Their own cash (couriers) or the couriers' cash (sales).
  static bool canSeeCash(CurrentUser user) => user.can(Permissions.cashReadOwn) || user.can(Permissions.cashRead);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final canSeeCash = user != null && CourierShell.canSeeCash(user);
    // Sales see every open remittance; couriers, theirs.
    final remittancesTitle = user != null && !user.can(Permissions.remittancesReadAssigned)
        ? CourierTexts.remittances
        : CourierTexts.myRemittances;
    final cashTitle = user != null && !user.can(Permissions.cashReadOwn) ? CourierTexts.cash : CourierTexts.myCash;
    final onCash = location == Routes.cash;
    final sync = context.syncCubit;
    final version = context.read<AppConfig>().version;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(onCash ? cashTitle : remittancesTitle),
            if (user != null)
              Text(
                user.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          PopupMenuButton<VoidCallback>(
            tooltip: CourierTexts.account,
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              if (user != null)
                PopupMenuItem(
                  enabled: false,
                  child: ListTile(contentPadding: EdgeInsets.zero, title: Text(user.name), subtitle: Text(user.email)),
                ),
              PopupMenuItem(
                value: () => showChangePasswordDialog(context),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.password),
                  title: Text(CoreTexts.changePassword),
                ),
              ),
              PopupMenuItem(
                value: () => _logout(context, sync),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text(CoreTexts.logout),
                ),
              ),
              if (version != null) ...[const PopupMenuDivider(), VersionMenuItem(label: CourierTexts.version(version))],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (sync != null) SyncBar(sync: sync),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: canSeeCash
          ? NavigationBar(
              selectedIndex: onCash ? 1 : 0,
              onDestinationSelected: (index) => context.go(index == 1 ? Routes.cash : Routes.assigned),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.local_shipping_outlined),
                  selectedIcon: const Icon(Icons.local_shipping),
                  label: remittancesTitle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: cashTitle,
                ),
              ],
            )
          : null,
    );
  }

  /// Unsent actions are lost on logout (only this user can send them): warn first.
  static Future<void> _logout(BuildContext context, SyncCubit? sync) async {
    final auth = context.read<AuthBloc>();
    final pending = sync?.state.pending ?? 0;
    if (pending > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(CoreTexts.logout),
          content: Text(CourierTexts.unsentOnLogout(pending)),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(CoreTexts.cancel)),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: OttosColors.danger),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(CourierTexts.logoutAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    auth.add(const AuthLogoutRequested());
  }
}
