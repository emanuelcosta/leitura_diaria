import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/favorite_color.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/section_header.dart';

/// Configurações → Marcadores: give each marker color a meaning for your
/// study ("Amarelo = Promessas"). The names show up in the color picker and
/// in the Marcadores filter. Kept on this device (a preference, like the
/// theme), not synced.
class MarkerNamesSection extends StatelessWidget {
  const MarkerNamesSection({super.key});

  Future<void> _rename(BuildContext context, SettingsProvider settings, FavoriteColor color) async {
    final controller = TextEditingController(text: settings.isMarkerRenamed(color) ? settings.markerName(color) : '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(backgroundColor: color.color, radius: 10),
            const SizedBox(width: 10),
            Text('Marcador ${color.label.toLowerCase()}'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'O que essa cor significa?',
            hintText: 'Ex: Promessas, Oração, Mandamentos',
            helperText: 'Deixe vazio para voltar a "${color.label}".',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await settings.setMarkerName(color, result);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Marcadores'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Dê um significado a cada cor para organizar seu estudo. Na leitura, '
            'selecione um versículo e toque na estrela para marcá-lo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        for (final c in FavoriteColor.values)
          ListTile(
            leading: CircleAvatar(backgroundColor: c.color, radius: 12),
            title: Text(settings.markerName(c)),
            subtitle: settings.isMarkerRenamed(c) ? Text(c.label) : null,
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () => _rename(context, settings, c),
          ),
      ],
    );
  }
}
