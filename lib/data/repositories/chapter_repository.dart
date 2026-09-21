import '../database/app_database.dart';
import '../database/queries.dart';

class OverallProgress {
  final int readCount;
  final int totalCount;

  const OverallProgress({required this.readCount, required this.totalCount});

  double get fraction => totalCount == 0 ? 0 : readCount / totalCount;
}

class ChapterRepository {
  Future<List<ChapterView>> getChaptersForPlanDay(int planDay) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '$chapterWithBookSelect WHERE chapters.plan_day = ? '
      'ORDER BY book_order ASC, chapter_number ASC',
      [planDay],
    );
    return rows.map(ChapterView.fromMap).toList();
  }

  Future<List<ChapterView>> getChaptersForBook(String bookId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '$chapterWithBookSelect WHERE chapters.book_id = ? ORDER BY chapters.chapter_number ASC',
      [bookId],
    );
    return rows.map(ChapterView.fromMap).toList();
  }

  Future<ChapterView?> getChapter(String chapterId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '$chapterWithBookSelect WHERE chapters.id = ?',
      [chapterId],
    );
    if (rows.isEmpty) return null;
    return ChapterView.fromMap(rows.first);
  }

  Future<List<ChapterView>> getChaptersWithNotes() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '$chapterWithBookSelect WHERE chapters.note IS NOT NULL AND chapters.note != "" '
      'ORDER BY chapters.read_at DESC',
    );
    return rows.map(ChapterView.fromMap).toList();
  }

  /// Marks a chapter read (optionally with a note) or unread. Unmarking a
  /// chapter clears its note along with its read state.
  Future<void> setRead(String chapterId, {required bool isRead, String? note}) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'chapters',
      {
        'is_read': isRead ? 1 : 0,
        'read_at': isRead ? DateTime.now().toIso8601String() : null,
        'note': isRead ? note : null,
      },
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  Future<void> setNote(String chapterId, String? note) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'chapters',
      {'note': note},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  Future<OverallProgress> getOverallProgress() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM chapters WHERE is_read = 1) as read_count,
        (SELECT COUNT(*) FROM chapters) as total_count
    ''');
    final row = result.first;
    return OverallProgress(
      readCount: row['read_count'] as int,
      totalCount: row['total_count'] as int,
    );
  }

  /// Distinct calendar dates (yyyy-MM-dd) on which at least one chapter was read.
  Future<List<DateTime>> getAllDistinctReadDates() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT date(read_at) as d FROM chapters
      WHERE is_read = 1 AND read_at IS NOT NULL
      ORDER BY d ASC
    ''');
    return rows.map((r) => DateTime.parse(r['d'] as String)).toList();
  }

  /// How many chapters were read on each calendar date (yyyy-MM-dd -> count), for the heatmap.
  Future<Map<String, int>> getReadCountsByDate() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT date(read_at) as d, COUNT(*) as c FROM chapters
      WHERE is_read = 1 AND read_at IS NOT NULL
      GROUP BY d
    ''');
    return {for (final r in rows) r['d'] as String: r['c'] as int};
  }

  /// Soft reset: clears read state everywhere without touching row identity.
  Future<void> resetAllProgress() async {
    final db = await AppDatabase.instance.database;
    await db.update('chapters', {'is_read': 0, 'read_at': null, 'note': null});
  }
}
