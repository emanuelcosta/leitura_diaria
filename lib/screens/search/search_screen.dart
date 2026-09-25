import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/verse_search_result.dart';
import '../../logic/bible_reference_parser.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/verse_search_provider.dart';
import '../../widgets/empty_state.dart';
import '../reading/chapter_reading_screen.dart';
import '../reading/widgets/passage_picker_sheet.dart';
import 'widgets/active_filters_bar.dart';
import 'widgets/recent_searches_section.dart';
import 'widgets/reference_result_card.dart';
import 'widgets/search_filters_sheet.dart';
import 'widgets/verse_result_tile.dart';

/// The Buscar tab: one box for both "find verses with these words" and "go
/// to this reference". Basic by default — a search bar, recent searches,
/// results as you type — with the advanced options (how words combine,
/// testament/category/book, excluded words) behind the Filtros button.
///
/// Owns its [VerseSearchProvider] (scoped to this tab, not app-wide): no
/// other screen reads search state, and the tab lives in HomeShell's
/// IndexedStack, so the query/results survive switching tabs anyway.
class SearchScreen extends StatelessWidget {
  /// Given by HomeShell so it can close the keyboard when leaving the tab.
  final FocusNode? focusNode;

  const SearchScreen({super.key, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<SettingsProvider, VerseSearchProvider>(
      create: (context) => VerseSearchProvider(
        books: context.read<ReadingPlanProvider>().meta.books,
        translation: context.read<SettingsProvider>().translation,
      ),
      update: (_, settings, search) => search!..translation = settings.translation,
      child: _SearchView(focusNode: focusNode),
    );
  }
}

class _SearchView extends StatefulWidget {
  final FocusNode? focusNode;

  const _SearchView({this.focusNode});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setText(VerseSearchProvider search, String text) {
    _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    search.setQuery(text);
  }

  void _openReference(VerseSearchProvider search, BibleReference reference) {
    search.rememberQuery();
    openBibleReference(context, reference);
  }

  Future<void> _pickPassage() async {
    FocusScope.of(context).unfocus();
    final selection = await showPassagePicker(context);
    if (selection == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReadingScreen(
          bookId: selection.book.id,
          bookOrder: selection.book.order,
          bookName: selection.book.name,
          chapterNumber: selection.chapterNumber,
          initialVerseNumber: selection.verseNumber,
        ),
      ),
    );
  }

  void _openResult(VerseSearchProvider search, VerseSearchResult r) {
    search.rememberQuery();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterReadingScreen(
          bookId: r.bookId,
          bookOrder: r.bookOrder,
          bookName: r.bookName,
          chapterNumber: r.chapterNumber,
          initialVerseNumber: r.verseNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = context.watch<VerseSearchProvider>();
    final filterCount = search.activeFilterCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: widget.focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Palavras ou referência (ex: Jo 3 16)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Limpar busca',
                            onPressed: () => _setText(search, ''),
                          ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: search.setQuery,
                  onSubmitted: (_) {
                    search.searchNow();
                    search.rememberQuery();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Escolher livro, capítulo e versículo',
                icon: const Icon(Icons.menu_book_outlined),
                onPressed: _pickPassage,
              ),
              IconButton(
                tooltip: filterCount == 0 ? 'Filtros' : 'Filtros ($filterCount ativos)',
                icon: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => showSearchFiltersSheet(context),
              ),
            ],
          ),
        ),
        ActiveFiltersBar(search: search),
        SizedBox(height: 2, child: search.searching ? const LinearProgressIndicator() : null),
        Expanded(child: _buildBody(search)),
      ],
    );
  }

  Widget _buildBody(VerseSearchProvider search) {
    // Only E/OU conditions filled (main box empty) still counts as a search.
    if (search.query.trim().isEmpty && search.compiledQuery == null) {
      return RecentSearchesSection(
        onPickPassage: _pickPassage,
        recent: search.recent,
        onSelect: (q) => _setText(search, q),
        onRemove: search.removeRecent,
        onClear: search.clearRecent,
      );
    }

    final reference = search.reference;
    if (reference != null) {
      return ListView(
        children: [
          ReferenceResultCard(
            reference: reference,
            translation: search.translation,
            onOpen: () => _openReference(search, reference),
          ),
        ],
      );
    }

    final query = search.compiledQuery;
    final results = search.results;
    if (query == null) {
      return const EmptyState(
        icon: Icons.keyboard,
        message: 'Continue digitando — use pelo menos uma palavra com 2 letras.',
      );
    }
    if (results == null) return const SizedBox.shrink(); // first search still running
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: search.activeFilterCount > 0
            ? 'Nenhum versículo encontrado.\nTente remover alguns filtros.'
            : 'Nenhum versículo encontrado.\nTente menos palavras ou outra forma de escrever.',
      );
    }

    final bookCount = results.map((r) => r.bookId).toSet().length;
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: results.length + 1,
      separatorBuilder: (context, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1, indent: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${results.length} ${results.length == 1 ? 'versículo' : 'versículos'} '
              'em $bookCount ${bookCount == 1 ? 'livro' : 'livros'} · ${search.translation.abbreviation}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          );
        }
        final r = results[i - 1];
        return VerseResultTile(result: r, query: query, onTap: () => _openResult(search, r));
      },
    );
  }
}
