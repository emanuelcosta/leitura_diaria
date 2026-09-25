import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/models/verse_note.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/settings_provider.dart';
import '../../state/verse_notes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/note_sheet.dart';
import '../notes/widgets/note_list_item.dart';
import '../reading/chapter_reading_screen.dart';
import '../../widgets/sync_refresh.dart';

/// Lists every verse-level comment/note across the whole Bible — the
/// verse-scoped counterpart to NotesListScreen (which lists chapter notes).
/// Each row shows the verse with the comment below it; tapping opens the
/// note sheet (read, edit, copy, delete, open in the chapter).
/// No own Scaffold/AppBar: it's one tab of NotesScreen, which owns the
/// shared AppBar via HomeShell.
class VerseNotesScreen extends StatefulWidget {
  const VerseNotesScreen({super.key});

  @override
  State<VerseNotesScreen> createState() => _VerseNotesScreenState();
}

class _VerseNotesScreenState extends State<VerseNotesScreen> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();

  Future<({List<VerseNote> notes, List<Book> books, Map<String, String?> verses})> _load(
    VerseNotesProvider provider,
    BibleTranslation translation,
  ) async {
    final (notes, books) = await (provider.getAll(), _bookRepo.getAllBooks()).wait;
    final byId = {for (final b in books) b.id: b};
    final verses = <String, String?>{};
    for (final n in notes) {
      final book = byId[n.bookId];
      if (book == null) continue;
      verses[n.id] = await _bibleRepo.getVerse(
        translation: translation,
        bookOrder: book.order,
        chapterNumber: n.chapterNumber,
        verseNumber: n.verseNumber,
      );
    }
    return (notes: notes, books: books, verses: verses);
  }

  void _open(VerseNotesProvider provider, VerseNote note, Book book, List<Book> books, String? verse) {
    showNoteSheet(
      context,
      title: '${book.name} ${note.chapterNumber}:${note.verseNumber}',
      kind: NoteKind.verse,
      books: books,
      onReferenceTap: previewBibleReference,
      initialText: note.note,
      verseText: Future.value(verse),
      date: note.updatedAt,
      onSave: (text) => provider.setNote(note.bookId, note.chapterNumber, note.verseNumber, text),
      onDelete: () => provider.setNote(note.bookId, note.chapterNumber, note.verseNumber, ''),
      onOpenChapter: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChapterReadingScreen(
            bookId: book.id,
            bookOrder: book.order,
            bookName: book.name,
            chapterNumber: note.chapterNumber,
            initialVerseNumber: note.verseNumber,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerseNotesProvider>();
    final translation = context.watch<SettingsProvider>().translation;
    return FutureBuilder(
      future: _load(provider, translation),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        if (data.notes.isEmpty) {
          return const SyncRefresh.fill(
            child: EmptyState(
              icon: Icons.note_add_outlined,
              message:
                  'Toque no ícone de nota abaixo de um versículo, na leitura\n'
                  'do capítulo, para comentar sobre ele.',
            ),
          );
        }
        final books = {for (final b in data.books) b.id: b};
        return SyncRefresh(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: data.notes.length,
            separatorBuilder: (context, i) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final note = data.notes[i];
              final book = books[note.bookId];
              if (book == null) return const SizedBox.shrink();
              final verse = data.verses[note.id];
              return NoteListItem(
                title: '${book.name} ${note.chapterNumber}:${note.verseNumber}',
                verseText: verse,
                note: note.note,
                date: note.updatedAt,
                books: data.books,
                accent: NoteKind.verse.accent(Theme.of(context).colorScheme),
                onTap: () => _open(provider, note, book, data.books, verse),
              );
            },
          ),
        );
      },
    );
  }
}
