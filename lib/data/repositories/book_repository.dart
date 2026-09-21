import '../database/app_database.dart';
import '../models/book.dart';

class BookProgress {
  final Book book;
  final int readCount;

  const BookProgress({required this.book, required this.readCount});

  double get fraction => book.chapterCount == 0 ? 0 : readCount / book.chapterCount;
}

class BookRepository {
  Future<List<Book>> getAllBooks() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('books', orderBy: 'book_order ASC');
    return rows.map(Book.fromMap).toList();
  }

  /// One row per book, with how many of its chapters are marked read.
  Future<List<BookProgress>> getProgressByBook() async {
    final db = await AppDatabase.instance.database;
    final books = await getAllBooks();
    final rows = await db.rawQuery('''
      SELECT book_id, COUNT(*) as read_count
      FROM chapters
      WHERE is_read = 1
      GROUP BY book_id
    ''');
    final readCountByBook = <String, int>{
      for (final row in rows) row['book_id'] as String: row['read_count'] as int,
    };
    return books
        .map((book) => BookProgress(book: book, readCount: readCountByBook[book.id] ?? 0))
        .toList();
  }
}
