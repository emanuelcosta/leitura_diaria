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

  const DoubtVerse({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    this.note,
    required this.createdAt,
  });

  String get id => '$bookId-$chapterNumber-$verseNumber';

  factory DoubtVerse.fromMap(Map<String, Object?> map) => DoubtVerse(
        bookId: map['book_id'] as String,
        chapterNumber: map['chapter_number'] as int,
        verseNumber: map['verse_number'] as int,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'verse_number': verseNumber,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}
