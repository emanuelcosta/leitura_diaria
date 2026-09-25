import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/models/favorite_color.dart';
import '../../data/models/favorite_verse.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/favorites_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/marker_picker_sheet.dart';
import '../reading/chapter_reading_screen.dart';

/// "Marcadores": every marked (favorited) verse, color-coded, with a filter
/// per color — the colors carry the names the user gave them in
/// Configurações (e.g. only "Promessas"). Tapping a verse opens it in the
/// chapter; the colored marker on the right changes its color or removes it.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();
  FavoriteColor? _filter;

  Future<void> _changeMarker(FavoritesProvider favorites, FavoriteVerse f, Book book) async {
    final choice = await showMarkerPicker(
      context,
      title: 'Marcador de ${book.name} ${f.chapterNumber}:${f.verseNumber}',
      current: f.color,
    );
    if (choice == null) return;
    final color = choice.color;
    if (color == null) {
      await favorites.remove(f.bookId, f.chapterNumber, f.verseNumber);
    } else if (color != f.color) {
      await favorites.setColor(f.bookId, f.chapterNumber, f.verseNumber, color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final settings = context.watch<SettingsProvider>();
    final translation = settings.translation;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Marcadores')),
      body: FutureBuilder(
        future: Future.wait([favorites.getAll(), _bookRepo.getAllBooks()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data![0] as List<FavoriteVerse>;
          final books = {for (final b in snapshot.data![1] as List<Book>) b.id: b};
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.star_border,
              message: 'Na leitura, selecione um versículo e toque na estrela\n'
                  'para marcá-lo com uma cor.',
            );
          }
          // Only colors actually in use get a filter chip.
          final usedColors = FavoriteColor.values.where((c) => all.any((f) => f.color == c)).toList();
          final filter = usedColors.contains(_filter) ? _filter : null;
          final items = filter == null ? all : all.where((f) => f.color == filter).toList();

          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Todos (${all.length})'),
                        selected: filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                    ),
                    for (final c in usedColors)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: CircleAvatar(backgroundColor: c.color, radius: 7),
                          label: Text('${settings.markerName(c)} (${all.where((f) => f.color == c).length})'),
                          selected: filter == c,
                          onSelected: (_) => setState(() => _filter = filter == c ? null : c),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final favorite = items[i];
                    final book = books[favorite.bookId];
                    if (book == null) return const SizedBox.shrink();
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 5, color: favorite.color.color),
                          Expanded(
                            child: ListTile(
                              title: Text('${book.name} ${favorite.chapterNumber}:${favorite.verseNumber}'),
                              subtitle: FutureBuilder<String?>(
                                future: _bibleRepo.getVerse(
                                  translation: translation,
                                  bookOrder: book.order,
                                  chapterNumber: favorite.chapterNumber,
                                  verseNumber: favorite.verseNumber,
                                ),
                                builder: (context, verseSnapshot) {
                                  final text = verseSnapshot.data;
                                  if (text == null) return const SizedBox.shrink();
                                  return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
                                },
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.star, color: favorite.color.color),
                                tooltip: '${settings.markerName(favorite.color)} — trocar cor ou remover',
                                onPressed: () => _changeMarker(favorites, favorite, book),
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
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (filter != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Mostrando só "${settings.markerName(filter)}"',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
