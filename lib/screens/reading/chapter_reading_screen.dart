import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../../data/models/book.dart';
import '../../data/repositories/bible_text_repository.dart';
import '../../logic/bible_reference_parser.dart';
import '../../state/bookmark_provider.dart';
import '../../state/doubts_provider.dart';
import '../../state/favorites_provider.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/verse_notes_provider.dart';
import '../../widgets/book_mention_field.dart';
import '../../widgets/reference_text.dart';

/// Shared by every `ReferenceText` in the app (verse notes, doubt notes,
/// chapter notes) — lives here rather than inside the widget itself so
/// lib/widgets/ stays screen-agnostic (see ReferenceText's doc comment).
void openBibleReference(BuildContext context, BibleReference reference) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChapterReadingScreen(
        bookId: reference.book.id,
        bookOrder: reference.book.order,
        bookName: reference.book.name,
        chapterNumber: reference.chapterNumber,
        initialVerseNumber: reference.verseNumber,
      ),
    ),
  );
}

/// Verse-by-verse reading view for one chapter, with a favorite toggle per
/// verse and a translation switcher (ACF/ARC).
class ChapterReadingScreen extends StatefulWidget {
  final String bookId;
  final int bookOrder;
  final String bookName;
  final int chapterNumber;

  /// When set (e.g. arriving from search/favorites/comments results), that
  /// verse starts pre-selected — highlighted and scrolled into view — same
  /// as if the user had just tapped it.
  final int? initialVerseNumber;

  const ChapterReadingScreen({
    super.key,
    required this.bookId,
    required this.bookOrder,
    required this.bookName,
    required this.chapterNumber,
    this.initialVerseNumber,
  });

  @override
  State<ChapterReadingScreen> createState() => _ChapterReadingScreenState();
}

class _ChapterReadingScreenState extends State<ChapterReadingScreen> {
  final _bibleRepo = BibleTextRepository();
  late BibleTranslation _translation;

  // Cached synchronously (not a Future rebuilt per build) so the AppBar can
  // read verse text directly for the selected-verse action bar below —
  // verses only change on translation switch, not on every rebuild.
  List<String>? _verses;

  int? _selectedVerse;
  bool _multiSelectMode = false;
  Set<int> _multiSelected = {};
  final _initialVerseKey = GlobalKey();
  bool _scrolledToInitial = false;

  // Tracked locally instead of re-fetched from the DB on every toggle: a
  // fresh Future/FutureBuilder round-trip after marking read briefly showed
  // stale "not read" data while it resolved, making the button look like it
  // reverted. This updates instantly and matches what was just written.
  bool _isRead = false;
  bool _readStateLoaded = false;

  String get _chapterId => '${widget.bookId}-${widget.chapterNumber}';

  @override
  void initState() {
    super.initState();
    _translation = context.read<SettingsProvider>().translation;
    // Provisional — a reference (from a note, or the Livros quick-jump
    // search) only validates its chapter against Book.chapterCount, since
    // per-chapter verse counts aren't known without the chapter text itself
    // loading (async). _loadVerses() below re-validates once that arrives
    // and clears this if the verse turns out not to exist.
    _selectedVerse = widget.initialVerseNumber;
    _loadVerses();
    _loadReadState();
  }

  Future<void> _autoSaveBookmark({int? verseNumber}) {
    return context.read<BookmarkProvider>().save(
          bookId: widget.bookId,
          bookOrder: widget.bookOrder,
          bookName: widget.bookName,
          chapterNumber: widget.chapterNumber,
          verseNumber: verseNumber,
        );
  }

  Future<void> _loadVerses() async {
    final verses = await _bibleRepo.getChapterVerses(
      translation: _translation,
      bookOrder: widget.bookOrder,
      chapterNumber: widget.chapterNumber,
    );
    if (!mounted) return;
    final requestedVerse = widget.initialVerseNumber;
    setState(() {
      _verses = verses;
      if (_selectedVerse != null && _selectedVerse! > verses.length) {
        // The referenced verse doesn't exist in this chapter (e.g. a typo,
        // or a translation with different verse numbering) — fall back to
        // just opening the chapter instead of crashing on an out-of-range
        // index.
        _selectedVerse = null;
      }
    });
    if (requestedVerse != null && requestedVerse > verses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Versículo $requestedVerse não existe nesse capítulo (só tem ${verses.length}).',
          ),
        ),
      );
    }
    // "Continuar de onde parei" is automatic, not a manual save button:
    // simply opening a chapter is "the last text I entered", so it becomes
    // the bookmark right away — using the now-validated _selectedVerse, not
    // the raw (possibly out-of-range) widget.initialVerseNumber.
    _autoSaveBookmark(verseNumber: _selectedVerse);
    _scrollToInitialVerseOnce();
  }

  Future<void> _loadReadState() async {
    final chapter = await context.read<ReadingPlanProvider>().getChapter(_chapterId);
    if (!mounted) return;
    setState(() {
      _isRead = chapter?.chapter.isRead ?? false;
      _readStateLoaded = true;
    });
  }

  void _scrollToInitialVerseOnce() {
    if (_scrolledToInitial || widget.initialVerseNumber == null) return;
    _scrolledToInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _initialVerseKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 300));
      }
    });
  }

  Future<void> _markRead(bool isRead) async {
    setState(() => _isRead = isRead);
    await context.read<ReadingPlanProvider>().setChapterRead(_chapterId, isRead: isRead);
    // The last chapter marked read is another strong "where I stopped"
    // signal — re-save the bookmark so it reflects the just-finished spot,
    // not whatever verse happened to be selected before.
    if (isRead) await _autoSaveBookmark();
  }

  Book _currentBook(List<Book> books) => books.firstWhere((b) => b.id == widget.bookId);

  bool _hasPrevious(List<Book> books) =>
      widget.chapterNumber > 1 || books.any((b) => b.order == widget.bookOrder - 1);

  bool _hasNext(List<Book> books) {
    final chapterCount = _currentBook(books).chapterCount;
    return widget.chapterNumber < chapterCount || books.any((b) => b.order == widget.bookOrder + 1);
  }

  void _openChapter(String bookId, int bookOrder, String bookName, int chapterNumber) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChapterReadingScreen(
          bookId: bookId,
          bookOrder: bookOrder,
          bookName: bookName,
          chapterNumber: chapterNumber,
        ),
      ),
    );
  }

  void _goPrevious(List<Book> books) {
    if (widget.chapterNumber > 1) {
      _openChapter(widget.bookId, widget.bookOrder, widget.bookName, widget.chapterNumber - 1);
      return;
    }
    final previousBooks = books.where((b) => b.order == widget.bookOrder - 1).toList();
    if (previousBooks.isNotEmpty) {
      final b = previousBooks.first;
      _openChapter(b.id, b.order, b.name, b.chapterCount);
    }
  }

  void _goNext(List<Book> books) {
    final chapterCount = _currentBook(books).chapterCount;
    if (widget.chapterNumber < chapterCount) {
      _openChapter(widget.bookId, widget.bookOrder, widget.bookName, widget.chapterNumber + 1);
      return;
    }
    final nextBooks = books.where((b) => b.order == widget.bookOrder + 1).toList();
    if (nextBooks.isNotEmpty) {
      final b = nextBooks.first;
      _openChapter(b.id, b.order, b.name, 1);
    }
  }

  void _changeTranslation(BibleTranslation translation) {
    setState(() {
      _translation = translation;
      _verses = null;
    });
    _loadVerses();
    context.read<SettingsProvider>().setTranslation(translation);
  }

  Future<void> _copyVerse(int verseNumber, String text) async {
    await Clipboard.setData(
      ClipboardData(text: '$text (${widget.bookName} ${widget.chapterNumber}:$verseNumber)'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Versículo copiado.'), duration: Duration(seconds: 2)),
    );
  }

  /// Collapses consecutive verse numbers into ranges for the copied
  /// reference, e.g. [1,2,3,5,7,8] -> "1-3,5,7-8".
  String _formatVerseRange(List<int> sortedVerses) {
    final parts = <String>[];
    var start = sortedVerses.first;
    var prev = start;
    for (final v in sortedVerses.skip(1)) {
      if (v == prev + 1) {
        prev = v;
        continue;
      }
      parts.add(start == prev ? '$start' : '$start-$prev');
      start = v;
      prev = v;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return parts.join(',');
  }

  Future<void> _copySelectedVerses() async {
    final verses = _verses;
    if (verses == null || _multiSelected.isEmpty) return;
    final sorted = _multiSelected.toList()..sort();
    final buffer = StringBuffer();
    for (final v in sorted) {
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write('$v ${verses[v - 1]}');
    }
    buffer.write('\n(${widget.bookName} ${widget.chapterNumber}:${_formatVerseRange(sorted)})');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    final count = sorted.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count ${count == 1 ? 'versículo copiado' : 'versículos copiados'}.'),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      _multiSelectMode = false;
      _multiSelected = {};
    });
  }

  Future<void> _editNote(int verseNumber, String? currentNote) async {
    final notes = context.read<VerseNotesProvider>();
    final books = context.read<ReadingPlanProvider>().meta.books;
    final controller = TextEditingController(text: currentNote ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // The @Sigla autocomplete dropdown can push content taller than the
        // available height once the keyboard is up — scrollable lets the
        // dialog scroll instead of overflowing.
        scrollable: true,
        title: Text('Nota — ${widget.bookName} ${widget.chapterNumber}:$verseNumber'),
        content: BookMentionTextField(
          controller: controller,
          books: books,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'O que chamou sua atenção nesse versículo?',
            helperText: 'Dica: @Sigla cap vers linka outro texto (ex: @Jo 3 16)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (currentNote != null && currentNote.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Remover'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result != null) {
      await notes.setNote(widget.bookId, widget.chapterNumber, verseNumber, result);
    }
  }

  /// Marking a verse as a doubt always goes through this dialog (instead of
  /// a plain toggle) so there's a chance to jot down *why* — what was
  /// confusing — right at the moment, not relying on memory later. Already
  /// marked + no text change just edits the note; the "Remover" button is
  /// the only way to unmark. Uses a (remove, text) record rather than a
  /// plain String result so clearing the note and hitting "Salvar" can't be
  /// confused with tapping "Remover dúvida" — both would otherwise produce
  /// the same empty string.
  Future<void> _editDoubt(int verseNumber, {required bool isDoubt, String? currentNote}) async {
    final doubts = context.read<DoubtsProvider>();
    final books = context.read<ReadingPlanProvider>().meta.books;
    final controller = TextEditingController(text: currentNote ?? '');
    final result = await showDialog<({bool remove, String text})>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Dúvida — ${widget.bookName} ${widget.chapterNumber}:$verseNumber'),
        content: BookMentionTextField(
          controller: controller,
          books: books,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'O que você não entendeu? (opcional, ajuda a lembrar depois)',
            helperText: 'Dica: @Sigla cap vers linka outro texto (ex: @Jo 3 16)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (isDoubt)
            TextButton(
              onPressed: () => Navigator.pop(context, (remove: true, text: '')),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Remover dúvida'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, (remove: false, text: controller.text)),
            child: Text(isDoubt ? 'Salvar' : 'Marcar dúvida'),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result.remove) {
      await doubts.unmark(widget.bookId, widget.chapterNumber, verseNumber);
    } else if (isDoubt) {
      await doubts.updateNote(
        widget.bookId,
        widget.chapterNumber,
        verseNumber,
        result.text.isEmpty ? null : result.text,
      );
    } else {
      await doubts.mark(
        widget.bookId,
        widget.chapterNumber,
        verseNumber,
        note: result.text.isEmpty ? null : result.text,
      );
    }
  }

  /// Same contextual-toolbar slot the multi-select copy button uses — a
  /// single selected verse gets its actions (favoritar/copiar/nota/dúvida)
  /// there too, instead of inline under the verse text.
  PreferredSizeWidget _buildSelectedVerseAppBar(
    FavoritesProvider favorites,
    VerseNotesProvider notes,
    DoubtsProvider doubts,
  ) {
    final verseNumber = _selectedVerse!;
    final isFavorite = favorites.isFavorite(widget.bookId, widget.chapterNumber, verseNumber);
    final isDoubt = doubts.isDoubt(widget.bookId, widget.chapterNumber, verseNumber);
    final doubtNote = doubts.noteFor(widget.bookId, widget.chapterNumber, verseNumber);
    final note = notes.noteFor(widget.bookId, widget.chapterNumber, verseNumber);
    // Belt-and-suspenders: _selectedVerse is validated against the loaded
    // chapter in _loadVerses, but this guards the index directly too in
    // case that invariant is ever broken by a future change.
    final verses = _verses;
    final verseText = (verses != null && verseNumber >= 1 && verseNumber <= verses.length)
        ? verses[verseNumber - 1]
        : null;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Fechar seleção',
        onPressed: () => setState(() => _selectedVerse = null),
      ),
      title: Text('${widget.bookName} ${widget.chapterNumber}:$verseNumber'),
      actions: [
        IconButton(
          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          tooltip: isFavorite ? 'Remover dos favoritos' : 'Favoritar versículo',
          onPressed: () => favorites.toggle(widget.bookId, widget.chapterNumber, verseNumber),
        ),
        IconButton(
          icon: Icon(isDoubt ? Icons.help : Icons.help_outline),
          tooltip: isDoubt ? 'Editar/remover dúvida' : 'Marcar como dúvida (pesquisar depois)',
          onPressed: () => _editDoubt(verseNumber, isDoubt: isDoubt, currentNote: doubtNote),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copiar versículo',
          onPressed: verseText == null ? null : () => _copyVerse(verseNumber, verseText),
        ),
        IconButton(
          icon: Icon(note != null ? Icons.note : Icons.note_add_outlined),
          tooltip: note != null ? 'Editar nota' : 'Adicionar nota',
          onPressed: () => _editNote(verseNumber, note),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildMultiSelectAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancelar seleção',
        onPressed: () => setState(() {
          _multiSelectMode = false;
          _multiSelected = {};
        }),
      ),
      title: Text('${_multiSelected.length} ${_multiSelected.length == 1 ? 'selecionado' : 'selecionados'}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copiar selecionados',
          onPressed: _multiSelected.isEmpty ? null : _copySelectedVerses,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(SettingsProvider settings) {
    return AppBar(
      title: Text('${widget.bookName} ${widget.chapterNumber}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.text_decrease),
          tooltip: 'Diminuir fonte',
          onPressed: settings.fontScale <= minFontScale ? null : settings.decreaseFontScale,
        ),
        IconButton(
          icon: const Icon(Icons.text_increase),
          tooltip: 'Aumentar fonte',
          onPressed: settings.fontScale >= maxFontScale ? null : settings.increaseFontScale,
        ),
        PopupMenuButton<BibleTranslation>(
          tooltip: 'Tradução',
          initialValue: _translation,
          onSelected: _changeTranslation,
          itemBuilder: (context) => BibleTranslation.values
              .map((t) => PopupMenuItem(value: t, child: Text('${t.abbreviation} — ${t.label}')))
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_translation.abbreviation, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final notes = context.watch<VerseNotesProvider>();
    final doubts = context.watch<DoubtsProvider>();
    final settings = context.watch<SettingsProvider>();
    final books = context.watch<ReadingPlanProvider>().meta.books;
    final verses = _verses;
    return Scaffold(
      appBar: _multiSelectMode
          ? _buildMultiSelectAppBar()
          : _selectedVerse != null
              ? _buildSelectedVerseAppBar(favorites, notes, doubts)
              : _buildDefaultAppBar(settings),
      body: verses == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              // ListView.builder only builds items near the viewport, so the
              // target verse's GlobalKey wouldn't exist yet for
              // Scrollable.ensureVisible if it's far down the chapter. The
              // longest chapter (Salmos 119) is 176 short verses, so forcing
              // everything to build up front is cheap and avoids that.
              cacheExtent: widget.initialVerseNumber != null ? 100000 : null,
              itemCount: verses.length + 1,
              itemBuilder: (context, i) {
                if (i == verses.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        if (!_readStateLoaded)
                          const SizedBox(
                            height: 36,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (_isRead)
                          OutlinedButton.icon(
                            onPressed: () => _markRead(false),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Capítulo lido — desmarcar'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _markRead(true),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Marcar capítulo como lido'),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _hasPrevious(books) ? () => _goPrevious(books) : null,
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Capítulo anterior'),
                            ),
                            TextButton(
                              onPressed: _hasNext(books) ? () => _goNext(books) : null,
                              child: const Row(
                                children: [
                                  Text('Próximo capítulo'),
                                  Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final verseNumber = i + 1;
                final isFavorite = favorites.isFavorite(widget.bookId, widget.chapterNumber, verseNumber);
                final isDoubt = doubts.isDoubt(widget.bookId, widget.chapterNumber, verseNumber);
                final note = notes.noteFor(widget.bookId, widget.chapterNumber, verseNumber);
                final isMultiSelected = _multiSelected.contains(verseNumber);
                final isSelected = !_multiSelectMode && _selectedVerse == verseNumber;
                // Priority when not actively selected: selection (blue) >
                // dúvida (purple) > favorito (amber) > none. A verse can be
                // both favorited and doubted; the purple tint wins so
                // pending-research verses stay easy to spot while reading.
                Color? highlight() {
                  if (isDoubt) return Colors.deepPurple.withValues(alpha: 0.12);
                  if (isFavorite) return Colors.amber.withValues(alpha: 0.15);
                  return null;
                }

                return Container(
                  key: verseNumber == widget.initialVerseNumber ? _initialVerseKey : null,
                  color: _multiSelectMode
                      ? (isMultiSelected ? Colors.lightBlue.withValues(alpha: 0.25) : highlight())
                      : (isSelected ? Colors.lightBlue.withValues(alpha: 0.15) : highlight()),
                  child: InkWell(
                    onTap: () {
                      if (_multiSelectMode) {
                        setState(() {
                          if (isMultiSelected) {
                            _multiSelected.remove(verseNumber);
                            if (_multiSelected.isEmpty) _multiSelectMode = false;
                          } else {
                            _multiSelected.add(verseNumber);
                          }
                        });
                      } else {
                        setState(() => _selectedVerse = isSelected ? null : verseNumber);
                      }
                    },
                    onLongPress: _multiSelectMode
                        ? null
                        : () => setState(() {
                              _multiSelectMode = true;
                              _selectedVerse = null;
                              _multiSelected = {verseNumber};
                            }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style.copyWith(
                                    height: 1.4,
                                    fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) *
                                        settings.fontScale,
                                  ),
                              children: [
                                TextSpan(
                                  text: '$verseNumber ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold, fontSize: 12 * settings.fontScale),
                                ),
                                TextSpan(text: verses[i]),
                              ],
                            ),
                          ),
                          if (note != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.note, size: 14, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ReferenceText(
                                      text: note,
                                      books: books,
                                      onReferenceTap: openBibleReference,
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isDoubt && doubts.noteFor(widget.bookId, widget.chapterNumber, verseNumber) != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.help, size: 14, color: Colors.deepPurple),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ReferenceText(
                                      text: doubts.noteFor(widget.bookId, widget.chapterNumber, verseNumber)!,
                                      books: books,
                                      onReferenceTap: openBibleReference,
                                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.deepPurple),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
