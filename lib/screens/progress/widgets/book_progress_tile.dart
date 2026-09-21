import 'package:flutter/material.dart';

import '../../../data/repositories/book_repository.dart';
import '../book_chapters_screen.dart';

class BookProgressTile extends StatelessWidget {
  final BookProgress progress;

  const BookProgressTile({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final book = progress.book;
    final complete = progress.readCount >= book.chapterCount;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookChaptersScreen(book: book)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
