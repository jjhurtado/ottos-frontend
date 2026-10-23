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

  /// Reports and statistics: only sales (who see every remittance, not just
  /// their assigned ones) with `reports:read`. Never a courier.
  static bool canSeeReports(CurrentUser user) =>
      user.can(Permissions.reportsRead) && !user.can(Permissions.remittancesReadAssigned);

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final canSeeCash = user != null && CourierShell.canSeeCash(user);
    final canSeeReports = user != null && CourierShell.canSeeReports(user);
    // Sales see every open remittance; couriers, theirs.
    final remittancesTitle = user != null && !user.can(Permissions.remittancesReadAssigned)
        ? CourierTexts.remittances
        : CourierTexts.myRemittances;
    final cashTitle = user != null && !user.can(Permissions.cashReadOwn) ? CourierTexts.cash : CourierTexts.myCash;
    final sections = [
      (
        path: Routes.assigned,
        label: remittancesTitle,
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
      ),
      if (canSeeCash)
        (
          path: Routes.cash,
          label: cashTitle,
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
        ),
      if (canSeeReports) ...[
        (path: Routes.reports, label: ReportTexts.reports, icon: Icons.insights_outlined, selectedIcon: Icons.insights),
        (
          path: Routes.statistics,
          label: ReportTexts.statistics,
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
        ),
      ],
    ];
    final selected = sections.indexWhere((section) => section.path == location);
    final current = selected < 0 ? 0 : selected;
    final sync = context.syncCubit;
    final version = context.read<AppConfig>().version;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sections[current].label),
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
      bottomNavigationBar: sections.length > 1
          ? NavigationBar(
              selectedIndex: current,
              onDestinationSelected: (index) => context.go(sections[index].path),
              destinations: [
                for (final section in sections)
                  NavigationDestination(
                    icon: Icon(section.icon),
                    selectedIcon: Icon(section.selectedIcon),
                    label: section.label,
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
