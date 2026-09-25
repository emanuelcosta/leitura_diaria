/// A verse marked "tenho dúvida" — the user wants to come back and research
/// it later. Independent of favoriting: same reference-only shape as
/// FavoriteVerse, but a distinct highlight/meaning (favorite = "this
/// matters to me", doubt = "I don't understand this yet"). [note] is
/// optional context on *why* — what they were thinking when they marked it.
class DoubtVerse {
  final String bookId;
  final int chapterNumber;
  final int verseNumber;
  final String? note;
  final DateTime createdAt;

  /// Last time the doubt was marked or its [note] edited — decides whose
  /// comment wins when two devices differ (newest wins, see mergeDoubts).
  final DateTime updatedAt;

  DoubtVerse({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    this.note,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  String get id => '$bookId-$chapterNumber-$verseNumber';

  factory DoubtVerse.fromMap(Map<String, Object?> map) {
    final createdAt = DateTime.parse(map['created_at'] as String);
    final updatedAt = map['updated_at'] as String?;
    return DoubtVerse(
      bookId: map['book_id'] as String,
      chapterNumber: map['chapter_number'] as int,
      verseNumber: map['verse_number'] as int,
      note: map['note'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt == null ? createdAt : DateTime.parse(updatedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'verse_number': verseNumber,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
