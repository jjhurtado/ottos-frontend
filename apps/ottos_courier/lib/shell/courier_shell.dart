import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/courier_texts.dart';
import '../app/router.dart';

/// App bar with logout and bottom navigation between the courier's sections.
class CourierShell extends StatelessWidget {
  const CourierShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canSeeCash = context.select((AuthBloc bloc) => bloc.state.user?.can(Permissions.cashReadOwn) ?? false);
    final onCash = location == Routes.cash;
    return Scaffold(
      appBar: AppBar(
        title: Text(onCash ? CourierTexts.myCash : CourierTexts.myRemittances),
        actions: [
          IconButton(
            tooltip: CoreTexts.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
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
