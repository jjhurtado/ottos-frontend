import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import 'offline_store.dart';

/// What happened to an action the courier just did.
sealed class ActionOutcome {
  const ActionOutcome();
}

/// The server applied it; [remittance] is how it is now.
final class Applied extends ActionOutcome {
  const Applied(this.remittance, {this.flaggedForReview = false});

  final Remittance? remittance;
  final bool flaggedForReview;
}

/// No network: kept on the phone, sent when it comes back.
final class Queued extends ActionOutcome {
  const Queued();
}

/// The server said no, e.g. a wrong PIN while online.
final class Rejected extends ActionOutcome {
  const Rejected(this.message);

  final String message;
}

final class SyncStatus extends Equatable {
  const SyncStatus({
    this.pending = 0,
    this.rejected = const [],
    this.lastSync,
    this.syncing = false,
    this.offline = false,
    this.revision = 0,
  });

  /// Actions waiting to be sent.
  final int pending;

  /// Actions the server refused, until the courier dismisses them.
  final List<RejectedAction> rejected;
  final DateTime? lastSync;
  final bool syncing;

  /// The last attempt could not reach the server.
  final bool offline;

  /// Grows whenever the stored data changes, so the screens reload.
  final int revision;

  SyncStatus copyWith({
    int? pending,
    List<RejectedAction>? rejected,
    DateTime? lastSync,
    bool? syncing,
    bool? offline,
    int? revision,
  }) => SyncStatus(
    pending: pending ?? this.pending,
    rejected: rejected ?? this.rejected,
    lastSync: lastSync ?? this.lastSync,
    syncing: syncing ?? this.syncing,
    offline: offline ?? this.offline,
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [pending, rejected.length, lastSync, syncing, offline, revision];
}

/// Keeps the phone and the server in step: sends the queue in order, then
/// downloads what changed. Without network everything stays queued.
class SyncCubit extends Cubit<SyncStatus> {
  SyncCubit({required this._store, required this._sync, this._onNewRemittances}) : super(const SyncStatus());

  final OfflineStore _store;
  final SyncRepository _sync;

  /// Remittances that came in a download and the phone did not have, for the
  /// notifications. Not on the first download: that is everything already open.
  final void Function(List<Remittance> remittances)? _onNewRemittances;
  Future<void>? _running;

  OfflineStore get store => _store;

  /// For [userId]: another user's data never shows; then syncs.
  Future<void> start(String userId) async {
    await _store.useFor(userId);
    await _refresh(changed: true);
    await sync();
  }

  /// Sends what is pending and downloads the changes. Calls made while one
  /// runs wait for it instead of starting another.
  Future<void> sync() => _running ??= _syncOnce().whenComplete(() => _running = null);

  Future<void> _syncOnce() async {
    if (isClosed) return;
    emit(state.copyWith(syncing: true));
    var offline = false;
    try {
      await _sendPending();
      final since = await _store.serverTime();
      final known = {for (final json in await _store.remittances()) json['id']};
      final downloaded = await _sync.state(since: since);
      await _store.applyState(downloaded);
      final arrived = [
        for (final json in downloaded.remittances)
          if (!known.contains(json['id'])) Remittance.fromJson(json),
      ].where((remittance) => !remittance.isCompleted).toList();
      if (since != null && arrived.isNotEmpty) _onNewRemittances?.call(arrived);
    } on ApiException catch (error) {
      offline = error.statusCode == null;
    }
    if (isClosed) return;
    emit(state.copyWith(syncing: false, offline: offline));
    await _refresh(changed: true);
  }

  Future<void> _sendPending() async {
    var pending = await _store.pending();
    while (pending.isNotEmpty) {
      final batch = pending.take(SyncRepository.maxBatch).toList();
      final response = await _sync.send(batch);
      for (final result in response.results) {
        await _apply(result);
      }
      // Only retryable ones are left; try them on the next sync, not in a loop.
      if (response.results.every((result) => !result.done && result.retryable)) return;
      pending = (await _store.pending()).where((action) => !batch.any((sent) => sent.id == action.id)).toList();
    }
  }

  Future<void> _apply(SyncResult result) async {
    if (result.done) {
      await _store.done(result.id);
      await _keep(result.remittance);
    } else if (!result.retryable) {
      await _store.reject(result.id, code: result.code, message: _message(result));
    }
  }

  /// Keeps the remittance as the server returned it; a completed one leaves the phone.
  Future<void> _keep(Map<String, dynamic>? json) async {
    if (json == null) return;
    final remittance = Remittance.fromJson(json);
    if (remittance.isCompleted) {
      await _store.removeRemittance(remittance.id);
    } else {
      await _store.putRemittance(json);
    }
  }

  static String _message(SyncResult result) =>
      CoreTexts.errorCodes[result.code] ?? result.message ?? CoreTexts.unexpectedError;

  /// Does [action] now if possible. With network and nothing queued before it,
  /// it goes straight to the server, checking the PIN strictly; otherwise it
  /// joins the queue, after the ones before it.
  Future<ActionOutcome> perform(SyncAction action) async {
    await _running;
    if ((await _store.pending()).isNotEmpty) return _enqueueAndSync(action);
    final now = action.type == SyncActionType.deliverWithPin
        ? action.withPayload({...action.payload, 'strictPin': true})
        : action;
    final SyncResponse response;
    try {
      response = await _sync.send([now]);
    } on ApiException catch (error) {
      if (error.statusCode != null) return Rejected(error.message);
      await _store.enqueue(action);
      emit(state.copyWith(offline: true));
      await _refresh(changed: true);
      return const Queued();
    }
    final result = response.results.single;
    if (!result.done) {
      if (result.retryable) return _enqueueAndSync(action);
      return Rejected(_message(result));
    }
    await _keep(result.remittance);
    emit(state.copyWith(offline: false));
    await _refresh(changed: true);
    // The cash moved on the server: bring it (and anything else new) now.
    unawaited(sync());
    final json = result.remittance;
    return Applied(json == null ? null : Remittance.fromJson(json), flaggedForReview: result.flaggedForReview);
  }

  Future<ActionOutcome> _enqueueAndSync(SyncAction action) async {
    await _store.enqueue(action);
    await sync();
    if ((await _store.pending()).any((queued) => queued.id == action.id)) return const Queued();
    final rejected = (await _store.rejected()).where((item) => item.action.id == action.id).firstOrNull;
    if (rejected != null) return Rejected(rejected.message ?? CoreTexts.unexpectedError);
    final remittanceId = action.remittanceId;
    final json = remittanceId == null ? null : await _store.remittance(remittanceId);
    return Applied(json == null ? null : Remittance.fromJson(json));
  }

  /// A currency exchange of the courier's own cash; works offline like the rest.
  Future<ActionOutcome> exchange(ExchangeInput input) => perform(
    SyncAction(
      id: SyncRepository.newActionId(),
      type: SyncActionType.cashExchange,
      occurredAt: DateTime.now(),
      payload: input.toJson(),
    ),
  );

  /// The two movements of a queued exchange: one currency out, the other in.
  static List<CashMovement> _exchangeLegs(SyncAction action) {
    final payload = action.payload;
    final input = ExchangeInput(
      fromCurrency: payload['fromCurrency'] as String,
      fromAmount: (payload['fromAmount'] as num).toDouble(),
      toCurrency: payload['toCurrency'] as String,
      rate: (payload['rate'] as num).toDouble(),
      note: payload['note'] as String?,
    );
    CashMovement leg(String side, CashMovementType type, double signed, String currency) => CashMovement(
      id: '$unsentMovement${action.id}:$side',
      type: type,
      amount: signed.abs(),
      signedAmount: signed,
      currency: currency,
      note: input.note,
      occurredAt: action.occurredAt,
      exchangeId: action.id,
      rate: input.rate,
    );
    return [
      leg('out', CashMovementType.courierExchangeOut, -input.fromAmount, input.fromCurrency),
      leg('in', CashMovementType.courierExchangeIn, input.toAmount, input.toCurrency),
    ];
  }

  /// Prefix of the ids of [cash]'s movements that are not on the server yet.
  static const unsentMovement = 'unsent:';

  static bool isUnsent(CashMovement movement) => movement.id.startsWith(unsentMovement);

  /// The courier's cash as the server last sent it, plus the deliveries and
  /// pickups still in the queue: handing over or collecting the money already
  /// happened, so the balance must show it before it is sent.
  Future<CourierStatement?> cash() async {
    final stored = await _store.cash();
    final unsent = <CashMovement>[];
    for (final action in await _store.pending()) {
      if (action.type == SyncActionType.cashExchange) {
        unsent.addAll(_exchangeLegs(action));
        continue;
      }
      final remittanceId = action.remittanceId;
      if (!action.type.completes || remittanceId == null) continue;
      final json = await _store.remittance(remittanceId);
      if (json == null) continue;
      final remittance = Remittance.fromJson(json);
      final amount = remittance.cashAmount;
      final currency = remittance.cashCurrency;
      if (amount == null || currency == null) continue;
      unsent.add(
        CashMovement(
          id: '$unsentMovement${action.id}',
          type: remittance.isPickup ? CashMovementType.pickupCollection : CashMovementType.deliveryPayout,
          amount: amount,
          // The courier collects on a pickup and pays out on a delivery.
          signedAmount: remittance.isPickup ? amount : -amount,
          currency: currency,
          remittanceId: remittance.id,
          note: remittance.code,
          occurredAt: action.occurredAt,
        ),
      );
    }
    if (stored == null && unsent.isEmpty) return null;
    final base = stored?.cash;
    final totals = {for (final balance in base?.balances ?? const <Balance>[]) balance.currency: balance.amount};
    for (final movement in unsent) {
      totals[movement.currency] = (totals[movement.currency] ?? 0) + movement.signedAmount;
    }
    final balances = [for (final entry in totals.entries) Balance(currency: entry.key, amount: entry.value)];
    return CourierStatement(
      cash: CourierCash(
        courierId: base?.courierId ?? '',
        name: base?.name ?? '',
        balances: balances,
        negative: balances.any((balance) => balance.amount < 0),
      ),
      movements: [...unsent.reversed, ...?stored?.movements],
    );
  }

  /// Lets a sync in course finish before closing (it writes to the store).
  @override
  Future<void> close() async {
    await _running;
    return super.close();
  }

  Future<void> dismiss(String actionId) async {
    await _store.dismiss(actionId);
    await _refresh();
  }

  Future<void> _refresh({bool changed = false}) async {
    final pending = (await _store.pending()).length;
    final rejected = await _store.rejected();
    final lastSync = await _store.lastSync();
    if (isClosed) return;
    emit(
      state.copyWith(
        pending: pending,
        rejected: rejected,
        lastSync: lastSync,
        revision: changed ? state.revision + 1 : null,
      ),
    );
  }
}
