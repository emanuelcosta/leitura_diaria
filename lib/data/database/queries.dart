import '../models/chapter.dart';

/// A chapter joined with its book's display name, for list/card UIs.
class ChapterView {
  final Chapter chapter;
  final String bookName;
  final int bookOrder;

  const ChapterView({required this.chapter, required this.bookName, required this.bookOrder});

  String get label => '$bookName ${chapter.chapterNumber}';

  factory ChapterView.fromMap(Map<String, Object?> map) => ChapterView(
        chapter: Chapter.fromMap(map),
        bookName: map['name'] as String,
        bookOrder: map['book_order'] as int,
      );
}

const chapterWithBookSelect = '''
  SELECT chapters.*, books.name as name, books.book_order as book_order
  FROM chapters
  JOIN books ON books.id = chapters.book_id
''';
