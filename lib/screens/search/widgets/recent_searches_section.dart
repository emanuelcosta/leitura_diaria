import 'package:flutter/material.dart';

/// What the Buscar tab shows before anything is typed: recent searches (if
/// any) and a few examples, so a first-time user sees what the box accepts
/// — words, phrases *and* references — instead of a blank screen.
class RecentSearchesSection extends StatelessWidget {
  final VoidCallback onPickPassage;
  final List<String> recent;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  const RecentSearchesSection({
    super.key,
    required this.onPickPassage,
    required this.recent,
    required this.onSelect,
    required this.onRemove,
    required this.onClear,
  });

  static const _examples = ['amor', 'não temas', 'João 3 16', 'Salmos 23', 'graça fé'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // For people who'd rather tap than type a reference.
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Ir para uma passagem'),
            subtitle: const Text('Escolha o livro, o capítulo e o versículo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onPickPassage,
          ),
        ),
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text('Buscas recentes', style: theme.textTheme.titleSmall)),
                TextButton(onPressed: onClear, child: const Text('Limpar')),
              ],
            ),
          ),
          for (final q in recent)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(q),
              onTap: () => onSelect(q),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remover do histórico',
                onPressed: () => onRemove(q),
              ),
            ),
          const Divider(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Experimente', style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _examples) ActionChip(label: Text(e), onPressed: () => onSelect(e)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Digite palavras para achar versículos, ou uma referência (ex: "Jo 3 16", '
            '"1 Pedro 5 7") para ir direto a ela. Acentos não importam. '
            'Use aspas para uma frase exata, e o botão de filtros para buscar só em um livro, '
            'testamento ou categoria.',
            style: muted,
          ),
        ),
      ],
    );
  }
}
