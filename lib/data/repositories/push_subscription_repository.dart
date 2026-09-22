import 'package:supabase_flutter/supabase_flutter.dart';

/// Pushes this device's FCM token + reminder schedule to the
/// `push_subscriptions` table in Supabase, so the send-daily-reminders Edge
/// Function knows when and where to send the daily reminder push. Every
/// call is scoped to the signed-in user by RLS; with nobody signed in, both
/// methods are a no-op (there's no user_id to key the row on server-side).
class PushSubscriptionRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> upsert({
    required String fcmToken,
    required String platform,
    required int hour,
    required int minute,
    required String timezone,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('push_subscriptions').upsert({
      'user_id': userId,
      'fcm_token': fcmToken,
      'platform': platform,
      'reminder_hour': hour,
      'reminder_minute': minute,
      'timezone': timezone,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> delete() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('push_subscriptions').delete().eq('user_id', userId);
  }
}
