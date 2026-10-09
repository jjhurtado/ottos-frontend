import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../features/coming_soon/coming_soon_page.dart';
import '../features/home/view/home_page.dart';
import '../features/remittances/view/remittance_detail_page.dart';
import '../features/remittances/view/remittance_list_page.dart';
import '../shell/ops_shell.dart';
import 'destinations.dart';
import 'ops_texts.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  static String remittance(String id) => '${Destinations.remittances.path}/$id';
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: Destinations.home.path,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final location = state.matchedLocation;
      if (auth.status == AuthStatus.unknown) return location == Routes.splash ? null : Routes.splash;
      if (!auth.isAuthenticated) return location == Routes.login ? null : Routes.login;
      if (location == Routes.login || location == Routes.splash) return Destinations.home.path;
      // Permission guard: sections the user cannot see send them home.
      final destination = Destinations.forLocation(location);
      if (destination != null && !destination.isVisibleTo(auth.user!)) return Destinations.home.path;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const LoginPage(appName: OpsTexts.appName),
      ),
      ShellRoute(
        builder: (context, state, child) => OpsShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: Destinations.home.path, builder: (_, _) => const HomePage()),
          GoRoute(
            path: Destinations.remittances.path,
            builder: (_, state) => RemittanceListPage(initialFilter: _filterFrom(state.uri.queryParameters)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => RemittanceDetailPage(remittanceId: state.pathParameters['id']!),
              ),
            ],
          ),
          for (final destination in [
            Destinations.customers,
            Destinations.rates,
            Destinations.cash,
            Destinations.users,
            Destinations.roles,
          ])
            GoRoute(
              path: destination.path,
              builder: (_, _) => ComingSoonPage(title: destination.label),
            ),
        ],
      ),
    ],
  );
}

/// Lets other screens link to a filtered list, e.g. `/remittances?late=true`.
RemittanceFilter _filterFrom(Map<String, String> query) =>
    RemittanceFilter(status: query['status'], late: query['late'] == 'true' ? true : null);
