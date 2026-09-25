import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/favorite_color.dart';
import '../state/settings_provider.dart';

/// What the user picked: a color to mark with, or null to remove the marker.
typedef MarkerChoice = ({FavoriteColor? color});

/// Color picker for marking a verse, like a highlighter: one row per
/// color with the name the user gave it in Configurações ("Promessas",
/// "Oração"...), so the meaning is right there when choosing. Returns null
/// if dismissed without choosing.
Future<MarkerChoice?> showMarkerPicker(
  BuildContext context, {
  required String title,
  FavoriteColor? current,
}) {
  return showModalBottomSheet<MarkerChoice>(
    context: context,
    showDragHandle: true,
    builder: (_) => MarkerPickerSheet(title: title, current: current),
  );
}

class MarkerPickerSheet extends StatelessWidget {
  final String title;
  final FavoriteColor? current;

  const MarkerPickerSheet({super.key, required this.title, this.current});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            for (final c in FavoriteColor.values)
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: c.color,
                  child: c == current ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                ),
                title: Text(settings.markerName(c)),
                subtitle: settings.isMarkerRenamed(c) ? Text(c.label) : null,
                selected: c == current,
                onTap: () => Navigator.of(context).pop<MarkerChoice>((color: c)),
              ),
            if (current != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.bookmark_remove_outlined, color: theme.colorScheme.error),
                title: Text('Remover marcador', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () => Navigator.of(context).pop<MarkerChoice>((color: null)),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Dê um nome a cada cor em Configurações → Marcadores.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
