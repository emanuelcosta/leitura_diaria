import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../logic/bible_reference_parser.dart';
import '../../logic/text_normalize.dart';
import '../../state/reading_plan_provider.dart';
import '../../widgets/empty_state.dart';
import '../reading/chapter_reading_screen.dart';
import 'widgets/testament_section.dart';
import 'widgets/verse_search_panel.dart';

enum _ReadFilter { all, read, unread }

enum _GroupBy { testament, category }

class BookProgressScreen extends StatefulWidget {
  const BookProgressScreen({super.key});

  @override
  State<BookProgressScreen> createState() => _BookProgressScreenState();
}

class _BookProgressScreenState extends State<BookProgressScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _ReadFilter _readFilter = _ReadFilter.all;
  _GroupBy _groupBy = _GroupBy.testament;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySuggestion(Book book) {
    final text = '${book.abbreviation} ';
    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _query = text);
  }

  List<BookProgress> _applyFilters(List<BookProgress> books) {
    return books.where((b) {
      if (_query.isNotEmpty) {
        final query = normalizeForSearch(_query);
        final matchesName = normalizeForSearch(b.book.name).contains(query);
        final matchesAbbreviation = normalizeForSearch(b.book.abbreviation).contains(query);
        if (!matchesName && !matchesAbbreviation) return false;
      }
      final complete = b.readCount >= b.book.chapterCount;
      switch (_readFilter) {
        case _ReadFilter.all:
          return true;
        case _ReadFilter.read:
          return complete;
        case _ReadFilter.unread:
          return !complete;
      }
    }).toList();
  }

  List<TestamentSection> _sectionsFor(List<BookProgress> books) {
    if (_groupBy == _GroupBy.testament) {
      final at = books.where((b) => b.book.testament == Testament.at).toList();
      final nt = books.where((b) => b.book.testament == Testament.nt).toList();
      return [
        if (at.isNotEmpty) TestamentSection(title: 'Antigo Testamento', books: at),
        if (nt.isNotEmpty) TestamentSection(title: 'Novo Testamento', books: nt),
      ];
    }
    return BookCategory.values
        .map((c) => TestamentSection(
              title: c.label,
              books: books.where((b) => b.book.category == c).toList(),
            ))
        .where((s) => s.books.isNotEmpty)
        .toList();
  }

  /// Opened as a modal sheet (not inline) so it never pushes the book list
  /// down or covers it — the list stays visible and interactive behind it,
  /// dimmed, and a swipe/tap-outside dismisses back to it.
  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const VerseSearchPanel(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Buscar livro, ou ir direto a um versículo (ex: 1Pe 5 15)',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              if (looksLikePartialSigla(_query))
                Builder(builder: (context) {
                  final suggestions = suggestBooksForPartialSigla(_query, plan.meta.books);
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final book in suggestions)
                          ListTile(
                            dense: true,
                            leading: SizedBox(
                              width: 40,
                              child: Text(
                                book.abbreviation,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(book.name),
                            onTap: () => _applySuggestion(book),
                          ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_ReadFilter>(
                      segments: const [
                        ButtonSegment(value: _ReadFilter.all, label: Text('Todos')),
                        ButtonSegment(value: _ReadFilter.read, label: Text('Lidos')),
                        ButtonSegment(value: _ReadFilter.unread, label: Text('Não lidos')),
                      ],
                      selected: {_readFilter},
                      onSelectionChanged: (s) => setState(() => _readFilter = s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _groupBy == _GroupBy.testament
                        ? 'Agrupar por categoria'
                        : 'Agrupar por testamento',
                    icon: Icon(
                      _groupBy == _GroupBy.testament ? Icons.category_outlined : Icons.menu_book_outlined,
                    ),
                    onPressed: () => setState(() {
                      _groupBy =
                          _groupBy == _GroupBy.testament ? _GroupBy.category : _GroupBy.testament;
                    }),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Pesquisar textos',
                    icon: const Icon(Icons.manage_search),
                    onPressed: () => _openSearch(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<BookProgress>>(
            key: ValueKey(plan.overallProgress.readCount),
            future: plan.getProgressByBook(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final allBooks = snapshot.data!.map((p) => p.book).toList();
              final quickJump = parseDirectReference(_query, allBooks);
              final filtered = _applyFilters(snapshot.data!);
              if (filtered.isEmpty && quickJump == null) {
                return const EmptyState(
                  icon: Icons.search_off,
                  message: 'Nenhum livro encontrado com esse filtro.',
                );
              }
              final sections = _sectionsFor(filtered);
              final items = <Widget>[
                if (quickJump != null)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.arrow_forward),
                      title: Text(
                        quickJump.verseNumber != null
                            ? 'Ir para ${quickJump.book.name} ${quickJump.chapterNumber}:${quickJump.verseNumber}'
                            : 'Ir para ${quickJump.book.name} ${quickJump.chapterNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => openBibleReference(context, quickJump),
                    ),
                  ),
                ...sections,
              ];
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (context, i) => items[i],
              );
            },
          ),
        ),
      ],
    );
  }
}
