import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';
import '../../logic/sync_merge.dart';
import '../../logic/verse_id.dart';
import '../models/favorite_color.dart';
import '../models/favorite_verse.dart';

/// Pushes/pulls favorited verses to the `favorite_verses` table in Supabase.
/// Mirrors SyncRepository's pattern (RLS-scoped, no-ops with nobody signed
/// in) but kept separate since favorites are a distinct concern from
/// reading progress.
///
/// Deleting is a soft delete (`deleted_at` set, row kept) so other devices
/// learn about it instead of pushing the favorite back — see applyDeletions.
class FavoriteSyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, FavoriteVerse favorite) => {
        'user_id': userId,
        'book_id': favorite.bookId,
        'chapter_number': favorite.chapterNumber,
        'verse_number': favorite.verseNumber,
        'color': favorite.color.name,
        'created_at': toRemoteTimestamp(favorite.createdAt),
        'updated_at': toRemoteTimestamp(favorite.updatedAt),
        'deleted_at': null, // pushing a live favorite undeletes it
      };

  Map<String, Object?>? _tombstoneFor(String userId, String id, DateTime deletedAt) {
    final ref = parseVerseId(id);
    if (ref == null) return null;
    return {
      'user_id': userId,
      'book_id': ref.bookId,
      'chapter_number': ref.chapterNumber,
      'verse_number': ref.verseNumber,
      'updated_at': toRemoteTimestamp(deletedAt),
      'deleted_at': toRemoteTimestamp(deletedAt),
    };
  }

  Future<void> push(FavoriteVerse favorite) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('favorite_verses').upsert(_rowFor(userId, favorite));
  }

  Future<void> pushAll(List<FavoriteVerse> favorites) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || favorites.isEmpty) return;
    await _client.from('favorite_verses').upsert(favorites.map((f) => _rowFor(userId, f)).toList());
  }

  Future<void> pushDeleted(Deletions deletions) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || deletions.isEmpty) return;
    final rows = [
      for (final e in deletions.entries) ?_tombstoneFor(userId, e.key, e.value),
    ];
    if (rows.isNotEmpty) await _client.from('favorite_verses').upsert(rows);
  }

  Future<({List<FavoriteVerse> live, Deletions deleted})> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (live: <FavoriteVerse>[], deleted: <String, DateTime>{});
    final rows = await _client.from('favorite_verses').select().eq('user_id', userId);
    final live = <FavoriteVerse>[];
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
      live.add(FavoriteVerse(
        bookId: r['book_id'] as String,
        chapterNumber: r['chapter_number'] as int,
        verseNumber: r['verse_number'] as int,
        color: FavoriteColor.fromName(r['color'] as String?),
        createdAt: createdAt,
        updatedAt: updatedAt == null ? createdAt : DateTime.parse(updatedAt).toLocal(),
      ));
    }
    return (live: live, deleted: deleted);
  }
}
