import 'package:flutter/foundation.dart';

import '../data/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;

  SettingsProvider(this._repo);

  DateTime? _startDate;
  bool _reminderEnabled = false;
  int _reminderHour = 7;
  int _reminderMinute = 0;
  bool _loaded = false;

  DateTime? get startDate => _startDate;
  bool get reminderEnabled => _reminderEnabled;
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  bool get loaded => _loaded;
  bool get hasStarted => _startDate != null;

  Future<void> load() async {
    _startDate = await _repo.getStartDate();
    _reminderEnabled = await _repo.getReminderEnabled();
    final (h, m) = await _repo.getReminderTime();
    _reminderHour = h;
    _reminderMinute = m;
    _loaded = true;
    notifyListeners();
  }

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
