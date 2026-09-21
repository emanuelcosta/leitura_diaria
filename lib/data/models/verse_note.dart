/// A note on a specific verse. Independent of favoriting (see
/// AppDatabase._createVerseNotes) — a row only exists while the note is
/// non-empty; clearing the text deletes the row.
class VerseNote {
  final String bookId;
  final int chapterNumber;
  final int verseNumber;
  final String note;
  final DateTime updatedAt;

  const VerseNote({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    required this.note,
    required this.updatedAt,
  });

  String get id => '$bookId-$chapterNumber-$verseNumber';

  factory VerseNote.fromMap(Map<String, Object?> map) => VerseNote(
        bookId: map['book_id'] as String,
        chapterNumber: map['chapter_number'] as int,
        verseNumber: map['verse_number'] as int,
        note: map['note'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'book_id': bookId,
        'chapter_number': chapterNumber,
        'verse_number': verseNumber,
        'note': note,
        'updated_at': updatedAt.toIso8601String(),
      };
}
