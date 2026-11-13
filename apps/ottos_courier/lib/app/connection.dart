import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network; injected so tests can say.
typedef ConnectionCheck = Future<bool> Function();

/// True unless the phone reports no network at all; a network without
/// internet still fails on the call, with the API's network error.
Future<bool> phoneHasNetwork() async => !(await Connectivity().checkConnectivity()).contains(ConnectivityResult.none);
