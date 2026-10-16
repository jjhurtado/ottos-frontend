import 'package:ottos_core/ottos_core.dart';

import 'sync_cubit.dart';

/// Where the app reads remittances from and sends the courier's actions to.
abstract interface class RemittanceSource {
  /// The open remittances of the list.
  Future<List<Remittance>> list();

  /// Whether the list can also show the completed remittances: sales, who see
  /// every remittance; the courier's list holds only open work.
  bool get canShowCompleted;

  /// The delivered and collected remittances, latest first, a page at a time.
  /// Only where [canShowCompleted].
  Future<PageResult<Remittance>> completed({int page = 0});

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
    final finals = [for (final status in (await _remittances.workflow()).statuses) if (status.isFinal) status.code];
    // With a single final status the backend pages exactly the completed ones.
    final result = await _remittances.search(
      RemittanceFilter(voided: false, status: finals.length == 1 ? finals.single : null),
      page: page,
      size: completedPageSize,
    );
    return PageResult(
      items: [for (final remittance in result.items) if (finals.contains(remittance.status)) remittance],
      page: result.page,
      size: result.size,
      totalItems: result.totalItems,
    );
  }

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
  bool get canShowCompleted => false;

  @override
  Future<PageResult<Remittance>> completed({int page = 0}) => throw UnsupportedError('Only sales list completed ones');

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

  @override
  Future<Remittance> get(String id) async {
    final json = await _sync.store.remittance(id);
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
          occurredAt: DateTime.now(),
          payload: payload,
        ),
      );

  static String? _text(String? text) => text == null || text.trim().isEmpty ? null : text.trim();
}
