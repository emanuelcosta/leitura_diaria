import 'package:flutter/material.dart';

import '../../../data/models/reading_bookmark.dart';
import '../../reading/chapter_reading_screen.dart';

/// "Continuar de onde parei" — jumps straight back to the saved reading
/// position (see BookmarkProvider / the bookmark icon in
/// ChapterReadingScreen's AppBar) without going through Livros again.
class ContinueReadingCard extends StatelessWidget {
  final ReadingBookmark bookmark;

  const ContinueReadingCard({super.key, required this.bookmark});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.bookmark),
        title: const Text('Continuar de onde parei', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(bookmark.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChapterReadingScreen(
              bookId: bookmark.bookId,
              bookOrder: bookmark.bookOrder,
              bookName: bookmark.bookName,
              chapterNumber: bookmark.chapterNumber,
              initialVerseNumber: bookmark.verseNumber,
              selectInitialVerse: false,
            ),
          ),
        ),
      ),
    );
  }
}
