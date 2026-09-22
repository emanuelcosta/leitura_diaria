import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications. The daily reminder
/// itself is now scheduled server-side (Supabase Edge Function, see
/// supabase/functions/send-daily-reminders) and delivered via FCM/APNs —
/// this class only requests the permission and displays the notification
/// when a push arrives while the app is in the foreground (the OS doesn't
/// show those on its own, see PushNotificationService.onMessage).
class NotificationService {
  static const _foregroundPushId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  Future<void> showNow({required String title, required String body}) async {
    await init();
    await _plugin.show(
      id: _foregroundPushId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Lembrete diário',
          channelDescription: 'Lembrete diário para a leitura bíblica',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
