import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/courier_texts.dart';
import 'notices.dart';

/// Shows [Notice]s on the phone.
abstract interface class Notifier {
  /// Asks for the permission where the system needs it (Android 13+).
  Future<void> requestPermission();

  Future<void> show(List<Notice> notices);
}

/// Local notifications: the app makes them itself when it checks the server,
/// with no push service (Firebase may not reach Cuba).
class LocalNotifier implements Notifier {
  LocalNotifier._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// The remittance of a tapped notification, to open it.
  void Function(String? remittanceId)? onOpen;

  /// The remittance whose notification launched the app, if one did.
  String? launchRemittanceId;
  bool launchedFromNotice = false;

  static Future<LocalNotifier> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    late final LocalNotifier notifier;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        // Asked after the login, with the Android one (requestPermission).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => notifier.onOpen?.call(_remittanceOf(response.payload)),
    );
    notifier = LocalNotifier._(plugin);
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      notifier.launchedFromNotice = true;
      notifier.launchRemittanceId = _remittanceOf(launch!.notificationResponse?.payload);
    }
    return notifier;
  }

  static String? _remittanceOf(String? payload) => payload == null || payload.isEmpty ? null : payload;

  @override
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<void> show(List<Notice> notices) async {
    for (final notice in notices) {
      await _plugin.show(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        notificationDetails: NotificationDetails(
          android: _channels[notice.channel],
          iOS: const DarwinNotificationDetails(),
        ),
        payload: notice.remittanceId,
      );
    }
  }

  static const _channels = {
    NoticeChannel.newRemittance: AndroidNotificationDetails(
      'remittances_new',
      CourierTexts.newRemittancesChannel,
      channelDescription: CourierTexts.newRemittancesChannelHelp,
      importance: Importance.high,
      priority: Priority.high,
    ),
    NoticeChannel.completed: AndroidNotificationDetails(
      'remittances_completed',
      CourierTexts.completedChannel,
      channelDescription: CourierTexts.completedChannelHelp,
      importance: Importance.high,
      priority: Priority.high,
    ),
  };
}
