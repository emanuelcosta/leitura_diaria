import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../../../logic/verse_query.dart';
import '../../../state/verse_search_provider.dart';

/// Removable chips for whatever filters are on, under the search box —
/// renders nothing when none are, so the basic screen stays just a search
/// bar. Seeing active filters matters: a forgotten "Só em Salmos" otherwise
/// looks like the search is broken.
class ActiveFiltersBar extends StatelessWidget {
  final VerseSearchProvider search;

  const ActiveFiltersBar({super.key, required this.search});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (search.mode != MatchMode.allWords)
        _chip(search.mode.label, () => search.setMode(MatchMode.allWords)),
      if (search.testament != null)
        _chip(search.testament == Testament.at ? 'Antigo Testamento' : 'Novo Testamento',
            () => search.setTestament(null)),
      if (search.category != null) _chip(search.category!.label, () => search.setCategory(null)),
      if (search.book != null) _chip(search.book!.name, () => search.setBook(null)),
      if (search.excluded.trim().isNotEmpty) _chip('Sem: ${search.excluded.trim()}', () => search.setExcluded('')),
      for (final c in search.conditions)
        if (c.text.trim().isNotEmpty) _chip('${c.op.label}: ${c.text.trim()}', () => search.removeCondition(c.id)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final chip in chips) Padding(padding: const EdgeInsets.only(right: 8), child: chip),
          if (chips.length > 1)
            TextButton(onPressed: search.clearFilters, child: const Text('Limpar tudo')),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteButtonTooltipMessage: 'Remover filtro',
      );
}
