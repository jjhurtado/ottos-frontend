import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import 'courier_texts.dart';
import 'router.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({super.key, required this.config});

  final AppConfig config;

  static bool canUseApp(CurrentUser user) => user.can(Permissions.remittancesReadAssigned);

  @override
  Widget build(BuildContext context) {
    return OttosScope(config: config, accessPolicy: canUseApp, child: const _CourierRouterApp());
  }
}

class _CourierRouterApp extends StatefulWidget {
  const _CourierRouterApp();

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
    );
  }
}
