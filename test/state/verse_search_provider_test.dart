import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leitura_diaria/data/models/book.dart';
import 'package:leitura_diaria/data/repositories/bible_text_repository.dart';
import 'package:leitura_diaria/logic/verse_query.dart';
import 'package:leitura_diaria/state/verse_search_provider.dart';

void main() {
  // Real bundled Bible text (assets/bible/acf.json).
  TestWidgetsFlutterBinding.ensureInitialized();

  const genesis = Book(id: 'genesis', name: 'Gênesis', testament: Testament.at, track: 2, order: 1, chapterCount: 50);
  const joao = Book(id: 'joao', name: 'João', testament: Testament.nt, track: 1, order: 43, chapterCount: 21);
  const books = [genesis, joao];

  late VerseSearchProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = VerseSearchProvider(books: books, translation: BibleTranslation.acf);
  });

  tearDown(() => provider.dispose());

  test('a reference query resolves to a reference, not a text search', () async {
    provider.setQuery('joao 3 16');
    await provider.searchNow();
    expect(provider.reference?.book.id, 'joao');
    expect(provider.reference?.verseNumber, 16);
    expect(provider.results, isNull);
  });

  test('a text query finds verses, restricted to the candidate books', () async {
    provider.setQuery('princípio');
    await provider.searchNow();
    final results = provider.results!;
    expect(results, isNotEmpty);
    expect(results.first.bookId, 'genesis'); // Gn 1:1 "No princípio criou Deus..."
    expect(results.map((r) => r.bookId).toSet(), everyElement(isIn(['genesis', 'joao'])));
  });

  test('book filter narrows results and counts as an active filter', () async {
    provider.setQuery('princípio');
    provider.setBook(joao);
    await provider.searchNow();
    expect(provider.results!.every((r) => r.bookId == 'joao'), isTrue);
    expect(provider.activeFilterCount, 1);
  });

  test('changing testament drops a book filter from the other testament', () {
    provider.setBook(genesis);
    provider.setTestament(Testament.nt);
    expect(provider.book, isNull);
    expect(provider.activeFilterCount, 1);
  });

  test('an OU condition widens the results and counts as a filter', () async {
    provider.setQuery('"no princípio era o verbo"');
    await provider.searchNow();
    final before = provider.results!.length; // João 1:1 only

    provider.addCondition();
    final id = provider.conditions.single.id;
    provider.setConditionText(id, '"no princípio criou"'); // Gênesis 1:1
    await provider.searchNow();

    expect(provider.conditions.single.op, LogicOp.or);
    expect(provider.results!.length, greaterThan(before));
    expect(provider.results!.map((r) => r.bookId).toSet(), {'genesis', 'joao'});
    expect(provider.activeFilterCount, 1);

    provider.removeCondition(id);
    expect(provider.conditions, isEmpty);
    expect(provider.activeFilterCount, 0);
  });

  test('clearFilters resets everything', () {
    provider.setMode(MatchMode.exactPhrase);
    provider.setExcluded('trevas');
    provider.setTestament(Testament.at);
    provider.clearFilters();
    expect(provider.activeFilterCount, 0);
    expect(provider.mode, MatchMode.allWords);
  });

  test('rememberQuery keeps recent searches newest-first without duplicates', () async {
    provider.setQuery('amor');
    await provider.rememberQuery();
    provider.setQuery('fé');
    await provider.rememberQuery();
    provider.setQuery('Amor');
    await provider.rememberQuery();
    expect(provider.recent, ['Amor', 'fé']);
  });
}
