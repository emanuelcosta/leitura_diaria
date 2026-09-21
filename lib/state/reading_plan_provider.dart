import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database/app_database.dart';
import '../data/database/queries.dart';
import '../data/database/seed_loader.dart';
import '../data/reading_plan_meta.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/chapter_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../logic/schedule_calculator.dart';
import '../logic/streak_calculator.dart';

class ReadingPlanProvider extends ChangeNotifier {
  final ChapterRepository _chapterRepo;
  final BookRepository _bookRepo;
  final SettingsRepository _settingsRepo;
  final SyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  ReadingPlanProvider({
    ChapterRepository? chapterRepo,
    BookRepository? bookRepo,
    SettingsRepository? settingsRepo,
    SyncRepository? syncRepo,
  })  : _chapterRepo = chapterRepo ?? ChapterRepository(),
        _bookRepo = bookRepo ?? BookRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _syncRepo = syncRepo {
    // Only listens when a SyncRepository was supplied (i.e. Supabase was
    // initialized) — tests and offline builds pass none and skip this.
    if (_syncRepo != null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) {
          pullFromRemoteAndMerge();
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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

  Future<ChapterView?> getChapter(String chapterId) {
    return _chapterRepo.getChapter(chapterId);
  }

  Future<List<BookProgress>> getProgressByBook() {
    return _bookRepo.getProgressByBook();
  }

  Future<void> setChapterRead(String chapterId, {required bool isRead, String? note}) async {
    await _chapterRepo.setRead(chapterId, isRead: isRead, note: note);
    await refreshOverallProgress();
    notifyListeners();
    _pushChapter(chapterId);
  }

  Future<void> setBookRead(String bookId, {required bool isRead}) async {
    await _chapterRepo.setAllReadForBook(bookId, isRead: isRead);
    await refreshOverallProgress();
    notifyListeners();
    _pushBook(bookId);
  }

  Future<void> setChapterNote(String chapterId, String? note) async {
    await _chapterRepo.setNote(chapterId, note);
    notifyListeners();
    _pushChapter(chapterId);
  }

  Future<void> resetAllProgress() async {
    await _chapterRepo.resetAllProgress();
    await refreshOverallProgress();
    notifyListeners();
    _pushAll();
  }

  /// Fire-and-forget: local state (and the UI, already updated above) never
  /// waits on the network. Failures (offline, RLS, etc.) are swallowed here —
  /// the next successful sync (e.g. after a reconnect or re-login) reconciles
  /// state again, so a dropped push isn't user-visible or fatal.
  void _pushChapter(String chapterId) {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    unawaited(_chapterRepo.getChapterRaw(chapterId).then((chapter) {
      if (chapter != null) return syncRepo.pushChapter(chapter);
    }).catchError((_) {}));
  }

  void _pushBook(String bookId) {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    unawaited(
      _chapterRepo.getChaptersRawForBook(bookId).then(syncRepo.pushAll).catchError((_) {}),
    );
  }

  void _pushAll() {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    unawaited(_chapterRepo.getAllChapters().then(syncRepo.pushAll).catchError((_) {}));
  }

  /// Called on sign-in: if the account already has remote progress, it wins
  /// and overwrites local state (e.g. logging into an existing account on a
  /// new device); otherwise this is treated as the account's first sync and
  /// the local state is pushed up instead.
  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    final remote = await syncRepo.pullAll();
    if (remote.isEmpty) {
      await syncRepo.pushAll(await _chapterRepo.getAllChapters());
    } else {
      await _chapterRepo.applyRemoteState(remote);
    }
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

  Future<DateTime?> getLastReadAt() {
    return _chapterRepo.getLastReadAt();
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
