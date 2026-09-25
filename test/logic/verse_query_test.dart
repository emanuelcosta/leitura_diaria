import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/logic/text_normalize.dart';
import 'package:leitura_diaria/logic/verse_query.dart';

bool _matches(VerseQuery q, String text) => q.matches(normalizeForSearch(text));

void main() {
  const verse = 'Não temas, porque eu sou contigo; não te assombres, porque eu sou teu Deus.';

  test('empty or 1-letter-only query -> null (not a meaningful search)', () {
    expect(VerseQuery.build(''), isNull);
    expect(VerseQuery.build('   '), isNull);
    expect(VerseQuery.build('e a o'), isNull);
  });

  test('all words: every word must appear, any order, accent-insensitive', () {
    final q = VerseQuery.build('deus nao')!;
    expect(_matches(q, verse), isTrue);
    expect(_matches(q, 'Deus é amor'), isFalse);
  });

  test('short words (< 4 letters) only match as a whole word', () {
    final q = VerseQuery.build('fé')!;
    expect(_matches(q, 'pela fé'), isTrue);
    expect(_matches(q, 'Deus fez os céus'), isFalse);
    expect(_matches(q, 'o café'), isFalse);
  });

  test('longer words match at the start of a word, not inside one', () {
    expect(_matches(VerseQuery.build('tema')!, verse), isTrue); // "temas"
    expect(_matches(VerseQuery.build('emas')!, verse), isFalse);
  });

  test('any word: at least one must appear', () {
    final q = VerseQuery.build('medo temas', mode: MatchMode.anyWord)!;
    expect(_matches(q, verse), isTrue);
    expect(_matches(q, 'não tenhais medo'), isTrue);
    expect(_matches(q, 'Deus é amor'), isFalse);
  });

  test('exact phrase: words together and in order, punctuation tolerated', () {
    final q = VerseQuery.build('não temas', mode: MatchMode.exactPhrase)!;
    expect(_matches(q, verse), isTrue);
    expect(_matches(q, 'Não, temas'), isTrue);
    expect(_matches(q, 'temas não'), isFalse);
    expect(_matches(q, 'não temasse'), isFalse);
  });

  test('quotes make a phrase inside all-words mode', () {
    final q = VerseQuery.build('"sou contigo" deus')!;
    expect(_matches(q, verse), isTrue);
    expect(_matches(q, 'contigo sou, diz Deus'), isFalse);
  });

  test('excluded words drop the verse', () {
    final q = VerseQuery.build('temas', excluded: 'assombres')!;
    expect(_matches(q, verse), isFalse);
    expect(_matches(q, 'Não temas'), isTrue);
  });

  test('highlight ranges cover whole matched words and map onto accented text', () {
    const text = 'Não temas, porque eu sou contigo';
    final q = VerseQuery.build('nao tema')!;
    final ranges = q.highlightRanges(normalizeForSearch(text));
    expect(ranges.map((r) => text.substring(r.$1, r.$2)).toList(), ['Não', 'temas']);
  });

  group('CompiledSearch (main box + E/OU conditions)', () {
    bool m(CompiledSearch s, String text) => s.matches(normalizeForSearch(text));

    test('OU: either condition is enough', () {
      final s = CompiledSearch.build('"não temas"', conditions: const [
        SearchCondition(op: LogicOp.or, text: '"não tenhais medo"'),
      ])!;
      expect(m(s, 'Não temas, pequeno rebanho'), isTrue);
      expect(m(s, 'Não tenhais medo'), isTrue);
      expect(m(s, 'Deus é amor'), isFalse);
    });

    test('E: both conditions required', () {
      final s = CompiledSearch.build('amor', conditions: const [
        SearchCondition(op: LogicOp.and, text: 'próximo'),
      ])!;
      expect(m(s, 'Amarás o teu próximo com amor'), isTrue);
      expect(m(s, 'Deus é amor'), isFalse);
    });

    test('folds left to right: a OU b E c = (a OU b) E c', () {
      final s = CompiledSearch.build('luz', conditions: const [
        SearchCondition(op: LogicOp.or, text: 'trevas'),
        SearchCondition(op: LogicOp.and, text: 'mundo'),
      ])!;
      expect(m(s, 'Eu sou a luz do mundo'), isTrue);
      expect(m(s, 'as trevas do mundo'), isTrue);
      expect(m(s, 'a luz resplandece'), isFalse);
    });

    test('empty main box: first usable condition starts the chain', () {
      final s = CompiledSearch.build('', conditions: const [
        SearchCondition(op: LogicOp.and, text: 'x'), // too short, skipped
        SearchCondition(op: LogicOp.and, text: 'graça'),
      ])!;
      expect(m(s, 'pela graça sois salvos'), isTrue);
      expect(CompiledSearch.build('', conditions: const [SearchCondition(op: LogicOp.or, text: '')]), isNull);
    });

    test('excluded words apply to every branch', () {
      final s = CompiledSearch.build('luz', excluded: 'trevas', conditions: const [
        SearchCondition(op: LogicOp.or, text: 'noite'),
      ])!;
      expect(m(s, 'a noite e as trevas'), isFalse);
      expect(m(s, 'a noite passou'), isTrue);
    });

    test('highlights words from every condition', () {
      const text = 'Eu sou a luz do mundo';
      final s = CompiledSearch.build('luz', conditions: const [
        SearchCondition(op: LogicOp.and, text: 'mundo'),
      ])!;
      final ranges = s.highlightRanges(normalizeForSearch(text));
      expect(ranges.map((r) => text.substring(r.$1, r.$2)).toList(), ['luz', 'mundo']);
    });
  });

  test('overlapping highlight ranges are merged', () {
    const text = 'não temas';
    final q = VerseQuery.build('"não temas" temas')!;
    expect(q.highlightRanges(normalizeForSearch(text)), [(0, 9)]);
  });
}
