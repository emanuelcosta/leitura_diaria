import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/book.dart';
import '../../../data/repositories/bible_text_repository.dart';
import '../../../logic/text_normalize.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../state/settings_provider.dart';

/// What the picker returns. [verseNumber] is null when the user chose
/// "Ler capítulo inteiro".
typedef PassageSelection = ({Book book, int chapterNumber, int? verseNumber});

/// Book → chapter → verse picker, the standard "go to passage" pattern of
/// Bible apps: each step shows only what exists (real chapter and verse
/// counts), and the breadcrumb at the top jumps back to any earlier step.
///
/// [initialBook] (e.g. the chapter being read) opens straight at its
/// chapter step — changing chapter in the same book is the common case.
Future<PassageSelection?> showPassagePicker(BuildContext context, {Book? initialBook}) {
  return showModalBottomSheet<PassageSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: PassagePickerSheet(initialBook: initialBook),
    ),
  );
}

enum _Step { book, chapter, verse }

class PassagePickerSheet extends StatefulWidget {
  final Book? initialBook;

  const PassagePickerSheet({super.key, this.initialBook});

  @override
  State<PassagePickerSheet> createState() => _PassagePickerSheetState();
}

class _PassagePickerSheetState extends State<PassagePickerSheet> {
  final _bibleRepo = BibleTextRepository();
  final _filterController = TextEditingController();
  String _filter = '';

  late _Step _step = widget.initialBook == null ? _Step.book : _Step.chapter;
  late Book? _book = widget.initialBook;
  int? _chapter;
  Future<List<List<int>>>? _verseCounts;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<List<List<int>>> get _counts =>
      _verseCounts ??= _bibleRepo.getVerseCounts(context.read<SettingsProvider>().translation);

  void _pickBook(Book book) => setState(() {
        _book = book;
        _chapter = null;
        _step = _Step.chapter;
      });

  void _pickChapter(int chapter) => setState(() {
        _chapter = chapter;
        _step = _Step.verse;
      });

  void _finish({int? verse}) {
    Navigator.of(context).pop<PassageSelection>((book: _book!, chapterNumber: _chapter!, verseNumber: verse));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBreadcrumb(context),
        const Divider(height: 1),
        Expanded(
          child: switch (_step) {
            _Step.book => _buildBookStep(context),
            _Step.chapter => _buildChapterStep(context),
            _Step.verse => _buildVerseStep(context),
          },
        ),
      ],
    );
  }

  /// "Livro › João › 3" — each earlier part is tappable to go back to it.
  Widget _buildBreadcrumb(BuildContext context) {
    final theme = Theme.of(context);
    final book = _book;
    final chapter = _chapter;
    Widget crumb(String label, _Step target) {
      final current = _step == target;
      return TextButton(
        onPressed: current ? null : () => setState(() => _step = target),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
          disabledForegroundColor: theme.colorScheme.onSurface,
          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: current ? FontWeight.bold : null),
        ),
        child: Text(label),
      );
    }

    final separator = Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          if (_step != _Step.book)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () => setState(() => _step = _step == _Step.verse ? _Step.chapter : _Step.book),
            ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  crumb(book == null ? 'Escolha o livro' : book.name, _Step.book),
                  if (book != null && _step != _Step.book) ...[
                    separator,
                    crumb(chapter == null ? 'Capítulo' : '$chapter', _Step.chapter),
                  ],
                  if (_step == _Step.verse) ...[separator, crumb('Versículo', _Step.verse)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookStep(BuildContext context) {
    final books = context.read<ReadingPlanProvider>().meta.books;
    final query = normalizeForSearch(_filter.trim());
    final visible = query.isEmpty
        ? books
        : books
            .where((b) =>
                normalizeForSearch(b.name).contains(query) || normalizeForSearch(b.abbreviation).startsWith(query))
            .toList();
    final theme = Theme.of(context);

    Widget section(String title, Testament testament) {
      final list = visible.where((b) => b.testament == testament).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ),
          for (final b in list)
            ListTile(
              dense: true,
              selected: b.id == widget.initialBook?.id,
              leading: SizedBox(
                width: 40,
                child: Text(b.abbreviation, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(b.name),
              trailing: Text(
                '${b.chapterCount} cap.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              onTap: () => _pickBook(b),
            ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _filterController,
            decoration: const InputDecoration(
              hintText: 'Filtrar livros',
              prefixIcon: Icon(Icons.filter_list),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Nenhum livro com esse nome.'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    section('Antigo Testamento', Testament.at),
                    section('Novo Testamento', Testament.nt),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChapterStep(BuildContext context) {
    final book = _book!;
    return _NumberGrid(
      count: book.chapterCount,
      selected: _chapter,
      onTap: _pickChapter,
    );
  }

  Widget _buildVerseStep(BuildContext context) {
    final book = _book!;
    final chapter = _chapter!;
    return FutureBuilder<List<List<int>>>(
      future: _counts,
      builder: (context, snapshot) {
        final counts = snapshot.data;
        if (counts == null) return const Center(child: CircularProgressIndicator());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text('Ler ${book.name} $chapter inteiro'),
              ),
            ),
            Expanded(
              child: _NumberGrid(
                count: counts[book.order - 1][chapter - 1],
                onTap: (verse) => _finish(verse: verse),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Numbered buttons (chapters or verses) in a grid — big tap targets,
/// scannable at a glance, the way every Bible app lays these out.
class _NumberGrid extends StatelessWidget {
  final int count;
  final int? selected;
  final ValueChanged<int> onTap;

  const _NumberGrid({required this.count, required this.onTap, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final n = i + 1;
        final isSelected = n == selected;
        return Material(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onTap(n),
            child: Center(
              child: Text(
                '$n',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isSelected ? theme.colorScheme.onPrimary : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
