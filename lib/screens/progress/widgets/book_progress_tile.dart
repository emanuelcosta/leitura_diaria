import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/book_repository.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../book_chapters_screen.dart';

class BookProgressTile extends StatelessWidget {
  final BookProgress progress;

  const BookProgressTile({super.key, required this.progress});

  Future<void> _markAll(BuildContext context, {required bool isRead}) async {
    final book = progress.book;
    final confirmed = await showConfirmDialog(
      context,
      title: isRead ? 'Marcar livro como lido' : 'Desmarcar livro',
      message: isRead
          ? 'Marcar todos os ${book.chapterCount} capítulos de ${book.name} como lidos?'
          : 'Desmarcar todos os capítulos lidos de ${book.name}? As notas desses capítulos também serão apagadas.',
      confirmLabel: isRead ? 'Marcar tudo' : 'Desmarcar tudo',
      destructive: !isRead,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<ReadingPlanProvider>().setBookRead(book.id, isRead: isRead);
  }

  @override
  Widget build(BuildContext context) {
    final book = progress.book;
    final complete = progress.readCount >= book.chapterCount;
    final started = progress.readCount > 0;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookChaptersScreen(book: book)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4, top: 2, bottom: 2),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                book.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.fraction.clamp(0, 1),
                  minHeight: 8,
                  color: complete ? Colors.green : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(
                '${progress.readCount}/${book.chapterCount}',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            PopupMenuButton<bool>(
              icon: const Icon(Icons.more_vert, size: 18, color: Colors.black38),
              tooltip: 'Marcar todos os capítulos',
              onSelected: (isRead) => _markAll(context, isRead: isRead),
              itemBuilder: (context) => [
                if (!complete)
                  const PopupMenuItem(value: true, child: Text('Marcar tudo como lido')),
                if (started)
                  const PopupMenuItem(value: false, child: Text('Desmarcar tudo')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
