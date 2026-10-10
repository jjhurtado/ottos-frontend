import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/courier_texts.dart';
import '../app/router.dart';

/// App bar with the account menu and bottom navigation between the courier's sections.
class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canSeeCash = context.select((AuthBloc bloc) => bloc.state.user?.can(Permissions.cashReadOwn) ?? false);
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final onCash = location == Routes.cash;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(onCash ? CourierTexts.myCash : CourierTexts.myRemittances),
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
                value: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text(CoreTexts.logout),
                ),
              ),
            ],
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: canSeeCash
          ? NavigationBar(
              selectedIndex: onCash ? 1 : 0,
              onDestinationSelected: (index) => context.go(index == 1 ? Routes.cash : Routes.assigned),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.local_shipping_outlined),
                  selectedIcon: Icon(Icons.local_shipping),
                  label: CourierTexts.myRemittances,
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: CourierTexts.myCash,
                ),
              ],
            )
          : null,
    );
  }
}
