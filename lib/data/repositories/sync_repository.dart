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

  Future<List<RemoteChapterProgress>> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('chapter_progress').select().eq('user_id', userId);
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
