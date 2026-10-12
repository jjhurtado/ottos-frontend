import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../notifications/notifier.dart';
import '../offline/offline_store.dart';
import '../offline/session_scope.dart';
import 'courier_texts.dart';
import 'router.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({super.key, required this.config, this.store, this.notifier});

  final AppConfig config;

  /// The phone's storage for working offline; null in tests.
  final OfflineStore? store;

  /// The phone's notifications; null in tests.
  final LocalNotifier? notifier;

  /// Couriers and, during the day, sales: whoever sees their assigned
  /// remittances or every remittance.
  static bool canUseApp(CurrentUser user) =>
      user.can(Permissions.remittancesReadAssigned) || user.can(Permissions.remittancesRead);

  @override
  Widget build(BuildContext context) {
    return OttosScope(
      config: config,
      accessPolicy: canUseApp,
      child: _CourierRouterApp(store: store, notifier: notifier),
    );
  }
}

class _CourierRouterApp extends StatefulWidget {
  const _CourierRouterApp({required this.store, required this.notifier});

  final OfflineStore? store;
  final LocalNotifier? notifier;

  @override
  State<_CourierRouterApp> createState() => _CourierRouterAppState();
}

class _CourierRouterAppState extends State<_CourierRouterApp> {
  late final GoRouter _router = buildRouter(context.read<AuthBloc>());
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    final notifier = widget.notifier;
    if (notifier == null) return;
    notifier.onOpen = _open;
    // Launched by tapping a notification: open it once the session is back.
    if (notifier.launchedFromNotice) {
      final id = notifier.launchRemittanceId;
      final authBloc = context.read<AuthBloc>();
      if (authBloc.state.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(id));
      } else {
        _auth = authBloc.stream.where((state) => state.isAuthenticated).take(1).listen((_) => _open(id));
      }
    }
  }

  void _open(String? remittanceId) {
    if (!context.read<AuthBloc>().state.isAuthenticated) return;
    if (remittanceId == null) {
      _router.go(Routes.assigned);
    } else {
      unawaited(_router.push(Routes.remittance(remittanceId)));
    }
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    widget.notifier?.onOpen = null;
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: CourierTexts.appTitle,
      debugShowCheckedModeBanner: false,
      theme: OttosTheme.light(),
      locale: OttosLocalization.locale,
      supportedLocales: OttosLocalization.supportedLocales,
      localizationsDelegates: OttosLocalization.delegates,
      routerConfig: _router,
      builder: (context, child) => SessionScope(store: widget.store, notifier: widget.notifier, child: child!),
    );
  }
}
