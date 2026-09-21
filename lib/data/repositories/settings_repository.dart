import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/translation_service.dart';
import 'bible_text_repository.dart';

class SettingsRepository {
  static const _keyStartDate = 'start_date';
  static const _keyReminderEnabled = 'reminder_enabled';
  static const _keyReminderHour = 'reminder_hour';
  static const _keyReminderMinute = 'reminder_minute';
  static const _keyHasSeeded = 'has_seeded';
  static const _keyTranslation = 'bible_translation';
  static const _keyThemeMode = 'theme_mode';
  static const _keyFontScale = 'font_scale';
  static const _keyTranslationLanguage = 'translation_language';

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

  Future<BibleTranslation> getTranslation() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyTranslation);
    return BibleTranslation.values.firstWhere(
      (t) => t.name == name,
      orElse: () => BibleTranslation.acf,
    );
  }

  Future<void> setTranslation(BibleTranslation translation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTranslation, translation.name);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyThemeMode);
    return ThemeMode.values.firstWhere((m) => m.name == name, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }

  /// Multiplier applied on top of the theme's default text size, e.g. for
  /// reading the Bible text. 1.0 = default.
  Future<double> getFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyFontScale) ?? 1.0;
  }

  Future<void> setFontScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontScale, scale);
  }

  /// Target language for "Traduzir" buttons (e.g. dictionary definitions).
  Future<TranslationLanguage> getTranslationLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyTranslationLanguage);
    return TranslationLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => TranslationLanguage.pt,
    );
  }

  Future<void> setTranslationLanguage(TranslationLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTranslationLanguage, language.code);
  }
}
