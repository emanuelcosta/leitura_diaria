import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';

import '../models/reading_bookmark.dart';

/// Mirrors the other Sync*Repository classes' pattern (RLS-scoped, no-ops
/// with nobody signed in), but for the single-row `reading_bookmarks` table.
class BookmarkSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> push(ReadingBookmark bookmark) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('reading_bookmarks').upsert({
      'user_id': userId,
      'book_id': bookmark.bookId,
      'book_order': bookmark.bookOrder,
      'book_name': bookmark.bookName,
      'chapter_number': bookmark.chapterNumber,
      'verse_number': bookmark.verseNumber,
      'saved_at': toRemoteTimestamp(bookmark.savedAt),
    });
  }

  Future<void> clear() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('reading_bookmarks').delete().eq('user_id', userId);
  }

  Future<ReadingBookmark?> pull() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client.from('reading_bookmarks').select().eq('user_id', userId).limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ReadingBookmark(
      bookId: r['book_id'] as String,
      bookOrder: r['book_order'] as int,
      bookName: r['book_name'] as String,
      chapterNumber: r['chapter_number'] as int,
      verseNumber: r['verse_number'] as int?,
      savedAt: DateTime.parse(r['saved_at'] as String).toLocal(),
    );
  }
}
