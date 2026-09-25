import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../data/models/favorite_color.dart';
import '../data/models/progress_mode.dart';
import '../data/repositories/bible_text_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/translation_service.dart';

/// Multiplied by the theme's default text size wherever reading text size
/// matters (currently ChapterReadingScreen). Clamped so text never becomes
/// unusably tiny or overflows common layouts.
const minFontScale = 0.8;
const maxFontScale = 1.8;
const _fontScaleStep = 0.1;

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;

  SettingsProvider(this._repo);

  DateTime? _startDate;
  bool _reminderEnabled = false;
  int _reminderHour = 7;
  int _reminderMinute = 0;
  BibleTranslation _translation = BibleTranslation.acf;
  ThemeMode _themeMode = ThemeMode.system;
  double _fontScale = 1.0;
  TranslationLanguage _translationLanguage = TranslationLanguage.pt;
  ProgressMode _progressMode = ProgressMode.chapters;
  Map<FavoriteColor, String> _markerNames = const {};
  bool _loaded = false;

  DateTime? get startDate => _startDate;
  bool get reminderEnabled => _reminderEnabled;
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  BibleTranslation get translation => _translation;
  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  TranslationLanguage get translationLanguage => _translationLanguage;
  ProgressMode get progressMode => _progressMode;
  /// What a marker color means to the user ("Promessas"), or the color's
  /// own name ("Amarelo") if not renamed.
  String markerName(FavoriteColor color) => _markerNames[color] ?? color.label;

  /// Whether the user gave this color a name of their own.
  bool isMarkerRenamed(FavoriteColor color) => _markerNames.containsKey(color);
  bool get loaded => _loaded;
  bool get hasStarted => _startDate != null;

  Future<void> load() async {
    _startDate = await _repo.getStartDate();
    _reminderEnabled = await _repo.getReminderEnabled();
    final (h, m) = await _repo.getReminderTime();
    _reminderHour = h;
    _reminderMinute = m;
    _translation = await _repo.getTranslation();
    _themeMode = await _repo.getThemeMode();
    _fontScale = await _repo.getFontScale();
    _translationLanguage = await _repo.getTranslationLanguage();
    _progressMode = await _repo.getProgressMode();
    _markerNames = await _repo.getMarkerNames();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTranslationLanguage(TranslationLanguage language) async {
    await _repo.setTranslationLanguage(language);
    _translationLanguage = language;
    notifyListeners();
  }

  /// Empty [name] goes back to the color's default name.
  Future<void> setMarkerName(FavoriteColor color, String name) async {
    await _repo.setMarkerName(color, name);
    _markerNames = await _repo.getMarkerNames();
    notifyListeners();
  }

  Future<void> setProgressMode(ProgressMode mode) async {
    await _repo.setProgressMode(mode);
    _progressMode = mode;
    notifyListeners();
  }

  Future<void> setTranslation(BibleTranslation translation) async {
    await _repo.setTranslation(translation);
    _translation = translation;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.setThemeMode(mode);
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    final clamped = scale.clamp(minFontScale, maxFontScale);
    await _repo.setFontScale(clamped);
    _fontScale = clamped;
    notifyListeners();
  }

  Future<void> increaseFontScale() => setFontScale(_fontScale + _fontScaleStep);

  Future<void> decreaseFontScale() => setFontScale(_fontScale - _fontScaleStep);

  Future<void> setStartDate(DateTime date) async {
    await _repo.setStartDate(date);
    _startDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  Future<void> setReminder({required bool enabled, int? hour, int? minute}) async {
    await _repo.setReminderEnabled(enabled);
    _reminderEnabled = enabled;
    if (hour != null && minute != null) {
      await _repo.setReminderTime(hour, minute);
      _reminderHour = hour;
      _reminderMinute = minute;
    }
    notifyListeners();
  }
}
