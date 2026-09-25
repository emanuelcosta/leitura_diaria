import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/favorite_color.dart';
import '../../../state/settings_provider.dart';

/// Opens the favorite-color picker as a bottom sheet over the chapter text.
/// Picking a color saves it immediately (SettingsProvider), so favorited
/// verses behind the sheet repaint in real time — the sheet stays open so
/// the user can compare colors before closing it.
Future<void> showFavoriteColorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const FavoriteColorSheet(),
  );
}

class FavoriteColorSheet extends StatelessWidget {
  const FavoriteColorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final selected = settings.favoriteColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cor dos favoritos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final c in FavoriteColor.values)
                  _ColorOption(
                    option: c,
                    isSelected: c == selected,
                    onTap: () => settings.setFavoriteColor(c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final FavoriteColor option;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({required this.option, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                    : null,
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
            ),
            const SizedBox(height: 4),
            Text(option.label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
