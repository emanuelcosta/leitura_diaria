import 'package:flutter/material.dart';

import '../more/more_screen.dart';
import '../notes/notes_screen.dart';
import '../progress/book_progress_screen.dart';
import '../search/search_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _searchIndex = 2;

  int _index = 0;
  final _searchFocus = FocusNode();

  static const _titles = ['Início', 'Livros', 'Buscar', 'Notas', 'Mais'];

  late final List<Widget> _tabs = [
    const HomeScreen(),
    const BookProgressScreen(),
    SearchScreen(focusNode: _searchFocus),
    const NotesScreen(),
    const MoreScreen(),
  ];

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int i) {
    // Leaving a tab shouldn't carry the search keyboard along.
    if (_index == _searchIndex && i != _searchIndex) _searchFocus.unfocus();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Livros'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notas'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Mais'),
        ],
      ),
    );
  }
}
