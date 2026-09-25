import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/book.dart';
import '../../../widgets/reference_text.dart';
import '../../reading/chapter_reading_screen.dart';

/// One row in the Notas lists (verse notes, doubts, chapter notes): the
/// reference, then the verse (when there is one) with the comment right
/// below it — the same order as in the reading screen. Tapping opens the
/// full note in the note sheet ([onTap]).
class NoteListItem extends StatelessWidget {
  final String title;
  final String? verseText;
  final String note;
  final DateTime? date;
  final List<Book> books;
  final Color accent;
  final bool italicNote;
  final VoidCallback onTap;

  const NoteListItem({
    super.key,
    required this.title,
    required this.note,
    required this.books,
    required this.accent,
    required this.onTap,
    this.verseText,
    this.date,
    this.italicNote = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;
    final date = this.date;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (date != null)
                  Text(DateFormat('dd/MM/yy').format(date), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
            if (verseText != null) ...[
              const SizedBox(height: 4),
              Text(
                verseText!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
                child: ReferenceText(
                  text: note,
                  books: books,
                  onReferenceTap: previewBibleReference,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: italicNote ? FontStyle.italic : null),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
