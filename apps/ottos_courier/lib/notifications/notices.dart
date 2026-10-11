import 'package:ottos_core/ottos_core.dart';

import '../app/courier_texts.dart';

enum NoticeChannel { newRemittance, completed }

/// One notification to show on the phone.
class Notice {
  const Notice({required this.id, required this.channel, required this.title, required this.body, this.remittanceId});

  /// The same remittance replaces its own notification instead of stacking.
  final int id;
  final NoticeChannel channel;
  final String title;
  final String body;

  /// Opened when the notification is tapped; null opens the list.
  final String? remittanceId;
}

/// Beyond this many at once, one notification sums them up.
const maxSingleNotices = 3;

/// "OT-ABC123 · Rosa Pérez · Boyeros".
String _line(Remittance remittance, [String? extra]) => [
  remittance.code,
  remittance.beneficiaryName,
  extra,
].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

int _idOf(String remittanceId, NoticeChannel channel) => Object.hash(remittanceId, channel) & 0x7fffffff;

/// Remittances just assigned to the courier.
List<Notice> newRemittanceNotices(List<Remittance> remittances) {
  if (remittances.isEmpty) return const [];
  if (remittances.length > maxSingleNotices) {
    return [
      Notice(
        id: NoticeChannel.newRemittance.index,
        channel: NoticeChannel.newRemittance,
        title: CourierTexts.newRemittancesTitle(remittances.length),
        body: remittances.map((remittance) => remittance.code).join(', '),
      ),
    ];
  }
  return [
    for (final remittance in remittances)
      Notice(
        id: _idOf(remittance.id, NoticeChannel.newRemittance),
        channel: NoticeChannel.newRemittance,
        title: CourierTexts.newRemittanceTitle(remittance),
        body: _line(remittance, remittance.municipalityName),
        remittanceId: remittance.id,
      ),
  ];
}

/// Deliveries and pickups that a courier finished, for sales.
List<Notice> completedNotices(List<Remittance> remittances) {
  if (remittances.isEmpty) return const [];
  if (remittances.length > maxSingleNotices) {
    return [
      Notice(
        id: NoticeChannel.completed.index,
        channel: NoticeChannel.completed,
        title: CourierTexts.completedManyTitle(remittances.length),
        body: remittances.map((remittance) => remittance.code).join(', '),
      ),
    ];
  }
  return [
    for (final remittance in remittances)
      Notice(
        id: _idOf(remittance.id, NoticeChannel.completed),
        channel: NoticeChannel.completed,
        title: CourierTexts.completedTitle(remittance),
        body: _line(remittance, remittance.courierName),
        remittanceId: remittance.id,
      ),
  ];
}
