import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../notifications/completed_watcher.dart';
import '../notifications/notices.dart';
import '../notifications/notifier.dart';
import 'offline_store.dart';
import 'remittance_source.dart';
import 'sync_cubit.dart';

/// Gives the logged-in user's screens their [RemittanceSource]: couriers work
/// from the phone and sync, sales straight against the server.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.store, this.notifier, required this.child});

  /// Null where there is no storage (tests): everything goes online.
  final OfflineStore? store;

  /// Null where there are no notifications (tests).
  final Notifier? notifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return child;
    // A new scope per user: nothing of the previous one carries over.
    return _UserScope(key: ValueKey(user.id), user: user, store: store, notifier: notifier, child: child);
  }
}

class _UserScope extends StatefulWidget {
  const _UserScope({super.key, required this.user, required this.store, required this.notifier, required this.child});

  final CurrentUser user;
  final OfflineStore? store;
  final Notifier? notifier;
  final Widget child;

  @override
  State<_UserScope> createState() => _UserScopeState();
}

class _UserScopeState extends State<_UserScope> with WidgetsBindingObserver {
  SyncCubit? _sync;
  CompletedWatcher? _completed;
  late final RemittanceSource _source;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _timer;

  /// How often the open app asks the server, for the notifications.
  static const checkEvery = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    final notifier = widget.notifier;
    final user = widget.user;
    final courier = user.can(Permissions.remittancesReadAssigned);
    if (store != null && courier) {
      final sync = _sync = SyncCubit(
        store: store,
        sync: context.read<SyncRepository>(),
        onNewRemittances: notifier == null
            ? null
            : (remittances) {
                // Nothing to announce about the ones this user just created.
                final others = remittances.where((remittance) => remittance.createdBy != user.id).toList();
                unawaited(notifier.show(newRemittanceNotices(others)));
              },
      );
      _source = OfflineSource(sync: sync);
      unawaited(sync.start(user.id));
    } else {
      _source = OnlineSource(remittances: context.read<RemittanceRepository>(), onlyMine: courier);
    }
    // Sales hear about every delivery and pickup that a courier completes.
    if (notifier != null && user.can(Permissions.remittancesRead)) {
      final key = 'completedSince.${user.id}';
      final watcher = _completed = CompletedWatcher(
        remittances: context.read<RemittanceRepository>(),
        userId: user.id,
        onCompleted: (remittances) => unawaited(notifier.show(completedNotices(remittances))),
        readSince: store == null ? null : () => store.setting(key),
        saveSince: store == null ? null : (since) => store.saveSetting(key, since),
      );
      unawaited(watcher.check());
    }
    if (notifier != null && (_sync != null || _completed != null)) unawaited(notifier.requestPermission());
    // When the network comes back, send what waited and look for news.
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) _check();
    });
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _check() {
    unawaited(_sync?.sync());
    unawaited(_completed?.check());
  }

  void _startTimer() {
    _timer?.cancel();
    if (_sync == null && _completed == null) return;
    _timer = Timer.periodic(checkEvery, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      // In the background the system would stop it anyway; save the battery.
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivity?.cancel());
    unawaited(_sync?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = _sync;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RemittanceSource>.value(value: _source),
        // Nullable, so screens can tell whether this user syncs.
        RepositoryProvider<SyncCubit?>.value(value: sync),
      ],
      child: widget.child,
    );
  }
}
