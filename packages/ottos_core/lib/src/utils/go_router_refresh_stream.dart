import 'dart:async';

import 'package:flutter/foundation.dart';

/// Makes go_router re-run its redirect whenever [stream] emits, e.g. on
/// every AuthBloc state change.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
