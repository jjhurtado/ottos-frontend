import 'package:ottos_core/ottos_core.dart';

import 'offline_store.dart';
import 'sync_cubit.dart';

/// Where the app reads remittances from and sends the courier's actions to.
abstract interface class RemittanceSource {
  /// The open remittances of the list.
  Future<List<Remittance>> list();

  /// Whether the list can also show the completed remittances: sales, who see
  /// every remittance, and the courier, who sees their latest ones (REQ-017).
  bool get canShowCompleted;

  /// Whether the completed ones are only the latest few (the courier's 20),
  /// which the list says in a heading; sales page through all of them.
  bool get completedAreLatest;

  /// The delivered and collected remittances, latest first, a page at a time.
  /// Only where [canShowCompleted].
  Future<PageResult<Remittance>> completed({int page = 0});

  /// Whether the list can search by beneficiary (sales, online; REQ-018).
  bool get canSearch;

  /// Remittances of any status whose beneficiary matches [query] (name or last
  /// phone digits), most recent first, a page at a time. Only where [canSearch].
  Future<PageResult<Remittance>> search(String query, {int page = 0});

  Future<Remittance> get(String id);

  /// Remittances with an action not sent yet.
  Future<Set<String>> pendingIds();

  /// Emits when the data changed on its own (a sync), to reload.
  Stream<void> get changes;

  /// Brings the latest (pull to refresh): a sync, or nothing online.
  Future<void> refresh();

  Future<ActionOutcome> deliver(Remittance remittance, {String? pin, String? note});

  Future<ActionOutcome> postpone(Remittance remittance, {required DateTime newDate, required String reason});

  Future<ActionOutcome> reportIncident(Remittance remittance, {required IncidentReason reason, String? note});
}

/// Straight to the server: sales, who work online.
class OnlineSource implements RemittanceSource {
  OnlineSource({required this._remittances, this.onlyMine = false});

  final RemittanceRepository _remittances;

  /// The ones assigned to the user; false lists every open remittance.
  final bool onlyMine;

  /// How many of the latest remittances sales sees; the panel has the rest.
  static const openPageSize = 100;

  @override
  bool get canShowCompleted => !onlyMine;

  @override
  bool get completedAreLatest => false;

  /// How many completed remittances each «Ver más» brings.
  static const completedPageSize = 50;

  @override
  Future<List<Remittance>> list() async {
    if (onlyMine) return _remittances.assignedToMe();
    final workflow = await _remittances.workflow();
    // Voided ones are not work: the backend keeps them out only of the courier's lists.
    final page = await _remittances.search(const RemittanceFilter(voided: false), size: openPageSize);
    return page.items.where((remittance) => !workflow.isFinal(remittance.status)).toList();
  }

  @override
  Future<PageResult<Remittance>> completed({int page = 0}) async {
    final finals = [
      for (final status in (await _remittances.workflow()).statuses)
        if (status.isFinal) status.code,
    ];
    // With a single final status the backend pages exactly the completed ones.
    final result = await _remittances.search(
      RemittanceFilter(voided: false, status: finals.length == 1 ? finals.single : null),
      page: page,
      size: completedPageSize,
    );
    return PageResult(
      items: [
        for (final remittance in result.items)
          if (finals.contains(remittance.status)) remittance,
      ],
      page: result.page,
      size: result.size,
      totalItems: result.totalItems,
    );
  }

  @override
  bool get canSearch => !onlyMine;

  /// How many results each page of a search brings.
  static const searchPageSize = 50;

  @override
  Future<PageResult<Remittance>> search(String query, {int page = 0}) => _remittances.search(
    RemittanceFilter(beneficiaryQuery: query),
    page: page,
    size: searchPageSize,
  );

  @override
  Future<Remittance> get(String id) => _remittances.get(id);

  @override
  Future<Set<String>> pendingIds() async => const {};

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<void> refresh() async {}

  @override
  Future<ActionOutcome> deliver(Remittance remittance, {String? pin, String? note}) => _run(
    () => pin == null || pin.isEmpty
        ? _remittances.deliver(remittance.id, note: note)
        : _remittances.deliverWithPin(remittance.id, pin: pin, note: note),
  );

  @override
  Future<ActionOutcome> postpone(Remittance remittance, {required DateTime newDate, required String reason}) =>
      _run(() => _remittances.postpone(remittance.id, newDate: newDate, reason: reason));

  @override
  Future<ActionOutcome> reportIncident(Remittance remittance, {required IncidentReason reason, String? note}) =>
      _run(() => _remittances.reportIncident(remittance.id, reason: reason, note: note));

  static Future<ActionOutcome> _run(Future<Remittance> Function() action) async {
    try {
      return Applied(await action());
    } on ApiException catch (error) {
      return Rejected(error.message);
    }
  }
}

/// From the phone: the courier's remittances work without network and their
/// actions wait in the queue until it comes back.
class OfflineSource implements RemittanceSource {
  OfflineSource({required this._sync});

  final SyncCubit _sync;

  @override
  bool get canShowCompleted => true;

  @override
  bool get completedAreLatest => true;

  /// The courier works from the phone: no search there (REQ-018 is for sales).
  @override
  bool get canSearch => false;

  @override
  Future<PageResult<Remittance>> search(String query, {int page = 0}) =>
      throw UnsupportedError('The offline source cannot search');

  /// The courier's latest completed ones, in one page, so there is never a
  /// «Ver más» (REQ-017): first those completed on the phone and not sent yet,
  /// then the stored ones, without repeats, at most [OfflineStore.maxCompleted].
  @override
  Future<PageResult<Remittance>> completed({int page = 0}) async {
    final unsent = await _unsentCompleted();
    final ids = {for (final remittance in unsent) remittance.id};
    final items = [
      ...unsent,
      for (final json in await _sync.store.completed())
        if (!ids.contains(json['id'])) Remittance.fromJson(json),
    ].take(OfflineStore.maxCompleted).toList();
    return PageResult(items: items, page: 0, size: OfflineStore.maxCompleted, totalItems: items.length);
  }

  /// Remittances completed on the phone whose action waits in the queue: the
  /// stored open one as it will be once sent, completed when the courier did
  /// it, newest first. One no longer on the phone (after a logout) is skipped
  /// until a download brings it back.
  Future<List<Remittance>> _unsentCompleted() async {
    final unsent = <Remittance>[];
    for (final action in (await _sync.store.pending()).reversed) {
      final id = action.remittanceId;
      if (!action.type.completes || id == null || unsent.any((remittance) => remittance.id == id)) continue;
      final json = await _sync.store.remittance(id);
      if (json == null) continue;
      unsent.add(Remittance.fromJson(_completedCopy(json, action)));
    }
    return unsent;
  }

  static Map<String, dynamic> _completedCopy(Map<String, dynamic> json, SyncAction action) {
    final type = RemittanceType.fromCode(json['type'] as String?);
    return {
      ...json,
      'status': _completedStatus,
      'statusName': CoreTexts.statusName(_completedStatus, type: type),
      'completedAt': action.occurredAt.toUtc().toIso8601String(),
    };
  }

  /// The final status of a delivery or a pickup.
  static const _completedStatus = 'DELIVERED';

  @override
  Future<List<Remittance>> list() async {
    final pending = await _sync.store.pending();
    // A completed one is gone for the courier even before it is sent.
    final completed = {
      for (final action in pending)
        if (action.type.completes) ?action.remittanceId,
    };
    return [
      for (final json in await _sync.store.remittances())
        if (!completed.contains(json['id'])) Remittance.fromJson(json),
    ];
  }

  /// One completed on the phone and not sent yet opens as completed, read-only;
  /// then an open one; then one of the latest completed (REQ-017 AC-1.2).
  @override
  Future<Remittance> get(String id) async {
    final unsent = (await _unsentCompleted()).where((remittance) => remittance.id == id).firstOrNull;
    if (unsent != null) return unsent;
    final json = await _sync.store.remittance(id) ?? await _sync.store.completedRemittance(id);
    if (json == null) throw const ApiException(CoreTexts.notFound, statusCode: 404);
    return Remittance.fromJson(json);
  }

  @override
  Future<Set<String>> pendingIds() async => {for (final action in await _sync.store.pending()) ?action.remittanceId};

  @override
  Future<void> refresh() => _sync.sync();

  @override
  Stream<void> get changes => _sync.stream.map((status) => status.revision).distinct().map((_) {});

  @override
  Future<ActionOutcome> deliver(Remittance remittance, {String? pin, String? note}) => _perform(
    remittance,
    pin == null || pin.isEmpty ? SyncActionType.deliver : SyncActionType.deliverWithPin,
    {'pin': ?(pin == null || pin.isEmpty ? null : pin), 'note': ?_text(note)},
  );

  @override
  Future<ActionOutcome> postpone(Remittance remittance, {required DateTime newDate, required String reason}) =>
      _perform(remittance, SyncActionType.postpone, {'newDate': Formatters.apiDate(newDate), 'reason': reason.trim()});

  @override
  Future<ActionOutcome> reportIncident(Remittance remittance, {required IncidentReason reason, String? note}) =>
      _perform(remittance, SyncActionType.reportIncident, {'reason': reason.code, 'note': ?_text(note)});

  Future<ActionOutcome> _perform(Remittance remittance, SyncActionType type, Map<String, dynamic> payload) =>
      _sync.perform(
        SyncAction(
          id: SyncRepository.newActionId(),
          type: type,
          remittanceId: remittance.id,
          occurredAt: BusinessTime.now(),
          payload: payload,
        ),
      );

  static String? _text(String? text) => text == null || text.trim().isEmpty ? null : text.trim();
}
