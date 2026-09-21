import 'package:flutter/material.dart';

import '../dictionary/dictionary_screen.dart';
import '../doubts/doubts_screen.dart';
import '../favorites/favorites_screen.dart';
import '../heatmap/heatmap_screen.dart';
import '../notes/notes_screen.dart';
import '../progress/book_progress_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

enum _MoreAction { favorites, doubts, dictionary }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Início', 'Livros', 'Constância', 'Notas'];

  static const _tabs = [
    HomeScreen(),
    BookProgressScreen(),
    HeatmapScreen(),
    NotesScreen(),
  ];

  void _openMoreAction(_MoreAction action) {
    final screen = switch (action) {
      _MoreAction.favorites => const FavoritesScreen(),
      _MoreAction.doubts => const DoubtsScreen(),
      _MoreAction.dictionary => const DictionaryScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          PopupMenuButton<_MoreAction>(
            tooltip: 'Mais',
            onSelected: _openMoreAction,
            // A labeled button instead of the bare 3-dot icon — Favoritos,
            // Dúvidas pendentes and Dicionário are used often enough that a
            // completely unlabeled overflow icon was easy to miss.
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apps_outlined),
                  SizedBox(width: 4),
                  Text('Mais'),
                ],
              ),
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MoreAction.favorites,
                child: ListTile(leading: Icon(Icons.star_outline), title: Text('Favoritos')),
              ),
              PopupMenuItem(
                value: _MoreAction.doubts,
                child: ListTile(leading: Icon(Icons.help_outline), title: Text('Dúvidas pendentes')),
              ),
              PopupMenuItem(
                value: _MoreAction.dictionary,
                child: ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Dicionário bíblico')),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Livros'),
          NavigationDestination(icon: Icon(Icons.calendar_view_month_outlined), selectedIcon: Icon(Icons.calendar_view_month), label: 'Constância'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notas'),
        ],
      ),
    );
  }
}
