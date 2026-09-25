import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/database/queries.dart';
import '../../../data/models/book.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../widgets/note_sheet.dart';
import '../../reading/chapter_reading_screen.dart';
import 'note_list_item.dart';

/// A chapter note in the "Por capítulo" list. Tapping opens the note sheet
/// (read, edit, copy, delete, open the chapter).
class NoteTile extends StatelessWidget {
  final ChapterView view;
  final List<Book> books;
  final VoidCallback onChanged;

  const NoteTile({super.key, required this.view, required this.books, required this.onChanged});

  Future<void> _save(BuildContext context, String text) async {
    await context.read<ReadingPlanProvider>().setChapterNote(view.chapter.id, text.isEmpty ? null : text);
    onChanged();
  }

  void _open(BuildContext context) {
    final plan = context.read<ReadingPlanProvider>();
    showNoteSheet(
      context,
      title: view.label,
      kind: NoteKind.chapter,
      books: books,
      onReferenceTap: previewBibleReference,
      initialText: view.chapter.note ?? '',
      date: view.chapter.readAt,
      onSave: (text) => _save(context, text),
      onDelete: () async {
        await plan.setChapterNote(view.chapter.id, null);
        onChanged();
      },
      onOpenChapter: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChapterReadingScreen(
            bookId: view.chapter.bookId,
            bookOrder: view.bookOrder,
            bookName: view.bookName,
            chapterNumber: view.chapter.chapterNumber,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NoteListItem(
      title: view.label,
      note: view.chapter.note ?? '',
      date: view.chapter.readAt,
      books: books,
      accent: NoteKind.chapter.accent(Theme.of(context).colorScheme),
      onTap: () => _open(context),
    );
  }
}
