import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';

import '../models/doubt_verse.dart';

/// Mirrors FavoriteSyncRepository's pattern (RLS-scoped, no-ops with nobody
/// signed in) for the `doubt_verses` table.
class DoubtSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, DoubtVerse doubt) => {
        'user_id': userId,
        'book_id': doubt.bookId,
        'chapter_number': doubt.chapterNumber,
        'verse_number': doubt.verseNumber,
        'note': doubt.note,
        'created_at': toRemoteTimestamp(doubt.createdAt),
      };

  Future<void> push(DoubtVerse doubt) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('doubt_verses').upsert(_rowFor(userId, doubt));
  }

  Future<void> pushAll(List<DoubtVerse> doubts) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || doubts.isEmpty) return;
    await _client.from('doubt_verses').upsert(doubts.map((d) => _rowFor(userId, d)).toList());
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('doubt_verses')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .eq('chapter_number', chapterNumber)
        .eq('verse_number', verseNumber);
  }

  Future<List<DoubtVerse>> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('doubt_verses').select().eq('user_id', userId);
    return rows
        .map((r) => DoubtVerse(
              bookId: r['book_id'] as String,
              chapterNumber: r['chapter_number'] as int,
              verseNumber: r['verse_number'] as int,
              note: r['note'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ))
        .toList();
  }
}
