import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyStartDate = 'start_date';
  static const _keyReminderEnabled = 'reminder_enabled';
  static const _keyReminderHour = 'reminder_hour';
  static const _keyReminderMinute = 'reminder_minute';
  static const _keyHasSeeded = 'has_seeded';

  Future<DateTime?> getStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_keyStartDate);
    if (iso == null) return null;
    return DateTime.parse(iso);
  }

  Future<void> setStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateOnly = DateTime(date.year, date.month, date.day);
    await prefs.setString(_keyStartDate, dateOnly.toIso8601String());
  }

  Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReminderEnabled) ?? false;
  }

  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReminderEnabled, enabled);
  }

  /// Returns (hour, minute), defaulting to 07:00.
  Future<(int, int)> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyReminderHour) ?? 7;
    final minute = prefs.getInt(_keyReminderMinute) ?? 0;
    return (hour, minute);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
    await prefs.setInt(_keyReminderMinute, minute);
  }

  Future<bool> getHasSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeeded) ?? false;
  }

  Future<void> setHasSeeded(bool seeded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeeded, seeded);
  }
}
