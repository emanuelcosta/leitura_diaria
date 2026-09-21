import 'package:flutter/foundation.dart';

import '../data/database/app_database.dart';
import '../data/database/queries.dart';
import '../data/database/seed_loader.dart';
import '../data/reading_plan_meta.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/chapter_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../logic/schedule_calculator.dart';
import '../logic/streak_calculator.dart';

class ReadingPlanProvider extends ChangeNotifier {
  final ChapterRepository _chapterRepo;
  final BookRepository _bookRepo;
  final SettingsRepository _settingsRepo;

  ReadingPlanProvider({
    ChapterRepository? chapterRepo,
    BookRepository? bookRepo,
    SettingsRepository? settingsRepo,
  })  : _chapterRepo = chapterRepo ?? ChapterRepository(),
        _bookRepo = bookRepo ?? BookRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository();

  ReadingPlanMeta? _meta;
  OverallProgress? _overallProgress;
  bool _initialized = false;

  bool get initialized => _initialized;
  ReadingPlanMeta get meta => _meta!;
  OverallProgress get overallProgress =>
      _overallProgress ?? const OverallProgress(readCount: 0, totalCount: 0);

  /// Ensures the DB is seeded (once) and plan metadata is loaded. Safe to call
  /// every app start; only seeds the very first time.
  Future<void> initialize() async {
    if (_initialized) return;
    _meta = await ReadingPlanMeta.load();

    final hasSeeded = await _settingsRepo.getHasSeeded();
    if (!hasSeeded) {
      final db = await AppDatabase.instance.database;
      await SeedLoader.seed(db);
      await _settingsRepo.setHasSeeded(true);
    }

    await refreshOverallProgress();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refreshOverallProgress() async {
    _overallProgress = await _chapterRepo.getOverallProgress();
  }

  Future<List<ChapterView>> getChaptersForPlanDay(int planDay) {
    return _chapterRepo.getChaptersForPlanDay(planDay);
  }

  Future<List<ChapterView>> getChaptersWithNotes() {
    return _chapterRepo.getChaptersWithNotes();
  }

  Future<List<ChapterView>> getChaptersForBook(String bookId) {
    return _chapterRepo.getChaptersForBook(bookId);
  }

  Future<List<BookProgress>> getProgressByBook() {
    return _bookRepo.getProgressByBook();
  }

  Future<void> setChapterRead(String chapterId, {required bool isRead, String? note}) async {
    await _chapterRepo.setRead(chapterId, isRead: isRead, note: note);
    await refreshOverallProgress();
    notifyListeners();
  }

  Future<void> setChapterNote(String chapterId, String? note) async {
    await _chapterRepo.setNote(chapterId, note);
    notifyListeners();
  }

  Future<void> resetAllProgress() async {
    await _chapterRepo.resetAllProgress();
    await refreshOverallProgress();
    notifyListeners();
  }

  Future<StreakResult> computeStreak() async {
    final dates = await _chapterRepo.getAllDistinctReadDates();
    return StreakCalculator.compute(dates);
  }

  Future<Map<String, int>> getReadCountsByDate() {
    return _chapterRepo.getReadCountsByDate();
  }

  ScheduleStatus computeScheduleStatus({
    required DateTime startDate,
    required DateTime today,
    DateTime? lastReadAt,
  }) {
    final calculator = ScheduleCalculator(
      planCumulative: meta.cumulativeByDay,
      totalPlanDays: meta.totalPlanDays,
    );
    return calculator.computeStatus(
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      today: DateTime(today.year, today.month, today.day),
      actualReadCount: overallProgress.readCount,
      lastReadAt: lastReadAt,
    );
  }

  int idealPlanDayFor(DateTime startDate, DateTime today) {
    final daysSinceStart = DateTime(today.year, today.month, today.day)
        .difference(DateTime(startDate.year, startDate.month, startDate.day))
        .inDays;
    final day = daysSinceStart + 1;
    if (day < 1) return 1;
    if (day > meta.totalPlanDays) return meta.totalPlanDays;
    return day;
  }
}
