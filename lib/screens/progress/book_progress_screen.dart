import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/repositories/book_repository.dart';
import '../../logic/text_normalize.dart';
import '../../state/reading_plan_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/testament_section.dart';
import '../../widgets/sync_refresh.dart';

enum _ReadFilter { all, read, unread }

enum _GroupBy { testament, category }

/// The Livros tab: every book with its reading progress, filterable by name
/// and read state, grouped by testament or category. The name box only
/// filters this list — verses and references are searched in the Buscar tab.
class BookProgressScreen extends StatefulWidget {
  const BookProgressScreen({super.key});

  @override
  State<BookProgressScreen> createState() => _BookProgressScreenState();
}

class _BookProgressScreenState extends State<BookProgressScreen> {
  final _nameController = TextEditingController();
  String _nameQuery = '';
  _ReadFilter _readFilter = _ReadFilter.all;
  _GroupBy _groupBy = _GroupBy.testament;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<BookProgress> _applyFilter(List<BookProgress> books) {
    final query = normalizeForSearch(_nameQuery.trim());
    return books.where((b) {
      if (query.isNotEmpty &&
          !normalizeForSearch(b.book.name).contains(query) &&
          !normalizeForSearch(b.book.abbreviation).contains(query)) {
        return false;
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
        .map((c) => TestamentSection(title: c.label, books: books.where((b) => b.book.category == c).toList()))
        .where((s) => s.books.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Filtrar livros (ex: Salmos, Jo)',
              prefixIcon: const Icon(Icons.filter_list),
              suffixIcon: _nameQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpar filtro',
                      onPressed: () {
                        _nameController.clear();
                        setState(() => _nameQuery = '');
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _nameQuery = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
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
                tooltip: _groupBy == _GroupBy.testament ? 'Agrupar por categoria' : 'Agrupar por testamento',
                icon: Icon(_groupBy == _GroupBy.testament ? Icons.category_outlined : Icons.menu_book_outlined),
                onPressed: () => setState(() {
                  _groupBy = _groupBy == _GroupBy.testament ? _GroupBy.category : _GroupBy.testament;
                }),
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
              final sections = _sectionsFor(_applyFilter(snapshot.data!));
              if (sections.isEmpty) {
                return SyncRefresh.fill(
                  child: EmptyState(
                    icon: _nameQuery.trim().isNotEmpty ? Icons.search_off : Icons.menu_book_outlined,
                    message: _nameQuery.trim().isNotEmpty
                        ? 'Nenhum livro encontrado com esse nome.'
                        : _readFilter == _ReadFilter.read
                        ? 'Nenhum livro lido por completo ainda.'
                        : 'Todos os livros já foram lidos!',
                  ),
                );
              }
              return SyncRefresh(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sections.length,
                  separatorBuilder: (context, i) => const Divider(height: 1),
                  itemBuilder: (context, i) => sections[i],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
