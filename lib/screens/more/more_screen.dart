import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../dictionary/dictionary_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/auth_dialog.dart';
import 'widgets/sync_now_tile.dart';

/// The app's 4th tab: account + the tools and preferences that don't belong
/// on Início/Livros/Notas — replaces what used to be an app-bar "Mais" popup
/// plus a separate gear icon, both easy to miss up in the corner. Conta
/// lives here (not in SettingsScreen) so the gear-flavored "Configurações"
/// stays purely about app preferences. Named "Mais" (not "Menu") since the
/// bottom nav itself is already the menu — this is just one item in it.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta',
      message: 'Seu progresso continua salvo neste aparelho. Você pode entrar novamente '
          'a qualquer momento para voltar a sincronizar.',
      confirmLabel: 'Sair',
    );
    if (confirmed && context.mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return ListView(
      children: [
        const SectionHeader(title: 'Conta'),
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Conta'),
          subtitle: Text(
            auth.isSignedIn
                ? 'Sincronizado como ${auth.user!.email}'
                : 'Entrar para sincronizar entre aparelhos',
          ),
          trailing: auth.isSignedIn
              ? TextButton(onPressed: () => _signOut(context), child: const Text('Sair'))
              : null,
          onTap: auth.isSignedIn ? null : () => showAuthDialog(context),
        ),
        if (auth.isSignedIn) const SyncNowTile(),
        const SectionHeader(title: 'Ferramentas'),
        ListTile(
          leading: const Icon(Icons.star_outline),
          title: const Text('Favoritos'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FavoritesScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('Dicionário bíblico'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DictionaryScreen()),
          ),
        ),
        const SectionHeader(title: 'App'),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Configurações'),
          subtitle: const Text('Leitura, notificações, dados'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
