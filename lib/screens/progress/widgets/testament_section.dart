import 'package:flutter/material.dart';

import '../../../data/repositories/book_repository.dart';
import 'book_progress_tile.dart';

class TestamentSection extends StatelessWidget {
  final String title;
  final List<BookProgress> books;

  const TestamentSection({super.key, required this.title, required this.books});

  @override
  Widget build(BuildContext context) {
    final read = books.fold<int>(0, (sum, b) => sum + b.readCount);
    final total = books.fold<int>(0, (sum, b) => sum + b.book.chapterCount);
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$read / $total capítulos'),
      children: books.map((b) => BookProgressTile(progress: b)).toList(),
    );
  }
}
