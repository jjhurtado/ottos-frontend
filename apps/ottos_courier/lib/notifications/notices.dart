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

/// "Rosa Pérez · Boyeros · OT-ABC123": the name first, the code last
/// (REQ-019 AC-2.1, AC-2.2). With no name, it starts with the extra part.
String _line(Remittance remittance, [String? extra]) => [
  Formatters.cleanName(remittance.beneficiaryName),
  extra,
  remittance.code,
].whereType<String>().where((part) => part.isNotEmpty).join(' · ');

/// "Rosa Pérez, Juan Gómez, Ana Díaz y 4 más": at most [maxSingleNotices]
/// names; a remittance with no name is named by its code.
String _names(List<Remittance> remittances) {
  final names = [
    for (final remittance in remittances.take(maxSingleNotices))
      switch (Formatters.cleanName(remittance.beneficiaryName)) {
        final name? => name,
        _ => remittance.code,
      },
  ];
  final rest = remittances.length - names.length;
  return rest > 0 ? CourierTexts.andMore(names.join(', '), rest) : names.join(', ');
}

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
        body: _names(remittances),
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
        body: _names(remittances),
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
