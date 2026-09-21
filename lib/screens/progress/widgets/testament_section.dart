import 'package:flutter/material.dart';

import '../../../data/repositories/book_repository.dart';
import 'book_progress_tile.dart';

class TestamentSection extends StatelessWidget {
  final String title;
  final List<BookProgress> books;

  const TestamentSection({super.key, required this.title, required this.books});

  @override
  Widget build(BuildContext context) {
    final totalChapters = books.fold<int>(0, (sum, b) => sum + b.book.chapterCount);
    final readChapters = books.fold<int>(0, (sum, b) => sum + b.readCount);
    final missingChapters = totalChapters - readChapters;

    final totalBooks = books.length;
    final completeBooks = books.where((b) => b.readCount >= b.book.chapterCount).length;
    final missingBooks = totalBooks - completeBooks;

    final subtitle = missingChapters == 0
        ? 'Completo — $totalBooks livros, $totalChapters capítulos'
        : 'Faltam $missingBooks de $totalBooks livros · $missingChapters de $totalChapters capítulos';

    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      children: books.map((b) => BookProgressTile(progress: b)).toList(),
    );
  }
}
