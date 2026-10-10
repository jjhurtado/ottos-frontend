import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import 'ops_texts.dart';

/// A section of the panel. It is shown only to users with any of [permissions].
class Destination {
  const Destination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.permissions = const [],
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Empty means every user of the panel.
  final List<String> permissions;

  bool isVisibleTo(CurrentUser user) => permissions.isEmpty || user.canAny(permissions);
}

abstract final class Destinations {
  static const home = Destination(path: '/', label: OpsTexts.home, icon: Icons.home_outlined, selectedIcon: Icons.home);
  static const remittances = Destination(
    path: '/remittances',
    label: OpsTexts.remittances,
    icon: Icons.send_outlined,
    selectedIcon: Icons.send,
    permissions: [Permissions.remittancesRead],
  );
  static const customers = Destination(
    path: '/customers',
    label: OpsTexts.customers,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    permissions: [Permissions.customersRead],
  );
  static const configuration = Destination(
    path: '/configuration',
    label: OpsTexts.configuration,
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
    permissions: [Permissions.configurationRead],
  );
  static const cash = Destination(
    path: '/cash',
    label: OpsTexts.cash,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    permissions: [Permissions.cashRead],
  );
  static const users = Destination(
    path: '/users',
    label: OpsTexts.users,
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    permissions: [Permissions.usersRead],
  );
  static const roles = Destination(
    path: '/roles',
    label: OpsTexts.roles,
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    permissions: [Permissions.rolesRead],
  );

  static const all = [home, remittances, customers, configuration, cash, users, roles];

  /// Who may use the panel at all: anyone who can see a section besides home.
  static bool canUsePanel(CurrentUser user) => all.skip(1).any((destination) => destination.isVisibleTo(user));

  /// The destination that owns [location] (the longest matching path).
  static Destination? forLocation(String location) {
    Destination? match;
    for (final destination in all) {
      final owns = destination.path == '/'
          ? location == '/'
          : location == destination.path || location.startsWith('${destination.path}/');
      if (owns && (match == null || destination.path.length > match.path.length)) match = destination;
    }
    return match;
  }
}
