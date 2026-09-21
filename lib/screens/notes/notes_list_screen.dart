import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/queries.dart';
import '../../state/reading_plan_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/note_tile.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  Key _refreshKey = UniqueKey();

  void _refresh() => setState(() => _refreshKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return FutureBuilder<List<ChapterView>>(
      key: _refreshKey,
      future: plan.getChaptersWithNotes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data!;
        if (notes.isEmpty) {
          return const EmptyState(
            icon: Icons.sticky_note_2_outlined,
            message: 'Suas anotações sobre os capítulos lidos vão aparecer aqui.',
          );
        }
        return ListView.separated(
          itemCount: notes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => NoteTile(view: notes[i], books: plan.meta.books, onChanged: _refresh),
        );
      },
    );
  }
}
