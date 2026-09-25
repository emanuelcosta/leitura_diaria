import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/data/models/book.dart';
import 'package:leitura_diaria/logic/bible_reference_parser.dart';

void main() {
  const books = [
    Book(id: 'genesis', name: 'Gênesis', testament: Testament.at, track: 2, order: 1, chapterCount: 50),
    Book(id: 'exodo', name: 'Êxodo', testament: Testament.at, track: 2, order: 2, chapterCount: 40),
    Book(id: 'joao', name: 'João', testament: Testament.nt, track: 1, order: 43, chapterCount: 21),
    Book(id: '1pedro', name: 'I Pedro', testament: Testament.nt, track: 1, order: 60, chapterCount: 5),
    Book(id: 'salmos', name: 'Salmos', testament: Testament.at, track: 3, order: 19, chapterCount: 150),
  ];

  test('parses a chapter.verse reference with a digit-prefixed sigla', () {
    final refs = findBibleReferences('Ver @1Pe 5.15 sobre humildade', books);
    expect(refs, hasLength(1));
    expect(refs.first.book.id, '1pedro');
    expect(refs.first.chapterNumber, 5);
    expect(refs.first.verseNumber, 15);
    expect(refs.first.matchedText, '@1Pe 5.15');
  });

  test('accepts ":" as the chapter/verse separator too', () {
    final refs = findBibleReferences('@Jo 3:16 é o mais famoso', books);
    expect(refs, hasLength(1));
    expect(refs.first.book.id, 'joao');
    expect(refs.first.verseNumber, 16);
  });

  test('chapter-only reference has a null verseNumber', () {
    final refs = findBibleReferences('Ler @Sl 23 inteiro', books);
    expect(refs, hasLength(1));
    expect(refs.first.book.id, 'salmos');
    expect(refs.first.chapterNumber, 23);
    expect(refs.first.verseNumber, isNull);
  });

  test('sigla matching ignores accents and case', () {
    // A sigla real é "Êx" (com acento) — confere que bate com variações
    // maiúsculas/minúsculas e sem acento também.
    final refs = findBibleReferences('@EX 1.1 e @êx 1.1', books);
    expect(refs, hasLength(2));
    expect(refs.every((r) => r.book.id == 'exodo'), isTrue);
  });

  test('unknown sigla is skipped, not treated as a reference', () {
    final refs = findBibleReferences('Isso não é @Xyz 1.1 uma referência', books);
    expect(refs, isEmpty);
  });

  test('chapter out of range for the book is skipped', () {
    // Salmos só tem 150 capítulos.
    final refs = findBibleReferences('@Sl 999.1', books);
    expect(refs, isEmpty);
  });

  test('finds multiple references in the same text with correct offsets', () {
    const text = 'Comparar @Gn 1.1 com @Jo 1.1 no começo.';
    final refs = findBibleReferences(text, books);
    expect(refs, hasLength(2));
    expect(text.substring(refs[0].start, refs[0].end), refs[0].matchedText);
    expect(text.substring(refs[1].start, refs[1].end), refs[1].matchedText);
    expect(refs[0].book.id, 'genesis');
    expect(refs[1].book.id, 'joao');
  });

  test('no references in plain text', () {
    expect(findBibleReferences('Só um comentário qualquer, sem nada.', books), isEmpty);
  });

  group('parseSearchReference: sigla forms and edge cases', () {
    test('parses a bare "Sigla cap.vers" query', () {
      final ref = parseSearchReference('1Pe 5.15', books);
      expect(ref, isNotNull);
      expect(ref!.book.id, '1pedro');
      expect(ref.chapterNumber, 5);
      expect(ref.verseNumber, 15);
    });

    test('accepts ":" as separator and trims surrounding whitespace', () {
      final ref = parseSearchReference('  1Pe 5:15  ', books);
      expect(ref, isNotNull);
      expect(ref!.verseNumber, 15);
    });

    test('accepts a plain space as the chapter/verse separator (no keyboard switch needed)', () {
      final ref = parseSearchReference('1Pe 5 15', books);
      expect(ref, isNotNull);
      expect(ref!.book.id, '1pedro');
      expect(ref.chapterNumber, 5);
      expect(ref.verseNumber, 15);
    });

    test('collapses extra spaces around the separator', () {
      final ref = parseSearchReference('1Pe 5   15', books);
      expect(ref, isNotNull);
      expect(ref!.verseNumber, 15);
    });

    test('chapter-only query resolves with a null verseNumber', () {
      final ref = parseSearchReference('Sl 23', books);
      expect(ref, isNotNull);
      expect(ref!.book.id, 'salmos');
      expect(ref.verseNumber, isNull);
    });

    test('a plain book-name query (not a reference) returns null, falls through to name search', () {
      expect(parseSearchReference('Gênesis', books), isNull);
      expect(parseSearchReference('', books), isNull);
    });

    test('trailing junk after the reference makes it not match (whole-string anchor)', () {
      expect(parseSearchReference('1Pe 5.15 e mais', books), isNull);
    });

    test('out-of-range chapter returns null', () {
      expect(parseSearchReference('Sl 999', books), isNull);
    });
  });

  group('suggestBooksForPartialSigla', () {
    test('matches by abbreviation prefix, case/accent-insensitive', () {
      final suggestions = suggestBooksForPartialSigla('ex', books);
      expect(suggestions, hasLength(1));
      expect(suggestions.first.id, 'exodo');
    });

    test('matches by full-name prefix typed with a digit instead of the roman numeral', () {
      final suggestions = suggestBooksForPartialSigla('1Pedro', books);
      expect(suggestions, hasLength(1));
      expect(suggestions.first.id, '1pedro');
    });

    test('matches by full-name prefix in all lowercase, no accent', () {
      // Nome real é "João" — confere que "joa" (minúsculo, sem acento) bate.
      final suggestions = suggestBooksForPartialSigla('joa', books);
      expect(suggestions, hasLength(1));
      expect(suggestions.first.id, 'joao');
    });

    test('abbreviation match ranks before a name match', () {
      // "sl" bate como abreviação de Salmos.
      final suggestions = suggestBooksForPartialSigla('sl', books);
      expect(suggestions.first.id, 'salmos');
    });

    test('empty partial yields no suggestions', () {
      expect(suggestBooksForPartialSigla('', books), isEmpty);
    });

    test('unmatched partial yields no suggestions', () {
      expect(suggestBooksForPartialSigla('xyz', books), isEmpty);
    });
  });

  group('parseSearchReference (Buscar tab: names or siglas)', () {
    test('full book name, accent-insensitive, space separators', () {
      final ref = parseSearchReference('joao 3 16', books)!;
      expect(ref.book.id, 'joao');
      expect(ref.chapterNumber, 3);
      expect(ref.verseNumber, 16);
    });

    test('sigla still works', () {
      expect(parseSearchReference('1Pe 5:7', books)!.book.id, '1pedro');
    });

    test('digit or roman numeral, spaced or not', () {
      for (final q in ['1 pedro 5 7', '1pedro 5.7', 'I Pedro 5:7', 'i pedro 5 7']) {
        expect(parseSearchReference(q, books)?.book.id, '1pedro', reason: q);
      }
    });

    test('unambiguous name prefix of 3+ letters', () {
      expect(parseSearchReference('gen 1', books)!.book.id, 'genesis');
      expect(parseSearchReference('salm 23', books)!.verseNumber, isNull);
    });

    test('plain words, missing chapter, or out-of-range chapter -> null', () {
      expect(parseSearchReference('amor de deus', books), isNull);
      expect(parseSearchReference('joao', books), isNull);
      expect(parseSearchReference('joao 99', books), isNull);
      expect(parseSearchReference('joao 3 0', books), isNull);
    });
  });
}
