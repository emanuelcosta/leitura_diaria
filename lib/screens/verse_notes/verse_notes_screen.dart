import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/models/verse_note.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/verse_notes_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/reference_text.dart';
import '../reading/chapter_reading_screen.dart';

/// Lists every verse-level comment/note across the whole Bible — the
/// verse-scoped counterpart to NotesListScreen (which lists chapter notes).
/// No own Scaffold/AppBar: it's one tab of NotesScreen, which owns the
/// shared AppBar via HomeShell.
class VerseNotesScreen extends StatefulWidget {
  const VerseNotesScreen({super.key});

  @override
  State<VerseNotesScreen> createState() => _VerseNotesScreenState();
}

class _VerseNotesScreenState extends State<VerseNotesScreen> {
  final _bookRepo = BookRepository();

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<VerseNotesProvider>();
    return FutureBuilder(
      future: Future.wait([notes.getAll(), _bookRepo.getAllBooks()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data![0] as List<VerseNote>;
        final allBooks = snapshot.data![1] as List<Book>;
        final books = {for (final b in allBooks) b.id: b};
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.note_add_outlined,
            message: 'Toque no ícone de nota abaixo de um versículo, na leitura\n'
                'do capítulo, para comentar sobre ele.',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, i) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final note = items[i];
            final book = books[note.bookId];
            if (book == null) return const SizedBox.shrink();
            return ListTile(
              title: Text('${book.name} ${note.chapterNumber}:${note.verseNumber}'),
              subtitle: ReferenceText(
                text: note.note,
                books: allBooks,
                onReferenceTap: openBibleReference,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(DateFormat('dd/MM/yy').format(note.updatedAt)),
              onTap: () => Navigator.of(context).push(
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
          },
        );
      },
    );
  }
}
