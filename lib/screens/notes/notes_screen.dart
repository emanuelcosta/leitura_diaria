import 'package:flutter/material.dart';

import '../verse_notes/verse_notes_screen.dart';
import 'notes_list_screen.dart';

/// Unifies the two note-taking surfaces — chapter notes (NotesListScreen)
/// and verse comments (VerseNotesScreen) — under one "Notas" tab instead of
/// splitting them across a tab and a hidden "Mais" menu item, since to the
/// user both are just "things I wrote while reading."
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(text: 'Por capítulo'),
                Tab(text: 'Por versículo'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                NotesListScreen(),
                VerseNotesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
