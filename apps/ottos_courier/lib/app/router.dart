import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../features/assigned/view/assigned_page.dart';
import '../features/cash/view/cash_page.dart';
import '../features/remittance/view/remittance_page.dart';
import '../shell/courier_shell.dart';
import 'courier_texts.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const assigned = '/';
  static const cash = '/cash';

  static String remittance(String id) => '/remittances/$id';
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
      if (state.matchedLocation == Routes.cash && !auth.user!.can(Permissions.cashReadOwn)) return Routes.assigned;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginPage(appName: CourierTexts.appName),
      ),
      ShellRoute(
        builder: (context, state, child) => CourierShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Routes.assigned, builder: (_, _) => const AssignedPage()),
          GoRoute(path: Routes.cash, builder: (_, _) => const CashPage()),
        ],
      ),
      GoRoute(
        path: '/remittances/:id',
        builder: (_, state) => RemittancePage(remittanceId: state.pathParameters['id']!),
      ),
    ],
  );
}
