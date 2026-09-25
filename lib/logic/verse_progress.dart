/// Progress weighted by verses: sums the verse counts of the read chapters
/// over the Bible's total. [verseCounts] is `[bookOrder - 1][chapterNumber - 1]`
/// (see BibleTextRepository.getVerseCounts). Refs outside the table are
/// ignored rather than throwing, so a mismatched ref can't break the home tab.
({int read, int total}) computeVerseProgress(
  List<List<int>> verseCounts,
  Iterable<({int bookOrder, int chapterNumber})> readChapters,
) {
  var total = 0;
  for (final book in verseCounts) {
    for (final count in book) {
      total += count;
    }
  }

  var read = 0;
  for (final ref in readChapters) {
    final bookIndex = ref.bookOrder - 1;
    final chapterIndex = ref.chapterNumber - 1;
    if (bookIndex < 0 || bookIndex >= verseCounts.length) continue;
    final chapters = verseCounts[bookIndex];
    if (chapterIndex < 0 || chapterIndex >= chapters.length) continue;
    read += chapters[chapterIndex];
  }

  return (read: read, total: total);
}
