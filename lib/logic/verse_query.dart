import 'text_normalize.dart';

/// How the words typed in the search box combine — picked in the filters
/// sheet instead of typed operators (E/OU), which basic users don't know.
enum MatchMode {
  allWords('Todas as palavras', 'O versículo precisa ter todas as palavras, em qualquer ordem.'),
  anyWord('Qualquer palavra', 'O versículo precisa ter pelo menos uma das palavras.'),
  exactPhrase('Frase exata', 'As palavras precisam aparecer juntas, nessa ordem.');

  final String label;
  final String description;
  const MatchMode(this.label, this.description);
}

/// Letters/digits in any script — the "inside a word" characters for the
/// word-start boundary below.
const _wordChar = r'[\p{L}\p{N}]';

/// A compiled verse-text search, matched against text already passed
/// through [normalizeForSearch] (lowercase, no accents).
///
/// Words match at the *start* of a word ("tema" finds "temas"), and short
/// ones only as a whole word — plain substring search made short words
/// noisy ("fé" matched "fez", "café"). Text in double quotes is always an exact
/// phrase, in any [MatchMode]; punctuation between its words is tolerated
/// ("não temas" matches "Não, temas").
class VerseQuery {
  final List<RegExp> _terms;
  final List<RegExp> _excluded;
  final bool _requireAll;

  VerseQuery._(this._terms, this._excluded, this._requireAll);

  /// Null when there's nothing searchable — empty, or only 1-letter words,
  /// which would match most of the Bible and aren't a meaningful search.
  static VerseQuery? build(String text, {MatchMode mode = MatchMode.allWords, String excluded = ''}) {
    final terms = <RegExp>[];
    var meaningful = false;
    void addPhrase(List<String> words) {
      if (words.isEmpty) return;
      terms.add(words.length == 1 ? _wordPattern(words.single) : _phrasePattern(words));
      meaningful = meaningful || words.length > 1 || words.single.length >= 2;
    }

    if (mode == MatchMode.exactPhrase) {
      addPhrase(_words(text.replaceAll('"', ' ')));
    } else {
      for (final match in RegExp(r'"([^"]*)"|(\S+)').allMatches(text)) {
        final phrase = match.group(1);
        if (phrase != null) {
          addPhrase(_words(phrase));
        } else {
          for (final word in _words(match.group(2)!)) {
            addPhrase([word]);
          }
        }
      }
    }
    if (!meaningful) return null;

    final excludedTerms = _words(excluded).map(_wordPattern).toList();
    return VerseQuery._(terms, excludedTerms, mode != MatchMode.anyWord);
  }

  /// Normalized words of [text], punctuation stripped.
  static List<String> _words(String text) => normalizeForSearch(text)
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Words shorter than this only match as a whole word: as a prefix, "fé"
  /// would match "fez"/"feito" and "eu" would match "eunuco". Longer ones
  /// match as a prefix so plurals/conjugations come along ("tema" → "temas").
  static const _minPrefixLength = 4;

  static RegExp _wordPattern(String word) => RegExp(
        word.length < _minPrefixLength
            ? '(?<!$_wordChar)${RegExp.escape(word)}(?!$_wordChar)'
            : '(?<!$_wordChar)${RegExp.escape(word)}$_wordChar*',
        unicode: true,
      );

  static RegExp _phrasePattern(List<String> words) => RegExp(
        '(?<!$_wordChar)${words.map(RegExp.escape).join('[^\\p{L}\\p{N}]+')}(?!$_wordChar)',
        unicode: true,
      );

  bool matches(String normalizedText) {
    if (_excluded.any((e) => e.hasMatch(normalizedText))) return false;
    return _requireAll
        ? _terms.every((t) => t.hasMatch(normalizedText))
        : _terms.any((t) => t.hasMatch(normalizedText));
  }

  /// Sorted, non-overlapping (start, end) ranges of the matched words, for
  /// bolding them in the result list. [normalizeForSearch] maps each
  /// character to exactly one character, so these offsets are valid on the
  /// original (accented) verse text too.
  List<(int, int)> highlightRanges(String normalizedText) => _mergeRanges([
        for (final term in _terms)
          for (final m in term.allMatches(normalizedText)) (m.start, m.end),
      ]);
}

List<(int, int)> _mergeRanges(List<(int, int)> ranges) {
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// How an extra condition joins everything before it.
enum LogicOp {
  and('E'),
  or('OU');

  final String label;
  const LogicOp(this.label);
}

/// One extra condition from the filters sheet: [op] + its own words (all
/// words required; quotes make a phrase, same as the main box).
class SearchCondition {
  final LogicOp op;
  final String text;

  const SearchCondition({required this.op, required this.text});
}

/// The full search: the main box plus any extra E/OU conditions, folded
/// left to right with no precedence ("a OU b E c" = "(a OU b) E c") — the
/// same rule the old multi-box search used, and the only one that reads
/// naturally top to bottom in the sheet. Excluded words apply to the whole
/// result, whichever condition matched.
class CompiledSearch {
  final List<(LogicOp, VerseQuery)> _parts;
  final VerseQuery? _excluded;

  CompiledSearch._(this._parts, this._excluded);

  /// Null when neither the main box nor any condition has something
  /// searchable. Empty/meaningless conditions are skipped; if the main box is
  /// empty, the first usable condition starts the chain (its op ignored).
  static CompiledSearch? build(
    String text, {
    MatchMode mode = MatchMode.allWords,
    String excluded = '',
    List<SearchCondition> conditions = const [],
  }) {
    final parts = <(LogicOp, VerseQuery)>[];
    final main = VerseQuery.build(text, mode: mode);
    if (main != null) parts.add((LogicOp.and, main));
    for (final c in conditions) {
      final q = VerseQuery.build(c.text);
      if (q != null) parts.add((c.op, q));
    }
    if (parts.isEmpty) return null;
    return CompiledSearch._(parts, VerseQuery.build(excluded, mode: MatchMode.anyWord));
  }

  bool matches(String normalizedText) {
    if (_excluded?.matches(normalizedText) ?? false) return false;
    var result = _parts.first.$2.matches(normalizedText);
    for (final (op, query) in _parts.skip(1)) {
      // Short-circuit: skip the regex work when it can't change the result.
      if (op == LogicOp.and && !result) continue;
      if (op == LogicOp.or && result) continue;
      result = query.matches(normalizedText);
    }
    return result;
  }

  List<(int, int)> highlightRanges(String normalizedText) => _mergeRanges([
        for (final (_, query) in _parts) ...query.highlightRanges(normalizedText),
      ]);
}
