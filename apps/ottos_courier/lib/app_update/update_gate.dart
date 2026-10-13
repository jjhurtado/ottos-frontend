import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../offline/sync_cubit.dart';
import 'app_update_cubit.dart';

/// Over the whole app: a screen that cannot be closed when this build must be
/// updated, and a notice that can be when a newer one exists. The app stays
/// underneath, so what is waiting to be sent still syncs.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppUpdateCubit>().check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppUpdateCubit>().check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _flushed = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AppUpdateCubit>();
    final version = cubit.state.version;
    if (cubit.update == AppUpdate.required && !_flushed) {
      _flushed = true;
      // The backend still takes what was done offline: send it before stopping.
      final sync = context.read<SyncCubit?>();
      if (sync != null) unawaited(sync.sync());
    }
    return Stack(
      children: [
        widget.child,
        if (version != null && cubit.update == AppUpdate.required)
          Positioned.fill(child: _UpdateRequired(version: version))
        else if (version != null && cubit.update == AppUpdate.available && !cubit.state.dismissed)
          Positioned(
            left: 12,
            right: 12,
            bottom: 96,
            child: SafeArea(
              child: _UpdateAvailable(version: version, onLater: cubit.dismiss),
            ),
          ),
      ],
    );
  }
}

/// Where the new version is installed from: the backend's link or, while it has
/// none, the store page (Play Store on Android, the TestFlight app on iPhone).
@visibleForTesting
String updateUrl(AppVersion version, {TargetPlatform? platform}) =>
    version.downloadUrl ??
    switch (platform ?? defaultTargetPlatform) {
      // TestFlight for now; the App Store link once the app is published there (roadmap.md).
      TargetPlatform.iOS => 'itms-beta://',
      _ => 'https://play.google.com/store/apps/details?id=com.remesadeotto.ottos',
    };

Future<void> _update(AppVersion version) =>
    launchUrl(Uri.parse(updateUrl(version)), mode: LaunchMode.externalApplication);

class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.version});

  final AppVersion version;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.system_update, size: 64),
              const SizedBox(height: 24),
              Text(CoreTexts.updateRequiredTitle, style: textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(CoreTexts.updateRequiredBody, textAlign: TextAlign.center),
              if (version.latestVersion != null) ...[
                const SizedBox(height: 8),
                Text(CoreTexts.newVersion(version.latestVersion!), textAlign: TextAlign.center),
              ],
              if (version.notes != null && version.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(version.notes!, textAlign: TextAlign.center, style: textTheme.bodySmall),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => _update(version),
                icon: const Icon(Icons.system_update),
                label: const Text(CoreTexts.update),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateAvailable extends StatelessWidget {
  const _UpdateAvailable({required this.version, required this.onLater});

  final AppVersion version;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CoreTexts.updateAvailable, style: Theme.of(context).textTheme.titleSmall),
            if (version.latestVersion != null) Text(CoreTexts.newVersion(version.latestVersion!)),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(onPressed: onLater, child: const Text(CoreTexts.later)),
                  FilledButton(onPressed: () => _update(version), child: const Text(CoreTexts.update)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
