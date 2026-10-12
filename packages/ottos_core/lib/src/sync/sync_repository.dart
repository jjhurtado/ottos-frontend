import 'dart:math';

import '../api/api_client.dart';
import 'sync_models.dart';

/// Offline sync of the mobile app (`/sync`): download what changed and send
/// the queued actions in batches.
class SyncRepository {
  SyncRepository({required this._api});

  final ApiClient _api;

  /// The backend rejects longer batches; longer queues go in several.
  static const maxBatch = 200;

  /// A new action id (UUID v4); generated once and kept with the action.
  static String newActionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Everything without [since]; with it, only what changed since that server time.
  Future<SyncState> state({String? since}) async =>
      SyncState.fromJson(await _api.get<Map<String, dynamic>>('/sync/state', query: {'since': since}));

  /// Sends up to [maxBatch] actions, applied in order. One result per action, same order.
  Future<SyncResponse> send(List<SyncAction> actions, {String? deviceId}) async {
    assert(actions.length <= maxBatch, 'split the queue in batches of $maxBatch');
    return SyncResponse.fromJson(
      await _api.post<Map<String, dynamic>>(
        '/sync/actions',
        body: {
          'deviceId': ?deviceId,
          'actions': [for (final action in actions) action.toJson()],
        },
      ),
    );
  }
}
