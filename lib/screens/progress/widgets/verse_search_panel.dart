import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/book.dart';
import '../../../data/models/verse_search_result.dart';
import '../../../data/repositories/bible_text_repository.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../logic/text_normalize.dart';
import '../../../state/settings_provider.dart';
import '../../../widgets/empty_state.dart';
import '../../reading/chapter_reading_screen.dart';

enum _LogicOp { and, or }

/// One search box. [op] connects it to the *accumulated result of every
/// condition before it* (left-to-right fold, no parentheses/precedence) —
/// it's ignored for the first condition, which has nothing to connect to.
class _SearchCondition {
  final controller = TextEditingController();
  _LogicOp op = _LogicOp.or;

  void dispose() => controller.dispose();
}

/// Full-text verse search, opened from the Livros tab as a modal bottom
/// sheet (see BookProgressScreen._openSearch) so it never covers the book
/// list behind it. Distinct from that screen's own "Buscar livro" field,
/// which filters the book list by name; this searches verse *content*
/// across the whole Bible. Expects to be laid out with a bounded height
/// (e.g. inside a sized modal sheet) since results fill the remaining space.
///
/// Supports multiple conditions chained with E/OU (AND/OR), e.g. "não temas"
/// OU "não tenha medo" — each condition is itself a word-AND match (every
/// word in that box must appear, any order, accent-insensitive), same as a
/// single-condition search always was.
class VerseSearchPanel extends StatefulWidget {
  const VerseSearchPanel({super.key});

  @override
  State<VerseSearchPanel> createState() => _VerseSearchPanelState();
}

class _VerseSearchPanelState extends State<VerseSearchPanel> {
  final _bookRepo = BookRepository();
  final _bibleRepo = BibleTextRepository();
  final List<_SearchCondition> _conditions = [_SearchCondition()];

  Testament? _testament;
  BookCategory? _category;
  bool _searching = false;
  List<VerseSearchResult>? _results;

  @override
  void dispose() {
    for (final c in _conditions) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCondition() => setState(() => _conditions.add(_SearchCondition()));

  void _removeCondition(int index) => setState(() {
        _conditions[index].dispose();
        _conditions.removeAt(index);
      });

  /// Words for each non-empty condition, pre-normalized once per search
  /// instead of per-verse.
  List<List<String>>? _activeConditionWords() {
    final active = _conditions.where((c) => c.controller.text.trim().isNotEmpty).toList();
    if (active.isEmpty) return null;
    return active
        .map((c) => normalizeForSearch(c.controller.text).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList())
        .toList();
  }

  List<_LogicOp> get _activeOps =>
      _conditions.where((c) => c.controller.text.trim().isNotEmpty).map((c) => c.op).toList();

  Future<void> _search() async {
    final conditionWords = _activeConditionWords();
    if (conditionWords == null) {
      setState(() => _results = null);
      return;
    }
    final ops = _activeOps;
    setState(() => _searching = true);
    final translation = context.read<SettingsProvider>().translation;
    final allBooks = await _bookRepo.getAllBooks();
    final candidates = allBooks.where((b) {
      if (_testament != null && b.testament != _testament) return false;
      if (_category != null && b.category != _category) return false;
      return true;
    }).toList();
    final results = await _bibleRepo.search(
      translation: translation,
      candidateBooks: candidates,
      matches: (normalized) {
        var result = conditionWords[0].every(normalized.contains);
        for (var i = 1; i < conditionWords.length; i++) {
          final conditionMatches = conditionWords[i].every(normalized.contains);
          result = ops[i] == _LogicOp.and ? (result && conditionMatches) : (result || conditionMatches);
        }
        return result;
      },
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pesquisar textos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var i = 0; i < _conditions.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              children: [
                if (i > 0) ...[
                  SizedBox(
                    width: 72,
                    child: DropdownButtonFormField<_LogicOp>(
                      initialValue: _conditions[i].op,
                      isDense: true,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: _LogicOp.and, child: Text('E')),
                        DropdownMenuItem(value: _LogicOp.or, child: Text('OU')),
                      ],
                      onChanged: (v) => setState(() => _conditions[i].op = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: _conditions[i].controller,
                    decoration: InputDecoration(
                      hintText: i == 0 ? 'Palavras ou frase (ex: não temas)' : 'Outra condição',
                      prefixIcon: i == 0 ? const Icon(Icons.search) : null,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                if (_conditions.length > 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    tooltip: 'Remover condição',
                    onPressed: () => _removeCondition(i),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addCondition,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar condição (E/OU)'),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButton<Testament?>(
              value: _testament,
              hint: const Text('Testamento'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todo o testamento')),
                DropdownMenuItem(value: Testament.at, child: Text('Antigo Testamento')),
                DropdownMenuItem(value: Testament.nt, child: Text('Novo Testamento')),
              ],
              onChanged: (v) => setState(() => _testament = v),
            ),
            DropdownButton<BookCategory?>(
              value: _category,
              hint: const Text('Categoria'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Toda categoria')),
                ...BookCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, size: 18),
            label: Text(_searching ? 'Buscando...' : 'Buscar'),
          ),
        ),
        const SizedBox(height: 8),
        if (_results != null) ...[
          Text(
            '${_results!.length} ${_results!.length == 1 ? 'resultado encontrado' : 'resultados encontrados'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
        ],
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    final results = _results;
    if (results == null) {
      return const EmptyState(
        icon: Icons.manage_search,
        message: 'Digite uma ou mais condições e toque em Buscar.\n'
            'Dentro de cada condição a ordem não importa — todas as palavras\n'
            'precisam aparecer no versículo, sem diferenciar acentos. Use "E"/\n'
            '"OU" para combinar condições (ex: "não temas" OU "não tenha medo").',
      );
    }
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        message: 'Nenhum versículo encontrado com esses termos e filtros.',
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = results[i];
        return ListTile(
          dense: true,
          title: Text('${r.bookName} ${r.chapterNumber}:${r.verseNumber}'),
          subtitle: Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChapterReadingScreen(
                bookId: r.bookId,
                bookOrder: r.bookOrder,
                bookName: r.bookName,
                chapterNumber: r.chapterNumber,
                initialVerseNumber: r.verseNumber,
              ),
            ),
          ),
        );
      },
    );
  }
}
