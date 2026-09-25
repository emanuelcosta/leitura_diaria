import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/data/database/app_database.dart';
import 'package:leitura_diaria/data/models/favorite_color.dart';
import 'package:leitura_diaria/data/repositories/favorite_verse_repository.dart';

void main() {
  late Database db;
  final repo = FavoriteVerseRepository();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async => db.close());

  test('setColor creates a marker with that color', () async {
    await repo.setColor('genesis', 1, 1, FavoriteColor.green);
    final all = await repo.getAll();
    expect(all.single.color, FavoriteColor.green);
  });

  test('recoloring keeps createdAt and moves updatedAt forward', () async {
    final first = await repo.setColor('genesis', 1, 1, FavoriteColor.amber);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await repo.setColor('genesis', 1, 1, FavoriteColor.pink);

    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.color, FavoriteColor.pink);
    expect(second.createdAt, first.createdAt);
    expect(second.updatedAt.isAfter(first.updatedAt), isTrue);
  });

  test('each verse keeps its own color', () async {
    await repo.setColor('genesis', 1, 1, FavoriteColor.amber);
    await repo.setColor('genesis', 1, 2, FavoriteColor.teal);
    final byVerse = {for (final f in await repo.getAll()) f.verseNumber: f.color};
    expect(byVerse, {1: FavoriteColor.amber, 2: FavoriteColor.teal});
  });

  test('v5 → v6 upgrade: existing favorites become amber with updated_at = created_at', () async {
    // A pre-v6 favorites table (no color/updated_at) with one row, in its own
    // in-memory DB (singleInstance: false — otherwise it's setUp's DB).
    final old = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await old.execute('''
      CREATE TABLE favorite_verses (
        id TEXT PRIMARY KEY, book_id TEXT NOT NULL, chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL, created_at TEXT NOT NULL
      )
    ''');
    await old.insert('favorite_verses', {
      'id': 'genesis-1-1',
      'book_id': 'genesis',
      'chapter_number': 1,
      'verse_number': 1,
      'created_at': '2026-01-01T10:00:00.000',
    });
    await AppDatabase.addFavoriteColor(old); // the real v6 upgrade step

    final row = (await old.query('favorite_verses')).single;
    expect(row['color'], 'amber');
    expect(row['updated_at'], '2026-01-01T10:00:00.000');
    await old.close();
  });
}
