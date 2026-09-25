import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';
import '../../logic/sync_merge.dart';
import '../../logic/verse_id.dart';
import '../models/verse_note.dart';

/// Pushes/pulls verse notes to the `verse_notes` table in Supabase. Mirrors
/// FavoriteSyncRepository's pattern (RLS-scoped, no-ops with nobody signed
/// in), including soft delete via `deleted_at`.
class VerseNoteSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, VerseNote note) => {
        'user_id': userId,
        'book_id': note.bookId,
        'chapter_number': note.chapterNumber,
        'verse_number': note.verseNumber,
        'note': note.note,
        'updated_at': toRemoteTimestamp(note.updatedAt),
        'deleted_at': null, // pushing a live note undeletes it
      };

  Map<String, Object?>? _tombstoneFor(String userId, String id, DateTime deletedAt) {
    final ref = parseVerseId(id);
    if (ref == null) return null;
    return {
      'user_id': userId,
      'book_id': ref.bookId,
      'chapter_number': ref.chapterNumber,
      'verse_number': ref.verseNumber,
      'note': '', // NOT NULL column; the text is gone with the note
      'updated_at': toRemoteTimestamp(deletedAt),
      'deleted_at': toRemoteTimestamp(deletedAt),
    };
  }

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

  Future<void> pushDeleted(Deletions deletions) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || deletions.isEmpty) return;
    final rows = [
      for (final e in deletions.entries) ?_tombstoneFor(userId, e.key, e.value),
    ];
    if (rows.isNotEmpty) await _client.from('verse_notes').upsert(rows);
  }

  Future<({List<VerseNote> live, Deletions deleted})> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (live: <VerseNote>[], deleted: <String, DateTime>{});
    final rows = await _client.from('verse_notes').select().eq('user_id', userId);
    final live = <VerseNote>[];
    final deleted = <String, DateTime>{};
    for (final r in rows) {
      final id = '${r['book_id']}-${r['chapter_number']}-${r['verse_number']}';
      final deletedAt = r['deleted_at'] as String?;
      if (deletedAt != null) {
        deleted[id] = DateTime.parse(deletedAt).toLocal();
        continue;
      }
      live.add(VerseNote(
        bookId: r['book_id'] as String,
        chapterNumber: r['chapter_number'] as int,
        verseNumber: r['verse_number'] as int,
        note: r['note'] as String,
        updatedAt: DateTime.parse(r['updated_at'] as String).toLocal(),
      ));
    }
    return (live: live, deleted: deleted);
  }
}
