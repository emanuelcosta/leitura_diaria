class VerseSearchResult {
  final String bookId;
  final String bookName;
  final int bookOrder;
  final int chapterNumber;
  final int verseNumber;
  final String text;

  const VerseSearchResult({
    required this.bookId,
    required this.bookName,
    required this.bookOrder,
    required this.chapterNumber,
    required this.verseNumber,
    required this.text,
  });
}
