import 'package:flutter/material.dart';

import '../doubts/doubts_screen.dart';
import '../verse_notes/verse_notes_screen.dart';
import 'notes_list_screen.dart';

/// Unifies everything the user writes or flags while reading — chapter notes
/// (NotesListScreen), verse comments (VerseNotesScreen) and "dúvida" verses
/// (DoubtsScreen, a note with an extra "preciso pesquisar isso" flag) — under
/// one "Notas" tab instead of splitting them across a tab and a hidden menu.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(text: 'Por capítulo'),
                Tab(text: 'Por versículo'),
                Tab(text: 'Dúvidas'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                NotesListScreen(),
                VerseNotesScreen(),
                DoubtsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
