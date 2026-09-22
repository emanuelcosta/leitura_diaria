import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/push_subscription_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'notification_service.dart';

/// Registered in main.dart via FirebaseMessaging.onBackgroundMessage.
/// Notification-type FCM messages are already shown by the OS while the app
/// is backgrounded/terminated — this only exists because the plugin
/// requires a handler to be registered, and it runs in its own isolate
/// (hence the separate Firebase.initializeApp call).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Orchestrates the daily reminder push: keeps this device's FCM token +
/// reminder schedule in sync with Supabase (see PushSubscriptionRepository)
/// and shows a local notification when a push arrives while the app is in
/// the foreground (the OS doesn't display those on its own).
///
/// Safe to use even when Firebase wasn't initialized (e.g. a build without
/// google-services.json/GoogleService-Info.plist bundled yet) — every
/// member then behaves as "no push available" instead of throwing, same
/// spirit as AuthService's `_ready` guard.
class PushNotificationService {
  final NotificationService _notificationService;
  final SettingsRepository _settingsRepo;
  final PushSubscriptionRepository? _subscriptionRepo;

  PushNotificationService({
    required NotificationService notificationService,
    required SettingsRepository settingsRepo,
    PushSubscriptionRepository? subscriptionRepo,
  })  : _notificationService = notificationService,
        _settingsRepo = settingsRepo,
        _subscriptionRepo = subscriptionRepo {
    if (_ready) {
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    }
    // Mirrors ReadingPlanProvider's pullFromRemoteAndMerge-on-signIn pattern:
    // if the reminder was already on (e.g. toggled before logging out, or
    // restored from local prefs) sign-in alone doesn't touch the switch, so
    // nothing would otherwise re-register the subscription server-side.
    if (_subscriptionRepo != null) {
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) {
          unawaited(_syncIfEnabled());
        }
      });
    }
  }

  bool get _ready {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> enableDailyReminder({required int hour, required int minute}) async {
    if (!_ready) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _upsert(token: token, hour: hour, minute: minute);
  }

  Future<void> disableDailyReminder() async {
    await _subscriptionRepo?.delete();
  }

  Future<void> _upsert({required String token, required int hour, required int minute}) async {
    final repo = _subscriptionRepo;
    if (repo == null) return;
    String timezone;
    try {
      timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      timezone = 'UTC';
    }
    await repo.upsert(
      fcmToken: token,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      hour: hour,
      minute: minute,
      timezone: timezone,
    );
  }

  void _onTokenRefresh(String token) {
    unawaited(_syncIfEnabled(token: token));
  }

  /// Re-upserts the subscription using the current reminder settings,
  /// whenever something happened that could've left the server row stale
  /// without the user touching the toggle: the token rotating (reinstall,
  /// restore, etc.) or signing back in with the reminder already on.
  /// No-op if the reminder is off.
  Future<void> _syncIfEnabled({String? token}) async {
    if (!_ready) return;
    final enabled = await _settingsRepo.getReminderEnabled();
    if (!enabled) return;
    final resolvedToken = token ?? await FirebaseMessaging.instance.getToken();
    if (resolvedToken == null) return;
    final (hour, minute) = await _settingsRepo.getReminderTime();
    await _upsert(token: resolvedToken, hour: hour, minute: minute);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    unawaited(_notificationService.showNow(
      title: notification.title ?? 'Leitura de hoje',
      body: notification.body ?? '',
    ));
  }
}
