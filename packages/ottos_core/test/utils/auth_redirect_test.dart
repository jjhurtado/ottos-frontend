import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

const _user = CurrentUser(id: 'u1', email: 'a@ottos.test', name: '', type: '', roles: [], permissions: {});

void main() {
  late ValueNotifier<AuthState> auth;
  late GoRouter router;

  String location() => router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> pumpRouter(WidgetTester tester, String initialLocation) {
    router = GoRouter(
      initialLocation: initialLocation,
      refreshListenable: auth,
      redirect: (_, state) => authRedirect(auth.value, state, home: '/'),
      routes: [
        for (final path in ['/', '/splash', '/login', '/remittances/:id'])
          GoRoute(path: path, builder: (_, _) => Text(path)),
      ],
    );
    addTearDown(router.dispose);
    return tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  setUp(() => auth = ValueNotifier(const AuthState.unknown()));

  testWidgets('returns to the requested page once the session is restored', (tester) async {
    await pumpRouter(tester, '/remittances/r1?tab=history');
    expect(location(), '/splash?from=%2Fremittances%2Fr1%3Ftab%3Dhistory');

    auth.value = const AuthState.authenticated(_user);
    await tester.pumpAndSettle();

    expect(location(), '/remittances/r1?tab=history');
  });

  testWidgets('keeps the requested page through login', (tester) async {
    await pumpRouter(tester, '/remittances/r1');

    auth.value = const AuthState.unauthenticated();
    await tester.pumpAndSettle();
    expect(location(), '/login?from=%2Fremittances%2Fr1');

    auth.value = const AuthState.authenticated(_user);
    await tester.pumpAndSettle();
    expect(location(), '/remittances/r1');
  });

  testWidgets('goes home when home was requested', (tester) async {
    await pumpRouter(tester, '/');
    expect(location(), '/splash');

    auth.value = const AuthState.authenticated(_user);
    await tester.pumpAndSettle();

    expect(location(), '/');
  });

  testWidgets('ignores a target that is not an app path', (tester) async {
    auth.value = const AuthState.authenticated(_user);
    await pumpRouter(tester, '/login?from=https://evil.test');
    await tester.pumpAndSettle();

    expect(location(), '/');
  });
}
