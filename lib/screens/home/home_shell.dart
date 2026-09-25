import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/connectivity_service.dart';
import '../../state/auth_provider.dart';
import '../../state/sync_all.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const _searchIndex = 2;

  /// Minimum gap between resume syncs, so flipping between apps doesn't
  /// fire a full pull every time.
  static const _resumeSyncInterval = Duration(minutes: 1);

  int _index = 0;
  final _searchFocus = FocusNode();
  DateTime? _lastResumeSync;
  StreamSubscription<void>? _reconnectSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Back online with the app open: send what was done offline (deletions,
    // failed pushes) right away. Skips the resume throttle — the previous
    // attempt most likely failed for being offline. Plugin errors (e.g. no
    // network manager on a Linux desktop) just leave this trigger off.
    _reconnectSub = ConnectivityService().onReconnected.listen(
      (_) => _backgroundSync(force: true),
      onError: (_) {},
    );
  }

  /// The startup/sign-in pull only runs when the app is launched fresh. On a
  /// phone the app usually just comes back from the background, so without
  /// this a device left open kept showing stale data — most visibly "onde
  /// parei" — until a restart or "Sincronizar agora".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _backgroundSync();
  }

  void _backgroundSync({bool force = false}) {
    if (!mounted || !context.read<AuthProvider>().isSignedIn) return;
    final now = DateTime.now();
    final last = _lastResumeSync;
    if (!force && last != null && now.difference(last) < _resumeSyncInterval) return;
    _lastResumeSync = now;
    // Background pull: failures (offline, etc.) are swallowed on purpose,
    // same as the startup pull — "Sincronizar agora" is where errors show.
    unawaited(pullAllFromRemote(context).catchError((_) => const <void>[]));
  }

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
    WidgetsBinding.instance.removeObserver(this);
    _reconnectSub?.cancel();
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
