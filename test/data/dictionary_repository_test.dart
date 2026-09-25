import 'package:flutter_test/flutter_test.dart';

import 'package:leitura_diaria/data/repositories/dictionary_repository.dart';

void main() {
  // Uses the real bundled assets (easton_smith.json + terms_pt.json).
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = DictionaryRepository();

  test('every entry has a Portuguese term', () async {
    final all = await repo.search('a');
    expect(all, isNotEmpty);
    expect(all.where((e) => e.termPt == null), isEmpty);
  });

  test('Portuguese query finds the entry, accent-insensitive', () async {
    final results = await repo.search('arao');
    expect(results.first.term, 'Aaron');
    expect(results.first.displayTerm, 'Arão');
  });

  test('English query still works', () async {
    final results = await repo.search('covenant');
    expect(results.map((e) => e.term), contains('Covenant'));
  });

  test('prefix matches come before substring matches', () async {
    final results = await repo.search('alianca');
    expect(results.first.displayTerm.toLowerCase(), startsWith('alian'));
  });

  test('empty query returns nothing', () async {
    expect(await repo.search('  '), isEmpty);
  });
}
