import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../features/audit/view/audit_page.dart';
import '../features/cash/view/cash_page.dart';
import '../features/cash/view/courier_cash_page.dart';
import '../features/customers/view/customer_detail_page.dart';
import '../features/customers/view/customer_list_page.dart';
import '../features/home/view/home_page.dart';
import '../features/configuration/view/configuration_page.dart';
import '../features/reports/view/reports_page.dart';
import '../features/remittances/view/new_remittance_page.dart';
import '../features/remittances/view/remittance_detail_page.dart';
import '../features/remittances/view/remittance_list_page.dart';
import '../features/roles/view/roles_page.dart';
import '../features/users/view/user_list_page.dart';
import '../shell/ops_shell.dart';
import 'destinations.dart';
import 'ops_texts.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  static final newRemittance = '${Destinations.remittances.path}/new';

  static String remittance(String id) => '${Destinations.remittances.path}/$id';

  /// The new remittance form with [customerId] already chosen.
  static String newRemittanceFor(String customerId) => '$newRemittance?customerId=$customerId';

  /// The remittance list filtered by sender.
  static String remittancesOf(String customerId) => '${Destinations.remittances.path}?customerId=$customerId';

  static String customer(String id) => '${Destinations.customers.path}/$id';

  static String courierCash(String courierId) => '${Destinations.cash.path}/couriers/$courierId';
}

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: Destinations.home.path,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final auth = authBloc.state;
      final sessionRedirect = authRedirect(
        auth,
        state,
        home: Destinations.home.path,
        splash: Routes.splash,
        login: Routes.login,
      );
      if (sessionRedirect != null || !auth.isAuthenticated) return sessionRedirect;
      // Permission guard: sections the user cannot see send them home.
      final destination = Destinations.forLocation(state.matchedLocation);
      if (destination != null && !destination.isVisibleTo(auth.user!)) return Destinations.home.path;
      if (state.matchedLocation == Routes.newRemittance && !auth.user!.can(Permissions.remittancesCreate)) {
        return Destinations.remittances.path;
      }
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
              // Before ':id', which would otherwise match "new".
              GoRoute(
                path: 'new',
                builder: (_, state) => NewRemittancePage(initialCustomerId: state.uri.queryParameters['customerId']),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => RemittanceDetailPage(remittanceId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Destinations.customers.path,
            builder: (_, _) => const CustomerListPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => CustomerDetailPage(customerId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Destinations.cash.path,
            builder: (_, _) => const CashPage(),
            routes: [
              GoRoute(
                path: 'couriers/:id',
                builder: (_, state) => CourierCashPage(courierId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: Destinations.configuration.path, builder: (_, _) => const ConfigurationPage()),
          GoRoute(path: Destinations.users.path, builder: (_, _) => const UserListPage()),
          GoRoute(path: Destinations.roles.path, builder: (_, _) => const RolesPage()),
          GoRoute(path: Destinations.audit.path, builder: (_, _) => const AuditPage()),
          GoRoute(path: Destinations.reports.path, builder: (_, _) => const ReportsPage()),
        ],
      ),
    ],
  );
}

/// Lets other screens link to a filtered list, e.g. `/remittances?late=true` or `?incident=true`.
RemittanceFilter _filterFrom(Map<String, String> query) => RemittanceFilter(
  status: query['status'],
  late: query['late'] == 'true' ? true : null,
  incident: query['incident'] == 'true' ? true : null,
  review: query['review'] == 'true' ? true : null,
  customerId: query['customerId'],
);
