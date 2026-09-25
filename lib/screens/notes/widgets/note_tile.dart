import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/database/queries.dart';
import '../../../data/models/book.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../widgets/book_mention_field.dart';
import '../../../widgets/reference_text.dart';
import '../../reading/chapter_reading_screen.dart';

class NoteTile extends StatelessWidget {
  final ChapterView view;
  final List<Book> books;
  final VoidCallback onChanged;

  const NoteTile({super.key, required this.view, required this.books, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: view.chapter.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(view.label),
        content: BookMentionTextField(
          controller: controller,
          books: books,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'Dica: @Sigla cap vers linka outro texto (ex: @Jo 3 16)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await context.read<ReadingPlanProvider>().setChapterNote(
            view.chapter.id,
            result.isEmpty ? null : result,
          );
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readAt = view.chapter.readAt;
    return ListTile(
      title: Text(view.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: ReferenceText(
        text: view.chapter.note ?? '',
        books: books,
        onReferenceTap: previewBibleReference,
      ),
      trailing: readAt != null ? Text(DateFormat('dd/MM/yy').format(readAt)) : null,
      onTap: () => _edit(context),
    );
  }
}
