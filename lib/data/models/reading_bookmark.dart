/// "Continuar de onde parei" — where the user last saved their place while
/// reading, independent of the daily plan (they might be reading ahead,
/// behind, or a totally different book). A single value, not a list: saving
/// a new spot replaces the previous one, like a physical bookmark.
class ReadingBookmark {
  final String bookId;
  final int bookOrder;
  final String bookName;
  final int chapterNumber;
  final int? verseNumber;
  final DateTime savedAt;

  const ReadingBookmark({
    required this.bookId,
    required this.bookOrder,
    required this.bookName,
    required this.chapterNumber,
    this.verseNumber,
    required this.savedAt,
  });

  String get label =>
      verseNumber != null ? '$bookName $chapterNumber:$verseNumber' : '$bookName $chapterNumber';
}
