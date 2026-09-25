import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/book.dart';
import '../../../logic/verse_query.dart';
import '../../../state/verse_search_provider.dart';

/// The "advanced" half of the Buscar tab, kept out of the way in a bottom
/// sheet so the basic screen is only a search bar. Every change applies
/// immediately (results update behind the sheet) — no "Aplicar" step to
/// forget.
Future<void> showSearchFiltersSheet(BuildContext context) {
  final search = context.read<VerseSearchProvider>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The sheet's route is outside the tab's provider scope; hand it over.
    builder: (_) => ChangeNotifierProvider.value(value: search, child: const SearchFiltersSheet()),
  );
}

class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late final TextEditingController _excludedController;

  // One controller per E/OU condition row, by the condition's id.
  final Map<int, TextEditingController> _conditionControllers = {};

  @override
  void initState() {
    super.initState();
    _excludedController = TextEditingController(text: context.read<VerseSearchProvider>().excluded);
  }

  @override
  void dispose() {
    _excludedController.dispose();
    for (final c in _conditionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(({int id, LogicOp op, String text}) condition) =>
      _conditionControllers.putIfAbsent(condition.id, () => TextEditingController(text: condition.text));

  void _removeCondition(VerseSearchProvider search, int id) {
    _conditionControllers.remove(id)?.dispose();
    search.removeCondition(id);
  }

  void _clearAll(VerseSearchProvider search) {
    search.clearFilters();
    _excludedController.clear();
    for (final c in _conditionControllers.values) {
      c.dispose();
    }
    _conditionControllers.clear();
  }

  Widget _conditionRow(VerseSearchProvider search, ({int id, LogicOp op, String text}) condition) {
    return Padding(
      key: ValueKey(condition.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SegmentedButton<LogicOp>(
            segments: [
              for (final op in LogicOp.values) ButtonSegment(value: op, label: Text(op.label)),
            ],
            selected: {condition.op},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (s) => search.setConditionOp(condition.id, s.first),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controllerFor(condition),
              decoration: const InputDecoration(
                hintText: 'Palavras',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (text) => search.setConditionText(condition.id, text),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remover condição',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeCondition(search, condition.id),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<VerseSearchProvider>();
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Filtros', style: theme.textTheme.titleLarge)),
                    if (search.activeFilterCount > 0)
                      TextButton(onPressed: () => _clearAll(search), child: const Text('Limpar')),
                  ],
                ),
                label('Como combinar as palavras'),
                SegmentedButton<MatchMode>(
                  segments: const [
                    ButtonSegment(value: MatchMode.allWords, label: Text('Todas')),
                    ButtonSegment(value: MatchMode.anyWord, label: Text('Qualquer')),
                    ButtonSegment(value: MatchMode.exactPhrase, label: Text('Frase exata')),
                  ],
                  selected: {search.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => search.setMode(s.first),
                ),
                const SizedBox(height: 6),
                Text(search.mode.description,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                label('Mais condições (E / OU)'),
                for (final c in search.conditions) _conditionRow(search, c),
                Text(
                  search.conditions.isEmpty
                      ? 'Combine a busca com outras palavras. Ex: "não temas" OU "não tenhais medo"; '
                          'amor E próximo.'
                      : 'Lido de cima para baixo: cada condição se junta a tudo que vem antes dela.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: search.addCondition,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar condição'),
                  ),
                ),
                label('Onde buscar'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (value, text) in const [
                      (null, 'Bíblia toda'),
                      (Testament.at, 'Antigo Testamento'),
                      (Testament.nt, 'Novo Testamento'),
                    ])
                      ChoiceChip(
                        label: Text(text),
                        selected: search.testament == value,
                        onSelected: (_) => search.setTestament(value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BookCategory?>(
                  key: ValueKey('category-${search.testament}-${search.category}'),
                  initialValue: search.category,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas as categorias')),
                    for (final c in search.availableCategories) DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: search.setCategory,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Book?>(
                  key: ValueKey('book-${search.testament}-${search.category}-${search.book?.id}'),
                  initialValue: search.book,
                  isExpanded: true,
                  menuMaxHeight: 400,
                  decoration: const InputDecoration(labelText: 'Livro', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos os livros')),
                    for (final b in search.availableBooks) DropdownMenuItem(value: b, child: Text(b.name)),
                  ],
                  onChanged: search.setBook,
                ),
                label('Sem as palavras'),
                TextField(
                  controller: _excludedController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: morte guerra',
                    helperText: 'Versículos com qualquer uma destas palavras ficam de fora.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: search.setExcluded,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_resultsLabel(search)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The close button doubles as a live result count, so the user sees
  /// what the filters did without closing the sheet first.
  String _resultsLabel(VerseSearchProvider search) {
    final results = search.results;
    if (search.searching) return 'Buscando...';
    if (results == null) return 'Pronto';
    return results.length == 1 ? 'Ver 1 versículo' : 'Ver ${results.length} versículos';
  }
}
