import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verse_note.dart';

/// Pushes/pulls verse notes to the `verse_notes` table in Supabase. Mirrors
/// FavoriteSyncRepository's pattern (RLS-scoped, no-ops with nobody signed
/// in).
class VerseNoteSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, VerseNote note) => {
        'user_id': userId,
        'book_id': note.bookId,
        'chapter_number': note.chapterNumber,
        'verse_number': note.verseNumber,
        'note': note.note,
        'updated_at': note.updatedAt.toIso8601String(),
      };

  Future<void> push(VerseNote note) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('verse_notes').upsert(_rowFor(userId, note));
  }

  Future<void> pushAll(List<VerseNote> notes) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || notes.isEmpty) return;
    await _client.from('verse_notes').upsert(notes.map((n) => _rowFor(userId, n)).toList());
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('verse_notes')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .eq('chapter_number', chapterNumber)
        .eq('verse_number', verseNumber);
  }

  Future<List<VerseNote>> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('verse_notes').select().eq('user_id', userId);
    return rows
        .map((r) => VerseNote(
              bookId: r['book_id'] as String,
              chapterNumber: r['chapter_number'] as int,
              verseNumber: r['verse_number'] as int,
              note: r['note'] as String,
              updatedAt: DateTime.parse(r['updated_at'] as String),
            ))
        .toList();
  }
}
