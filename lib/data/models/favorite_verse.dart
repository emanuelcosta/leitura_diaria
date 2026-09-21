/// A favorited verse reference. Not tied to a translation — the same
/// favorite shows up regardless of which translation (ACF/ARC) is currently
/// selected for reading.
class FavoriteVerse {
  final String bookId;
  final int chapterNumber;
  final int verseNumber;
  final DateTime createdAt;

  const FavoriteVerse({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    required this.createdAt,
  });

  /// Deterministic id, mirrors the `'$bookId-$chapterNumber'` chapter id
  /// convention from SeedLoader.
  String get id => '$bookId-$chapterNumber-$verseNumber';

  factory FavoriteVerse.fromMap(Map<String, Object?> map) => FavoriteVerse(
        bookId: map['book_id'] as String,
        chapterNumber: map['chapter_number'] as int,
        verseNumber: map['verse_number'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'verse_number': verseNumber,
        'created_at': createdAt.toIso8601String(),
      };
}
