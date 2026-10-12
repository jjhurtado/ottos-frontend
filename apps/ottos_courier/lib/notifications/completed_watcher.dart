import 'package:ottos_core/ottos_core.dart';

/// Asks the server which remittances were completed since the last time, for
/// sales' notifications. The first call only marks where to start: nothing
/// from before is announced.
class CompletedWatcher {
  CompletedWatcher({
    required this._remittances,
    required this._userId,
    required this._onCompleted,
    this._readSince,
    this._saveSince,
  });

  final RemittanceRepository _remittances;
  final String _userId;
  final void Function(List<Remittance> completed) _onCompleted;
  final Future<String?> Function()? _readSince;
  final Future<void> Function(String since)? _saveSince;

  /// Kept here too, for when there is nowhere to save it.
  String? _since;
  Future<void>? _running;

  /// Pages are 100; after days without network, stop after this many in a row.
  static const maxPages = 10;

  Future<void> check() => _running ??= _checkOnce().whenComplete(() => _running = null);

  Future<void> _checkOnce() async {
    final completed = <Remittance>[];
    try {
      var since = _since ??= await _readSince?.call();
      for (var page = 0; page < maxPages; page++) {
        final feed = await _remittances.completed(since: since);
        since = _since = feed.serverTime;
        await _saveSince?.call(feed.serverTime);
        completed.addAll(feed.remittances);
        if (!feed.hasMore) break;
      }
    } on ApiException {
      // No network or no permission: try again on the next check.
    }
    // Your own deliveries need no notice.
    final others = completed.where((remittance) => remittance.courierId != _userId).toList();
    if (others.isNotEmpty) _onCompleted(others);
  }
}
