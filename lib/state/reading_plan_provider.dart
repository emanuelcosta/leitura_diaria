import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database/app_database.dart';
import '../data/database/queries.dart';
import '../data/database/seed_loader.dart';
import '../data/reading_plan_meta.dart';
import '../data/repositories/bible_text_repository.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/chapter_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../logic/chapter_progress_merge.dart';
import '../logic/schedule_calculator.dart';
import '../logic/streak_calculator.dart';
import '../logic/verse_progress.dart';
import '../services/auth_service.dart';

class ReadingPlanProvider extends ChangeNotifier {
  final ChapterRepository _chapterRepo;
  final BookRepository _bookRepo;
  final SettingsRepository _settingsRepo;
  final BibleTextRepository _bibleTextRepo;
  final SyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  ReadingPlanProvider({
    ChapterRepository? chapterRepo,
    BookRepository? bookRepo,
    SettingsRepository? settingsRepo,
    BibleTextRepository? bibleTextRepo,
    SyncRepository? syncRepo,
  })  : _chapterRepo = chapterRepo ?? ChapterRepository(),
        _bookRepo = bookRepo ?? BookRepository(),
        _settingsRepo = settingsRepo ?? SettingsRepository(),
        _bibleTextRepo = bibleTextRepo ?? BibleTextRepository(),
        _syncRepo = syncRepo {
    // Only listens when a SyncRepository was supplied (i.e. Supabase was
    // initialized) — tests and offline builds pass none and skip this.
    if (_syncRepo != null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (AuthService.startsSession(state)) {
          // Background pull: failures (e.g. offline at startup) are swallowed
          // on purpose — "Sincronizar agora" is where sync errors surface.
          unawaited(pullFromRemoteAndMerge().catchError((_) {}));
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

  Future<void>? _initFuture;

  /// Ensures the DB is seeded (once) and plan metadata is loaded. Safe to call
  /// every app start; only seeds the very first time. Memoized so concurrent
  /// callers (main.dart and the startup sync pull) share one run.
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    _meta = await ReadingPlanMeta.load();

    // The flag lives in SharedPreferences, the data in SQLite — they can
    // drift (e.g. the DB file deleted/replaced while prefs survive), which
    // left an empty chapters table that sync merges silently no-op'd into.
    // The DB itself is the source of truth; seeding is idempotent (replace).
    final hasSeeded = await _settingsRepo.getHasSeeded() && await _bookRepo.hasBooks();
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

  /// Called on sign-in: merges remote progress into local (a chapter read on
  /// any device stays read — see [mergeChapterProgress]) and pushes the merged
  /// result back, so both this device and the account end up with the union.
  /// Local reads made before signing in are never overwritten.
  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    // On startup this races initialize(): merging before the seed lands
    // would write into an empty chapters table and drop remote progress.
    await initialize();
    final remote = await syncRepo.pullAll();
    final merged = mergeChapterProgress(await _chapterRepo.getAllChapters(), remote);
    await _chapterRepo.applyRemoteState(merged.map((c) => (
          bookId: c.bookId,
          chapterNumber: c.chapterNumber,
          isRead: c.isRead,
          readAt: c.readAt,
          note: c.note,
        )));
    await syncRepo.pushAll(merged);
    await refreshOverallProgress();
    notifyListeners();
  }

  /// Same shape as [overallProgress], but counting verses of the read
  /// chapters instead of chapters (see ProgressMode.verses).
  Future<OverallProgress> getVerseProgress(BibleTranslation translation) async {
    final counts = await _bibleTextRepo.getVerseCounts(translation);
    final result = computeVerseProgress(counts, await _chapterRepo.getReadChapterRefs());
    return OverallProgress(readCount: result.read, totalCount: result.total);
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
