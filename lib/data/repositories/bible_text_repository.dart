import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../logic/text_normalize.dart';
import '../models/book.dart';
import '../models/verse_search_result.dart';

enum BibleTranslation {
  acf('ACF', 'Almeida Corrigida Fiel'),
  arc('ARC', 'Almeida Revista e Corrigida');

  final String abbreviation;
  final String label;
  const BibleTranslation(this.abbreviation, this.label);
}

/// Serves verse text for a chapter from the bundled `assets/bible/*.json`
/// files (see assets/bible/ATTRIBUTION.md). Each file is a JSON array of 66
/// books in canonical order — the same order as `Book.order` in
/// assets/reading_plan.json — so a verse is looked up by array index, no id
/// matching needed. Parsed once per translation and cached in memory: at
/// ~4MB/translation, re-parsing per chapter would be wasteful.
class BibleTextRepository {
  static final Map<BibleTranslation, List<dynamic>> _cache = {};

  Future<List<dynamic>> _books(BibleTranslation translation) async {
    final cached = _cache[translation];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/bible/${translation.name}.json');
    final books = jsonDecode(raw) as List<dynamic>;
    _cache[translation] = books;
    return books;
  }

  /// Verse texts for a chapter, 1-indexed (`verses[0]` is verse 1).
  /// [bookOrder] is the book's canonical 1-66 position (`Book.order`), which
  /// is also this JSON's array index (offset by one) — no id lookup needed.
  Future<List<String>> getChapterVerses({
    required BibleTranslation translation,
    required int bookOrder,
    required int chapterNumber,
  }) async {
    final books = await _books(translation);
    final chapters = (books[bookOrder - 1] as Map<String, dynamic>)['chapters'] as List<dynamic>;
    return (chapters[chapterNumber - 1] as List<dynamic>).cast<String>();
  }

  /// Full-text search across every verse of [candidateBooks] (already
  /// filtered by testament/category by the caller). [matches] receives each
  /// verse's normalized text (see normalizeForSearch) and decides whether it
  /// counts as a hit — the word/AND-OR condition logic lives in the caller
  /// (see VerseSearchPanel), this just does the scan.
  Future<List<VerseSearchResult>> search({
    required BibleTranslation translation,
    required List<Book> candidateBooks,
    required bool Function(String normalizedVerseText) matches,
  }) async {
    final allBooks = await _books(translation);
    final results = <VerseSearchResult>[];
    for (final book in candidateBooks) {
      final chapters = (allBooks[book.order - 1] as Map<String, dynamic>)['chapters'] as List<dynamic>;
      for (var c = 0; c < chapters.length; c++) {
        final verses = (chapters[c] as List<dynamic>).cast<String>();
        for (var v = 0; v < verses.length; v++) {
          final normalized = normalizeForSearch(verses[v]);
          if (matches(normalized)) {
            results.add(VerseSearchResult(
              bookId: book.id,
              bookName: book.name,
              bookOrder: book.order,
              chapterNumber: c + 1,
              verseNumber: v + 1,
              text: verses[v],
            ));
          }
        }
      }
    }
    return results;
  }
}
