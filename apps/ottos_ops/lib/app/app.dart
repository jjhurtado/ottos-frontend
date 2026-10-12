import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import 'destinations.dart';
import 'ops_texts.dart';
import 'router.dart';

class OpsApp extends StatelessWidget {
  const OpsApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return OttosScope(config: config, accessPolicy: Destinations.canUsePanel, child: const _OpsRouterApp());
  }
}

class _OpsRouterApp extends StatefulWidget {
  const _OpsRouterApp();

  @override
  State<_OpsRouterApp> createState() => _OpsRouterAppState();
}

class _OpsRouterAppState extends State<_OpsRouterApp> {
  late final GoRouter _router = buildRouter(context.read<AuthBloc>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: OpsTexts.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _withBundledFont(OttosTheme.light()),
      locale: OttosLocalization.locale,
      supportedLocales: OttosLocalization.supportedLocales,
      localizationsDelegates: OttosLocalization.delegates,
      routerConfig: _router,
    );
  }
}

/// The panel's text in the Roboto bundled with it, whatever the visitor's
/// system: on the web Flutter would ask for Segoe UI or the Mac's font and
/// fall back to another one.
ThemeData _withBundledFont(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
  primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
);
