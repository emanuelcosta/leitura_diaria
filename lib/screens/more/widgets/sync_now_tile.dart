import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/bookmark_provider.dart';
import '../../../state/doubts_provider.dart';
import '../../../state/favorites_provider.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../state/verse_notes_provider.dart';

/// "Sincronizar agora": runs the same merge the sign-in does, on demand.
/// Every merge is a union (see lib/logic/sync_merge.dart), so tapping it can
/// never drop data that only exists on this device. Unlike the background
/// pushes, errors here are surfaced — the user explicitly asked for a sync.
class SyncNowTile extends StatefulWidget {
  const SyncNowTile({super.key});

  @override
  State<SyncNowTile> createState() => _SyncNowTileState();
}

class _SyncNowTileState extends State<SyncNowTile> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait([
        context.read<ReadingPlanProvider>().pullFromRemoteAndMerge(),
        context.read<FavoritesProvider>().pullFromRemoteAndMerge(),
        context.read<VerseNotesProvider>().pullFromRemoteAndMerge(),
        context.read<DoubtsProvider>().pullFromRemoteAndMerge(),
        context.read<BookmarkProvider>().pullFromRemoteAndMerge(),
      ]);
      messenger.showSnackBar(
        const SnackBar(content: Text('Dados sincronizados', style: TextStyle(color: Colors.white),), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Sincronizar agora falhou: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível sincronizar. Verifique sua conexão.')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _syncing
          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync),
      title: const Text('Sincronizar agora'),
      subtitle: const Text('Envia e recebe progresso, favoritos, notas e dúvidas'),
      enabled: !_syncing,
      onTap: _sync,
    );
  }
}
