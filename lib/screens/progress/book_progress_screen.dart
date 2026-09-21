import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../state/reading_plan_provider.dart';
import 'widgets/testament_section.dart';

class BookProgressScreen extends StatelessWidget {
  const BookProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return FutureBuilder<List<BookProgress>>(
      key: ValueKey(plan.overallProgress.readCount),
      future: plan.getProgressByBook(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snapshot.data!;
        final at = books.where((b) => b.book.testament == Testament.at).toList();
        final nt = books.where((b) => b.book.testament == Testament.nt).toList();
        return ListView(
          children: [
            TestamentSection(title: 'Antigo Testamento', books: at),
            const Divider(height: 1),
            TestamentSection(title: 'Novo Testamento', books: nt),
          ],
        );
      },
    );
  }
}
