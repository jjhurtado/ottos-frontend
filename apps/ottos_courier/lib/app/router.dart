import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../features/assigned/view/assigned_page.dart';
import '../features/cash/view/cash_page.dart';
import '../features/cash/view/courier_cash_page.dart';
import '../features/new_remittance/view/new_remittance_page.dart';
import '../features/remittance/view/remittance_page.dart';
import '../shell/courier_shell.dart';
import 'courier_texts.dart';
import 'device_biometrics.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const assigned = '/';
  static const cash = '/cash';

  static const newRemittance = '/remittances/new';

  static String remittance(String id) => '/remittances/$id';

  /// A courier's balances and movements, for who manages the couriers' cash.
  static String courierCash(String courierId) => '/cash/couriers/$courierId';
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: Routes.assigned,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final sessionRedirect = authRedirect(
        auth,
        state,
        home: Routes.assigned,
        splash: Routes.splash,
        login: Routes.login,
      );
      if (sessionRedirect != null || !auth.isAuthenticated) return sessionRedirect;
      final user = auth.user!;
      if (state.matchedLocation == Routes.cash && !CourierShell.canSeeCash(user)) return Routes.assigned;
      if (state.matchedLocation.startsWith('${Routes.cash}/couriers/') && !user.can(Permissions.cashRead)) {
        return Routes.cash;
      }
      if (state.matchedLocation == Routes.newRemittance && !user.can(Permissions.remittancesCreate)) {
        return Routes.assigned;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => LoginPage(appName: CourierTexts.appName, biometrics: DeviceBiometrics()),
      ),
      ShellRoute(
        builder: (context, state, child) => CourierShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.assigned, builder: (_, _) => const AssignedPage()),
          GoRoute(path: Routes.cash, builder: (_, _) => const CashPage()),
        ],
      ),
      // Before '/remittances/:id', which would take 'new' as an id.
      GoRoute(path: Routes.newRemittance, builder: (_, _) => const NewRemittancePage()),
      GoRoute(
        path: '/cash/couriers/:id',
        builder: (_, state) => CourierCashPage(courierId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/remittances/:id',
        builder: (_, state) => RemittancePage(remittanceId: state.pathParameters['id']!),
      ),
    ],
  );
}
