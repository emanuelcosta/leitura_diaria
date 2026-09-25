import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';
import '../../logic/sync_merge.dart';
import '../../logic/verse_id.dart';
import '../models/doubt_verse.dart';

/// Mirrors FavoriteSyncRepository's pattern (RLS-scoped, no-ops with nobody
/// signed in, soft delete via `deleted_at`) for the `doubt_verses` table.
class DoubtSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, DoubtVerse doubt) => {
        'user_id': userId,
        'book_id': doubt.bookId,
        'chapter_number': doubt.chapterNumber,
        'verse_number': doubt.verseNumber,
        'note': doubt.note,
        'created_at': toRemoteTimestamp(doubt.createdAt),
        'updated_at': toRemoteTimestamp(doubt.updatedAt),
        'deleted_at': null, // pushing a live doubt undeletes it
      };

  Map<String, Object?>? _tombstoneFor(String userId, String id, DateTime deletedAt) {
    final ref = parseVerseId(id);
    if (ref == null) return null;
    return {
      'user_id': userId,
      'book_id': ref.bookId,
      'chapter_number': ref.chapterNumber,
      'verse_number': ref.verseNumber,
      'note': null, // the comment goes with the doubt — only "which verse, when" stays
      'deleted_at': toRemoteTimestamp(deletedAt),
    };
  }

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

  Future<void> pushDeleted(Deletions deletions) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || deletions.isEmpty) return;
    final rows = [
      for (final e in deletions.entries) ?_tombstoneFor(userId, e.key, e.value),
    ];
    if (rows.isNotEmpty) await _client.from('doubt_verses').upsert(rows);
  }

  Future<({List<DoubtVerse> live, Deletions deleted})> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (live: <DoubtVerse>[], deleted: <String, DateTime>{});
    final rows = await _client.from('doubt_verses').select().eq('user_id', userId);
    final live = <DoubtVerse>[];
    final deleted = <String, DateTime>{};
    for (final r in rows) {
      final id = '${r['book_id']}-${r['chapter_number']}-${r['verse_number']}';
      final deletedAt = r['deleted_at'] as String?;
      if (deletedAt != null) {
        deleted[id] = DateTime.parse(deletedAt).toLocal();
        continue;
      }
      final createdAt = DateTime.parse(r['created_at'] as String).toLocal();
      final updatedAt = r['updated_at'] as String?;
      live.add(DoubtVerse(
        bookId: r['book_id'] as String,
        chapterNumber: r['chapter_number'] as int,
        verseNumber: r['verse_number'] as int,
        note: r['note'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt == null ? createdAt : DateTime.parse(updatedAt).toLocal(),
      ));
    }
    return (live: live, deleted: deleted);
  }
}
