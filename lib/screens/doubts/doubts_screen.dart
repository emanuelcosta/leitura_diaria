import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/models/doubt_verse.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/doubts_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/note_sheet.dart';
import '../notes/widgets/note_list_item.dart';
import '../reading/chapter_reading_screen.dart';

/// Verses marked "tenho dúvida" — pending to research/understand later.
/// Each row shows the verse with the doubt's comment below it; tapping opens
/// the note sheet (read, edit the comment, copy, remove, open in the
/// chapter). Removing lives in the sheet, behind a confirmation — a
/// one-tap remove icon on the row was too easy to hit by accident.
/// No own Scaffold/AppBar: it's one tab of NotesScreen (a dúvida is really
/// just a note with an extra "preciso pesquisar isso" flag). When pushed
/// standalone (from the Início summary card), the caller wraps it in its
/// own Scaffold — see DoubtsSummaryCard.
class DoubtsScreen extends StatefulWidget {
  const DoubtsScreen({super.key});

  @override
  State<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends State<DoubtsScreen> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();

  Future<({List<DoubtVerse> doubts, List<Book> books, Map<String, String?> verses})> _load(
    DoubtsProvider provider,
    BibleTranslation translation,
  ) async {
    final (doubts, books) = await (provider.getAll(), _bookRepo.getAllBooks()).wait;
    final byId = {for (final b in books) b.id: b};
    final verses = <String, String?>{};
    for (final d in doubts) {
      final book = byId[d.bookId];
      if (book == null) continue;
      verses[d.id] = await _bibleRepo.getVerse(
        translation: translation,
        bookOrder: book.order,
        chapterNumber: d.chapterNumber,
        verseNumber: d.verseNumber,
      );
    }
    return (doubts: doubts, books: books, verses: verses);
  }

  void _open(DoubtsProvider provider, DoubtVerse doubt, Book book, List<Book> books, String? verse) {
    showNoteSheet(
      context,
      title: '${book.name} ${doubt.chapterNumber}:${doubt.verseNumber}',
      kind: NoteKind.doubt,
      books: books,
      onReferenceTap: previewBibleReference,
      initialText: doubt.note ?? '',
      verseText: Future.value(verse),
      date: doubt.createdAt,
      onSave: (text) =>
          provider.updateNote(doubt.bookId, doubt.chapterNumber, doubt.verseNumber, text.isEmpty ? null : text),
      onDelete: () => provider.unmark(doubt.bookId, doubt.chapterNumber, doubt.verseNumber),
      onOpenChapter: () => Navigator.of(context).push(
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DoubtsProvider>();
    final translation = context.watch<SettingsProvider>().translation;
    return FutureBuilder(
      future: _load(provider, translation),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        if (data.doubts.isEmpty) {
          return const EmptyState(
            icon: Icons.help_outline,
            message: 'Toque no ícone de dúvida ao lado de um versículo, na leitura\n'
                'do capítulo, para guardá-lo aqui e pesquisar depois.',
          );
        }
        final books = {for (final b in data.books) b.id: b};
        return ListView.separated(
          itemCount: data.doubts.length,
          separatorBuilder: (context, i) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final doubt = data.doubts[i];
            final book = books[doubt.bookId];
            if (book == null) return const SizedBox.shrink();
            final verse = data.verses[doubt.id];
            return NoteListItem(
              title: '${book.name} ${doubt.chapterNumber}:${doubt.verseNumber}',
              verseText: verse,
              note: doubt.note ?? '',
              date: doubt.createdAt,
              books: data.books,
              accent: NoteKind.doubt.accent(Theme.of(context).colorScheme),
              italicNote: true,
              onTap: () => _open(provider, doubt, book, data.books, verse),
            );
          },
        );
      },
    );
  }
}
