import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_bookmark.dart';

/// Local storage for the single "continuar de onde parei" bookmark — a
/// handful of scalar fields, so SharedPreferences (like theme/font-scale in
/// SettingsRepository) fits better than a SQLite table for one row.
class BookmarkRepository {
  static const _keyBookId = 'bookmark_book_id';
  static const _keyBookOrder = 'bookmark_book_order';
  static const _keyBookName = 'bookmark_book_name';
  static const _keyChapterNumber = 'bookmark_chapter_number';
  static const _keyVerseNumber = 'bookmark_verse_number';
  static const _keySavedAt = 'bookmark_saved_at';

  Future<ReadingBookmark?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final bookId = prefs.getString(_keyBookId);
    final savedAtIso = prefs.getString(_keySavedAt);
    if (bookId == null || savedAtIso == null) return null;
    return ReadingBookmark(
      bookId: bookId,
      bookOrder: prefs.getInt(_keyBookOrder) ?? 0,
      bookName: prefs.getString(_keyBookName) ?? '',
      chapterNumber: prefs.getInt(_keyChapterNumber) ?? 1,
      verseNumber: prefs.getInt(_keyVerseNumber),
      savedAt: DateTime.parse(savedAtIso),
    );
  }

  Future<void> set(ReadingBookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBookId, bookmark.bookId);
    await prefs.setInt(_keyBookOrder, bookmark.bookOrder);
    await prefs.setString(_keyBookName, bookmark.bookName);
    await prefs.setInt(_keyChapterNumber, bookmark.chapterNumber);
    if (bookmark.verseNumber != null) {
      await prefs.setInt(_keyVerseNumber, bookmark.verseNumber!);
    } else {
      await prefs.remove(_keyVerseNumber);
    }
    await prefs.setString(_keySavedAt, bookmark.savedAt.toIso8601String());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBookId);
    await prefs.remove(_keyBookOrder);
    await prefs.remove(_keyBookName);
    await prefs.remove(_keyChapterNumber);
    await prefs.remove(_keyVerseNumber);
    await prefs.remove(_keySavedAt);
  }
}
