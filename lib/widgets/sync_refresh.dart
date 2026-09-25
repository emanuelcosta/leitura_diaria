import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/sync_all.dart';

/// Pull down to sync: wraps a list so dragging it from the top runs the
/// same full sync as "Sincronizar agora" (pullAllFromRemote). Unlike the
/// silent background syncs, the user asked for this one, so failures and
/// "not signed in" are shown.
///
/// [child] must be a scrollable (ListView) with
/// `physics: const AlwaysScrollableScrollPhysics()` — without it a list
/// shorter than the screen can't be pulled. For a non-scrollable child —
/// typically an EmptyState — use [SyncRefresh.fill], so an empty list can
/// still be pulled to fetch what another device has.
class SyncRefresh extends StatelessWidget {
  final Widget child;
  final bool _fill;

  const SyncRefresh({super.key, required this.child}) : _fill = false;

  const SyncRefresh.fill({super.key, required this.child}) : _fill = true;

  Future<void> _sync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.read<AuthProvider>().isSignedIn) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Entre na sua conta (aba Mais) para sincronizar entre aparelhos.')),
      );
      return;
    }
    try {
      await pullAllFromRemote(context);
    } catch (e) {
      debugPrint('Sincronizar (puxar para atualizar) falhou: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível sincronizar. Verifique sua conexão.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Flutter only drags lists with touch by default; on Windows/macOS/Linux
    // the pull would be impossible with a mouse, so allow mouse drags too.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
      child: RefreshIndicator(
        onRefresh: () => _sync(context),
        child: _fill
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: child,
                  ),
                ),
              )
            : child,
      ),
    );
  }
}
