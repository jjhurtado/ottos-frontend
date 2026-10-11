import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import 'offline_store.dart';
import 'remittance_source.dart';
import 'sync_cubit.dart';

/// Gives the logged-in user's screens their [RemittanceSource]: couriers work
/// from the phone and sync, sales straight against the server.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.store, required this.child});

  /// Null where there is no storage (tests): everything goes online.
  final OfflineStore? store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    if (user == null) return child;
    // A new scope per user: nothing of the previous one carries over.
    return _UserScope(key: ValueKey(user.id), user: user, store: store, child: child);
  }
}

class _UserScope extends StatefulWidget {
  const _UserScope({super.key, required this.user, required this.store, required this.child});

  final CurrentUser user;
  final OfflineStore? store;
  final Widget child;

  @override
  State<_UserScope> createState() => _UserScopeState();
}

class _UserScopeState extends State<_UserScope> with WidgetsBindingObserver {
  SyncCubit? _sync;
  late final RemittanceSource _source;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    final courier = widget.user.can(Permissions.remittancesReadAssigned);
    if (store != null && courier) {
      final sync = _sync = SyncCubit(store: store, sync: context.read<SyncRepository>());
      _source = OfflineSource(sync: sync);
      unawaited(sync.start(widget.user.id));
      // When the network comes back, send what waited.
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (!results.contains(ConnectivityResult.none)) unawaited(sync.sync());
      });
      WidgetsBinding.instance.addObserver(this);
    } else {
      _source = OnlineSource(remittances: context.read<RemittanceRepository>(), onlyMine: courier);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync?.sync());
  }

  @override
  void dispose() {
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
