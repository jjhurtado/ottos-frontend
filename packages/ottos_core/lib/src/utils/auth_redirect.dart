import 'package:go_router/go_router.dart';

import '../auth/bloc/auth_bloc.dart';

/// Session part of a router's `redirect`: sends the user to [splash] while the
/// session is being restored and to [login] when there is none, keeping the
/// page they asked for in `?from=` so they land on it afterwards (e.g. after
/// reloading a detail page) instead of on [home].
///
/// Returns null when the user may stay where they are; permission guards go
/// after it.
String? authRedirect(
  AuthState auth,
  GoRouterState state, {
  required String home,
  String splash = '/splash',
  String login = '/login',
}) {
  final location = state.matchedLocation;
  final onEntryPage = location == splash || location == login;
  // Entry pages carry the target along; any other page is the target.
  final from = onEntryPage ? state.uri.queryParameters['from'] : state.uri.toString();
  final target = from != null && from.startsWith('/') && from != home ? from : null;

  String entry(String path) => target == null ? path : Uri(path: path, queryParameters: {'from': target}).toString();

  if (auth.status == AuthStatus.unknown) return location == splash ? null : entry(splash);
  if (!auth.isAuthenticated) return location == login ? null : entry(login);
  if (onEntryPage) return target ?? home;
  return null;
}
