import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/destinations.dart';
import '../app/ops_texts.dart';

/// Frame of the panel: side navigation with the sections the user may see.
/// A rail on wide screens, a drawer on narrow ones.
class OpsShell extends StatelessWidget {
  const OpsShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return const SizedBox.shrink();
    final destinations = Destinations.all.where((destination) => destination.isVisibleTo(user)).toList();
    final current = Destinations.forLocation(location);
    final selectedIndex = current == null ? null : destinations.indexOf(current);
    void select(int index) => context.go(destinations[index].path);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        return Scaffold(
          appBar: wide
              ? null
              : AppBar(
                  title: Text(current?.label ?? OpsTexts.appName),
                  actions: [_UserMenu(user: user)],
                ),
          drawer: wide
              ? null
              : NavigationDrawer(
                  backgroundColor: OttosColors.navy,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    Navigator.of(context).pop();
                    select(index);
                  },
                  children: [
                    const Padding(padding: EdgeInsets.all(16), child: OttosLogo(size: 120)),
                    for (final destination in destinations)
                      NavigationDrawerDestination(
                        icon: Icon(destination.icon, color: OttosColors.cream),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label, style: const TextStyle(color: OttosColors.cream)),
                      ),
                  ],
                ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  minExtendedWidth: 220,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: select,
                  leading: const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: OttosLogo(size: 88)),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _UserMenu(user: user),
                      ),
                    ),
                  ),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.user});

  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.characters.first.toUpperCase();
    final version = context.read<AppConfig>().version;
    return PopupMenuButton<void>(
      tooltip: user.displayName,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(contentPadding: EdgeInsets.zero, title: Text(user.displayName), subtitle: Text(user.email)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => showChangePasswordDialog(context),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.password),
            title: Text(CoreTexts.changePassword),
          ),
        ),
        PopupMenuItem(
          onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text(CoreTexts.logout),
          ),
        ),
        if (version != null) ...[const PopupMenuDivider(), VersionMenuItem(label: OpsTexts.version(version))],
      ],
      child: CircleAvatar(backgroundColor: OttosColors.cream, foregroundColor: OttosColors.navy, child: Text(initial)),
    );
  }
}
