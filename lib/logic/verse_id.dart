/// Splits a verse-level item id (`'$bookId-$chapterNumber-$verseNumber'`,
/// the convention of FavoriteVerse/VerseNote/DoubtVerse) back into its
/// parts. Parsed from the end so a book id containing "-" would still work.
/// Null for anything that isn't in that shape.
({String bookId, int chapterNumber, int verseNumber})? parseVerseId(String id) {
  final parts = id.split('-');
  if (parts.length < 3) return null;
  final verse = int.tryParse(parts.last);
  final chapter = int.tryParse(parts[parts.length - 2]);
  final bookId = parts.sublist(0, parts.length - 2).join('-');
  if (verse == null || chapter == null || bookId.isEmpty) return null;
  return (bookId: bookId, chapterNumber: chapter, verseNumber: verse);
}
