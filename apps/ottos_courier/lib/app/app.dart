import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../offline/offline_store.dart';
import '../offline/session_scope.dart';
import 'courier_texts.dart';
import 'router.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({super.key, required this.config, this.store});

  final AppConfig config;

  /// The phone's storage for working offline; null in tests.
  final OfflineStore? store;

  /// Couriers and, during the day, sales: whoever sees their assigned
  /// remittances or every remittance.
  static bool canUseApp(CurrentUser user) =>
      user.can(Permissions.remittancesReadAssigned) || user.can(Permissions.remittancesRead);

  @override
  Widget build(BuildContext context) {
    return OttosScope(
      config: config,
      accessPolicy: canUseApp,
      child: _CourierRouterApp(store: store),
    );
  }
}

class _CourierRouterApp extends StatefulWidget {
  const _CourierRouterApp({required this.store});

  final OfflineStore? store;

  @override
  State<_CourierRouterApp> createState() => _CourierRouterAppState();
}

class _CourierRouterAppState extends State<_CourierRouterApp> {
  late final GoRouter _router = buildRouter(context.read<AuthBloc>());

  @override
  void dispose() {
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
      builder: (context, child) => SessionScope(store: widget.store, child: child!),
    );
  }
}
