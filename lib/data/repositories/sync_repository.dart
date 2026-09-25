import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chapter.dart';

typedef RemoteChapterProgress = ({
  String bookId,
  int chapterNumber,
  bool isRead,
  DateTime? readAt,
  String? note,
});

/// Pushes/pulls chapter read-state to the `chapter_progress` table in
/// Supabase. Every call is scoped to the signed-in user by RLS; with nobody
/// signed in, pushes are skipped and pulls return an empty list.
class SyncRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, Object?> _rowFor(String userId, Chapter chapter) => {
        'user_id': userId,
        'book_id': chapter.bookId,
        'chapter_number': chapter.chapterNumber,
        'is_read': chapter.isRead,
        'read_at': chapter.readAt?.toIso8601String(),
        'note': chapter.note,
      };

  Future<void> pushChapter(Chapter chapter) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('chapter_progress').upsert(_rowFor(userId, chapter));
  }

  Future<void> pushAll(List<Chapter> chapters) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || chapters.isEmpty) return;
    final rows = chapters.map((c) => _rowFor(userId, c)).toList();
    await _client.from('chapter_progress').upsert(rows);
  }

  /// PostgREST caps each response (1000 rows by default on Supabase) and the
  /// Bible has 1189 chapters — every chapter is pushed, read or not — so this
  /// pages through with a stable order until a short page comes back.
  static const _pageSize = 1000;

  Future<List<RemoteChapterProgress>> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = <Map<String, dynamic>>[];
    for (var from = 0;; from += _pageSize) {
      final page = await _client
          .from('chapter_progress')
          .select()
          .eq('user_id', userId)
          .order('book_id')
          .order('chapter_number')
          .range(from, from + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) break;
    }
    return rows
        .map((r) => (
              bookId: r['book_id'] as String,
              chapterNumber: r['chapter_number'] as int,
              isRead: r['is_read'] as bool,
              readAt: r['read_at'] == null ? null : DateTime.parse(r['read_at'] as String),
              note: r['note'] as String?,
            ))
        .toList();
  }
}
