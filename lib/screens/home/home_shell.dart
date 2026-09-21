import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../heatmap/heatmap_screen.dart';
import '../notes/notes_list_screen.dart';
import '../progress/book_progress_screen.dart';
import '../settings/settings_screen.dart';
import '../today/today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Hoje', 'Painel', 'Progresso', 'Constância', 'Notas'];

  static const _tabs = [
    TodayScreen(),
    DashboardScreen(),
    BookProgressScreen(),
    HeatmapScreen(),
    NotesListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
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
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Livros'),
          NavigationDestination(icon: Icon(Icons.calendar_view_month_outlined), selectedIcon: Icon(Icons.calendar_view_month), label: 'Constância'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notas'),
        ],
      ),
    );
  }
}
