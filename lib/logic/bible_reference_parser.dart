import '../data/models/book.dart';
import 'text_normalize.dart';

/// A Bible reference resolved to a real book/chapter/verse, e.g. "1Pe 5.15"
/// -> 1 Pedro 5:15. [verseNumber] is null for a chapter-only reference like
/// "Sl 23".
class BibleReference {
  final String matchedText;
  final int start;
  final int end;
  final Book book;
  final int chapterNumber;
  final int? verseNumber;

  const BibleReference({
    required this.matchedText,
    required this.start,
    required this.end,
    required this.book,
    required this.chapterNumber,
    this.verseNumber,
  });
}

/// Sigla: an optional leading digit (1/2/3 João, etc.) then 1-3 letters
/// (accented, e.g. "Êx"). Chapter/verse separator accepts ".", ":", or just
/// whitespace — a plain space is what lets "1Pe 5 15" work without ever
/// leaving the default mobile keyboard layout (":" and sometimes "." need a
/// switch to the symbols page, which is exactly the friction this avoids).
const _siglaPattern = r'\d?[A-Za-zÀ-ÖØ-öø-ÿ]+';
const _chapterVersePattern = r'(\d+)(?:[.:\s]+(\d+))?';

/// `@Sigla cap.vers` anywhere inside free text (notes) — see
/// findBibleReferences.
final _embeddedReferencePattern = RegExp('@($_siglaPattern)\\s*$_chapterVersePattern');

/// `Sigla cap.vers` matching the *whole* trimmed input, no "@" — see
/// parseDirectReference (the Livros tab's quick-jump search).
final _directReferencePattern = RegExp('^($_siglaPattern)\\s*$_chapterVersePattern\$');

/// Case/accent-insensitive lookup by abbreviation only (not full book name —
/// a direct search query like "1Pe" is terse by design; full names are
/// already covered by the Livros tab's plain name filter).
Book? _resolveBookBySigla(String sigla, List<Book> books) {
  final normalized = normalizeForSearch(sigla);
  for (final book in books) {
    if (normalizeForSearch(book.abbreviation) == normalized) return book;
  }
  return null;
}

BibleReference? _toReference(RegExpMatch match, List<Book> books) {
  final book = _resolveBookBySigla(match.group(1)!, books);
  final chapter = int.parse(match.group(2)!);
  if (book == null || chapter < 1 || chapter > book.chapterCount) return null;
  final verseText = match.group(3);
  return BibleReference(
    matchedText: match.group(0)!,
    start: match.start,
    end: match.end,
    book: book,
    chapterNumber: chapter,
    verseNumber: verseText != null ? int.parse(verseText) : null,
  );
}

/// Pure text scan — no Flutter/DB — [books] is passed in by the caller
/// (already has it via ReadingPlanProvider.meta.books) rather than fetched
/// here, keeping this a pure function per lib/logic/ convention. A match
/// whose sigla doesn't resolve to a known book, or whose chapter is out of
/// range for that book, is silently skipped (treated as plain text).
List<BibleReference> findBibleReferences(String text, List<Book> books) {
  final results = <BibleReference>[];
  for (final match in _embeddedReferencePattern.allMatches(text)) {
    final ref = _toReference(match, books);
    if (ref != null) results.add(ref);
  }
  return results;
}

/// For a search box where the *entire* query is meant to be a reference,
/// e.g. typing "1Pe 5:15" or "1Pe 5.15" (no "@") to jump straight there —
/// returns null for anything that isn't exactly `Sigla capítulo[.:versículo]`
/// end to end, so a plain book-name search still falls through to the
/// normal filter instead of being swallowed here.
BibleReference? parseDirectReference(String query, List<Book> books) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  final match = _directReferencePattern.firstMatch(trimmed);
  if (match == null) return null;
  return _toReference(match, books);
}

/// A reference still being typed, e.g. "1P" or "1Pedro" — an optional
/// leading digit then letters only, no chapter number yet. Drives
/// autocomplete: once a space + digit shows up the user has moved on to the
/// chapter, so this stops matching and any suggestion list should close.
final _partialSiglaPattern = RegExp(r'^\d?[A-Za-zÀ-ÖØ-öø-ÿ]+$');

bool looksLikePartialSigla(String text) => _partialSiglaPattern.hasMatch(text.trim());

/// Bible book names spell ordinal prefixes as Roman numerals ("I Pedro",
/// "II Samuel"), but the abbreviation next to them uses the digit ("1Pe",
/// "2Sm") — people typing a reference from memory use whichever, so this
/// yields both a spaced and unspaced digit-prefixed variant of a normalized
/// name alongside the name itself, for suggestion matching to check against.
const _romanToDigit = {'iii': '3', 'ii': '2', 'i': '1'};

Iterable<String> _nameSearchVariants(String normalizedName) sync* {
  yield normalizedName;
  for (final entry in _romanToDigit.entries) {
    if (normalizedName.startsWith('${entry.key} ')) {
      final rest = normalizedName.substring(entry.key.length + 1);
      yield '${entry.value} $rest';
      yield '${entry.value}$rest';
      break;
    }
  }
}

/// Book suggestions for autocomplete while [partial] is being typed as
/// either an abbreviation ("1Pe") or the start of the book's full name
/// ("1Pedro", "i pedro") — both are valid, matching how books are already
/// searched elsewhere (Livros tab name/abbreviation filter). Matching is
/// case/accent-insensitive via normalizeForSearch, same as the rest of the
/// app. Abbreviation-prefix matches rank first since that's the terser,
/// more likely intent when typing a reference.
List<Book> suggestBooksForPartialSigla(String partial, List<Book> books, {int limit = 5}) {
  final normalized = normalizeForSearch(partial);
  if (normalized.isEmpty) return const [];
  final byAbbreviation = <Book>[];
  final byName = <Book>[];
  for (final book in books) {
    if (normalizeForSearch(book.abbreviation).startsWith(normalized)) {
      byAbbreviation.add(book);
    } else if (_nameSearchVariants(normalizeForSearch(book.name)).any((v) => v.startsWith(normalized))) {
      byName.add(book);
    }
  }
  return [...byAbbreviation, ...byName].take(limit).toList();
}
