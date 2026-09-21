import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/queries.dart';
import '../../data/models/book.dart';
import '../../state/reading_plan_provider.dart';
import '../../widgets/chapter_card.dart';

/// Lets the user mark any chapter of a book as read/unread on its own,
/// independent of the day it falls on in the plan (catch-up, reading ahead,
/// or just re-reading something already covered).
class BookChaptersScreen extends StatelessWidget {
  final Book book;

  const BookChaptersScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(book.name)),
      body: FutureBuilder<List<ChapterView>>(
        key: ValueKey('${book.id}_${plan.overallProgress.readCount}'),
        future: plan.getChaptersForBook(book.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chapters = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chapters.length,
            itemBuilder: (context, i) => ChapterCard(view: chapters[i]),
          );
        },
      ),
    );
  }
}
