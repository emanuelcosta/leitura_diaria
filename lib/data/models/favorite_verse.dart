import 'favorite_color.dart';

/// A favorited (marked) verse reference, with its marker [color]. Not tied
/// to a translation — the same marker shows up regardless of which
/// translation (ACF/ARC) is currently selected for reading.
class FavoriteVerse {
  final String bookId;
  final int chapterNumber;
  final int verseNumber;
  final FavoriteColor color;
  final DateTime createdAt;

  /// Last time the color changed — decides which device's color wins when
  /// syncing (newest wins).
  final DateTime updatedAt;

  FavoriteVerse({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    this.color = FavoriteColor.amber,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Deterministic id, mirrors the `'$bookId-$chapterNumber'` chapter id
  /// convention from SeedLoader.
  String get id => '$bookId-$chapterNumber-$verseNumber';

  factory FavoriteVerse.fromMap(Map<String, Object?> map) {
    final createdAt = DateTime.parse(map['created_at'] as String);
    final updatedAt = map['updated_at'] as String?;
    return FavoriteVerse(
      bookId: map['book_id'] as String,
      chapterNumber: map['chapter_number'] as int,
      verseNumber: map['verse_number'] as int,
      color: FavoriteColor.fromName(map['color'] as String?),
      createdAt: createdAt,
      updatedAt: updatedAt == null ? createdAt : DateTime.parse(updatedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'verse_number': verseNumber,
        'color': color.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  FavoriteVerse withColor(FavoriteColor newColor, DateTime at) => FavoriteVerse(
        bookId: bookId,
        chapterNumber: chapterNumber,
        verseNumber: verseNumber,
        color: newColor,
        createdAt: createdAt,
        updatedAt: at,
      );
}
