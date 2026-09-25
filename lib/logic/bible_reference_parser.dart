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

/// Case/accent-insensitive lookup by abbreviation only — `@` references in
/// notes are written with siglas. (The Buscar tab also accepts full names:
/// see parseSearchReference.)
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
/// ("1Pedro", "i pedro") — both are valid (used by the "@" book mention
/// field in notes). Matching is
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

/// Book part (letters/spaces, optional leading digit — "1 pedro", "I Pedro",
/// "joão") then chapter and optional verse, matching the whole input.
final _flexibleReferencePattern =
    RegExp(r'^(\d?\s*[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ\s]*?)\s*(\d+)(?:[.:\s]+(\d+))?$');

/// Resolves what a person types for a book in a search box: the sigla
/// ("Jo", "1Pe"), the full name with digit or roman numeral, spaced or not
/// ("1 pedro", "i pedro", "1pedro"), or an unambiguous start of the name
/// ("gen", "apoc"). Spaces and accents are ignored throughout.
Book? _resolveBookLoosely(String typed, List<Book> books) {
  final key = normalizeForSearch(typed).replaceAll(RegExp(r'\s+'), '');
  if (key.isEmpty) return null;
  String squash(String s) => s.replaceAll(' ', '');

  for (final book in books) {
    if (normalizeForSearch(book.abbreviation) == key) return book;
  }
  for (final book in books) {
    if (_nameSearchVariants(normalizeForSearch(book.name)).any((v) => squash(v) == key)) return book;
  }
  // Prefix only when it's long enough to mean something and points at a
  // single book ("jo" is already the sigla for João; "jos" could only be
  // Josué).
  if (key.length < 3) return null;
  final prefixMatches = books
      .where((b) => _nameSearchVariants(normalizeForSearch(b.name)).any((v) => squash(v).startsWith(key)))
      .toList();
  return prefixMatches.length == 1 ? prefixMatches.single : null;
}

/// The Buscar tab's reference detection: the *whole* input must be a
/// reference, with the book as a sigla ("1Pe 5 15") or a full/partial name
/// ("joão 3 16", "1 pedro 5:15", "salmos 23", "gen 1") — what most people
/// type. Null when the input isn't entirely a reference, so the caller
/// falls back to a text search.
BibleReference? parseSearchReference(String query, List<Book> books) {
  final trimmed = query.trim();
  final match = _flexibleReferencePattern.firstMatch(trimmed);
  if (match == null) return null;
  final book = _resolveBookLoosely(match.group(1)!, books);
  final chapter = int.parse(match.group(2)!);
  if (book == null || chapter < 1 || chapter > book.chapterCount) return null;
  final verseText = match.group(3);
  final verse = verseText != null ? int.parse(verseText) : null;
  if (verse != null && verse < 1) return null;
  return BibleReference(
    matchedText: trimmed,
    start: 0,
    end: trimmed.length,
    book: book,
    chapterNumber: chapter,
    verseNumber: verse,
  );
}
