import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logic/remote_timestamp.dart';

import '../models/favorite_color.dart';
import '../models/favorite_verse.dart';

/// Pushes/pulls favorited verses to the `favorite_verses` table in Supabase.
/// Mirrors SyncRepository's pattern (RLS-scoped, no-ops with nobody signed
/// in) but kept separate since favorites are a distinct concern from
/// reading progress.
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
      };

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

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('favorite_verses')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .eq('chapter_number', chapterNumber)
        .eq('verse_number', verseNumber);
  }

  Future<List<FavoriteVerse>> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('favorite_verses').select().eq('user_id', userId);
    return rows.map((r) {
      final createdAt = DateTime.parse(r['created_at'] as String).toLocal();
      final updatedAt = r['updated_at'] as String?;
      return FavoriteVerse(
        bookId: r['book_id'] as String,
        chapterNumber: r['chapter_number'] as int,
        verseNumber: r['verse_number'] as int,
        color: FavoriteColor.fromName(r['color'] as String?),
        createdAt: createdAt,
        updatedAt: updatedAt == null ? createdAt : DateTime.parse(updatedAt).toLocal(),
      );
    }).toList();
  }
}
