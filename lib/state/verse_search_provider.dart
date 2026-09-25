import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/book.dart';
import '../data/models/verse_search_result.dart';
import '../data/repositories/bible_text_repository.dart';
import '../data/repositories/search_history_repository.dart';
import '../logic/bible_reference_parser.dart';
import '../logic/verse_query.dart';

/// State for the Buscar tab: the query, the optional filters, and results.
///
/// Searches as you type (debounced), so there's no "Buscar" button to find.
/// A query that is entirely a reference ("joão 3 16") is resolved to
/// [reference] instead of being text-searched — typing a reference and
/// getting zero verse matches for the words "joao", "3", "16" is the most
/// common way this kind of search confuses people.
class VerseSearchProvider extends ChangeNotifier {
  final List<Book> _books;
  final BibleTextRepository _bibleRepo;
  final SearchHistoryRepository _historyRepo;
  final Duration _debounce;
  BibleTranslation _translation;

  VerseSearchProvider({
    required List<Book> books,
    required BibleTranslation translation,
    BibleTextRepository? bibleRepo,
    SearchHistoryRepository? historyRepo,
    Duration debounce = const Duration(milliseconds: 300),
  })  : _books = books,
        _translation = translation,
        _bibleRepo = bibleRepo ?? BibleTextRepository(),
        _historyRepo = historyRepo ?? SearchHistoryRepository(),
        _debounce = debounce {
    unawaited(_bibleRepo.warmUpSearch(translation).catchError((_) {}));
    unawaited(_loadRecent());
  }

  Timer? _timer;
  // Bumped on every search so a slow, older search finishing late can't
  // overwrite the results of a newer one.
  int _generation = 0;

  String _query = '';
  BibleReference? _reference;
  CompiledSearch? _compiled;
  List<VerseSearchResult>? _results;
  bool _searching = false;
  List<String> _recent = const [];

  MatchMode _mode = MatchMode.allWords;
  String _excluded = '';
  Testament? _testament;
  BookCategory? _category;
  Book? _book;

  // Extra E/OU conditions. Each has a stable id so the filters sheet can key
  // its rows (and their text fields) across adds/removes.
  List<({int id, LogicOp op, String text})> _conditions = const [];
  int _nextConditionId = 0;

  String get query => _query;
  BibleReference? get reference => _reference;
  CompiledSearch? get compiledQuery => _compiled;
  List<({int id, LogicOp op, String text})> get conditions => _conditions;
  bool get _hasConditions => _conditions.any((c) => c.text.trim().isNotEmpty);

  /// Null while there's no text search to show (empty query, reference, or
  /// only 1-letter words); empty list when it ran and found nothing.
  List<VerseSearchResult>? get results => _results;
  bool get searching => _searching;
  List<String> get recent => _recent;
  List<Book> get books => _books;
  BibleTranslation get translation => _translation;

  MatchMode get mode => _mode;
  String get excluded => _excluded;
  Testament? get testament => _testament;
  BookCategory? get category => _category;
  Book? get book => _book;

  /// For the badge on the Filtros button and the "clear" affordance.
  int get activeFilterCount => [
        _mode != MatchMode.allWords,
        _excluded.trim().isNotEmpty,
        _testament != null,
        _category != null,
        _book != null,
        _hasConditions,
      ].where((active) => active).length;

  /// Categories that make sense for the chosen testament.
  List<BookCategory> get availableCategories {
    final testament = _testament;
    if (testament == null) return BookCategory.values;
    return BookCategory.values
        .where((c) => _books.any((b) => b.category == c && b.testament == testament))
        .toList();
  }

  /// Books selectable in the "Livro" filter, narrowed by testament/category.
  List<Book> get availableBooks => _books.where((b) {
        if (_testament != null && b.testament != _testament) return false;
        if (_category != null && b.category != _category) return false;
        return true;
      }).toList();

  set translation(BibleTranslation value) {
    if (value == _translation) return;
    _translation = value;
    unawaited(_bibleRepo.warmUpSearch(value).catchError((_) {}));
    _scheduleSearch(immediate: true);
  }

  void setQuery(String value) {
    _query = value;
    _reference = parseSearchReference(value, _books);
    _scheduleSearch();
    notifyListeners();
  }

  void setMode(MatchMode value) {
    _mode = value;
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void setExcluded(String value) {
    _excluded = value;
    _scheduleSearch();
    notifyListeners();
  }

  void setTestament(Testament? value) {
    _testament = value;
    // Keep narrower filters only if they still fit the new testament.
    if (_category != null && !availableCategories.contains(_category)) _category = null;
    if (_book != null && value != null && _book!.testament != value) _book = null;
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void setCategory(BookCategory? value) {
    _category = value;
    if (_book != null && value != null && _book!.category != value) _book = null;
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void setBook(Book? value) {
    _book = value;
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  /// New conditions default to OU — the common case is alternate wordings
  /// of the same idea ("não temas" OU "não tenhais medo").
  void addCondition() {
    _conditions = [..._conditions, (id: _nextConditionId++, op: LogicOp.or, text: '')];
    notifyListeners();
  }

  void setConditionOp(int id, LogicOp op) {
    _conditions = [for (final c in _conditions) c.id == id ? (id: id, op: op, text: c.text) : c];
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void setConditionText(int id, String text) {
    _conditions = [for (final c in _conditions) c.id == id ? (id: id, op: c.op, text: text) : c];
    _scheduleSearch();
    notifyListeners();
  }

  void removeCondition(int id) {
    _conditions = _conditions.where((c) => c.id != id).toList();
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void clearConditions() {
    _conditions = const [];
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void clearFilters() {
    _mode = MatchMode.allWords;
    _excluded = '';
    _testament = null;
    _category = null;
    _book = null;
    _conditions = const [];
    _scheduleSearch(immediate: true);
    notifyListeners();
  }

  void _scheduleSearch({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) {
      unawaited(searchNow());
    } else {
      _timer = Timer(_debounce, () => unawaited(searchNow()));
    }
  }

  /// Runs the search for the current query/filters right away. Public so
  /// tests (and a keyboard "search" action) don't have to wait the debounce.
  Future<void> searchNow() async {
    _timer?.cancel();
    final generation = ++_generation;
    final compiled = _reference == null
        ? CompiledSearch.build(
            _query,
            mode: _mode,
            excluded: _excluded,
            conditions: [for (final c in _conditions) SearchCondition(op: c.op, text: c.text)],
          )
        : null;
    _compiled = compiled;
    if (compiled == null) {
      _results = null;
      _searching = false;
      notifyListeners();
      return;
    }

    _searching = true;
    notifyListeners();
    final book = _book;
    final candidates = book != null ? [book] : availableBooks;
    final results = await _bibleRepo.search(
      translation: _translation,
      candidateBooks: candidates,
      matches: compiled.matches,
    );
    if (generation != _generation) return;
    _results = results;
    _searching = false;
    notifyListeners();
  }

  Future<void> _loadRecent() async {
    _recent = await _historyRepo.getRecent();
    notifyListeners();
  }

  /// Saves the current query to the recent list — called when the user acts
  /// on it (opens a result, submits), not on every keystroke, so half-typed
  /// words don't pile up in the history.
  Future<void> rememberQuery() async {
    if (_query.trim().isEmpty) return;
    _recent = await _historyRepo.add(_query);
    notifyListeners();
  }

  Future<void> removeRecent(String query) async {
    _recent = await _historyRepo.remove(query);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    await _historyRepo.clear();
    _recent = const [];
    notifyListeners();
  }

  bool _disposed = false;

  // A search or history read can finish after the tab's provider is gone.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
