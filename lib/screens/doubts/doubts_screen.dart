import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/models/doubt_verse.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/doubts_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reference_text.dart';
import '../reading/chapter_reading_screen.dart';

/// Verses marked "tenho dúvida" — pending to research/understand later.
/// Mirrors FavoritesScreen's structure; a distinct list since a doubt is a
/// different kind of highlight from a favorite.
class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key});

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();

  @override
  Widget build(BuildContext context) {
    final doubts = context.watch<DoubtsProvider>();
    final translation = context.watch<SettingsProvider>().translation;
    return Scaffold(
      appBar: AppBar(title: const Text('Dúvidas pendentes')),
      body: FutureBuilder(
        future: Future.wait([doubts.getAll(), _bookRepo.getAllBooks()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data![0] as List<DoubtVerse>;
          final allBooks = snapshot.data![1] as List<Book>;
          final books = {for (final b in allBooks) b.id: b};
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.help_outline,
              message: 'Toque no ícone de dúvida ao lado de um versículo, na leitura\n'
                  'do capítulo, para guardá-lo aqui e pesquisar depois.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doubt = items[i];
              final book = books[doubt.bookId];
              if (book == null) return const SizedBox.shrink();
              return ListTile(
                title: Text('${book.name} ${doubt.chapterNumber}:${doubt.verseNumber}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<List<String>>(
                      future: _bibleRepo.getChapterVerses(
                        translation: translation,
                        bookOrder: book.order,
                        chapterNumber: doubt.chapterNumber,
                      ),
                      builder: (context, verseSnapshot) {
                        final text = verseSnapshot.data?[doubt.verseNumber - 1];
                        if (text == null) return const SizedBox.shrink();
                        return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
                      },
                    ),
                    if (doubt.note != null && doubt.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ReferenceText(
                          text: doubt.note!,
                          books: allBooks,
                          onReferenceTap: openBibleReference,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.deepPurple),
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.help, color: Colors.deepPurple[400]),
                  tooltip: 'Remover das dúvidas',
                  onPressed: () => doubts.unmark(doubt.bookId, doubt.chapterNumber, doubt.verseNumber),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChapterReadingScreen(
                      bookId: book.id,
                      bookOrder: book.order,
                      bookName: book.name,
                      chapterNumber: doubt.chapterNumber,
                      initialVerseNumber: doubt.verseNumber,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
