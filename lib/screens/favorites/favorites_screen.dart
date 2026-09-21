import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/favorite_verse.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/favorites_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../reading/chapter_reading_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final translation = context.watch<SettingsProvider>().translation;
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder(
        future: Future.wait([favorites.getAll(), _bookRepo.getAllBooks()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data![0] as List<FavoriteVerse>;
          final books = {for (final b in snapshot.data![1] as List) b.id: b};
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.star_border,
              message: 'Toque na estrela ao lado de um versículo, na leitura do\n'
                  'capítulo, para guardá-lo aqui.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final favorite = items[i];
              final book = books[favorite.bookId];
              if (book == null) return const SizedBox.shrink();
              return ListTile(
                title: Text('${book.name} ${favorite.chapterNumber}:${favorite.verseNumber}'),
                subtitle: FutureBuilder<List<String>>(
                  future: _bibleRepo.getChapterVerses(
                    translation: translation,
                    bookOrder: book.order,
                    chapterNumber: favorite.chapterNumber,
                  ),
                  builder: (context, verseSnapshot) {
                    final text = verseSnapshot.data?[favorite.verseNumber - 1];
                    if (text == null) return const SizedBox.shrink();
                    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
                  },
                ),
                trailing: IconButton(
                  icon: Icon(Icons.star, color: Colors.amber[700]),
                  tooltip: 'Remover dos favoritos',
                  onPressed: () => favorites.toggle(favorite.bookId, favorite.chapterNumber, favorite.verseNumber),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChapterReadingScreen(
                      bookId: book.id,
                      bookOrder: book.order,
                      bookName: book.name,
                      chapterNumber: favorite.chapterNumber,
                      initialVerseNumber: favorite.verseNumber,
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
