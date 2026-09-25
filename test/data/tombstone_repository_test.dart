import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/data/database/app_database.dart';
import 'package:leitura_diaria/data/repositories/tombstone_repository.dart';

void main() {
  late Database db;
  final repo = TombstoneRepository();
  final jan = DateTime(2026, 1, 1, 10);
  final feb = DateTime(2026, 2, 1, 10);

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

  test('record/getAll per kind, kinds kept apart', () async {
    await repo.record(SyncKind.doubt, 'genesis-1-1', jan);
    await repo.record(SyncKind.favorite, 'genesis-1-1', feb);
    expect(await repo.getAll(SyncKind.doubt), {'genesis-1-1': jan});
    expect(await repo.getAll(SyncKind.favorite), {'genesis-1-1': feb});
    expect(await repo.getAll(SyncKind.verseNote), isEmpty);
  });

  test('recording again overwrites the time', () async {
    await repo.record(SyncKind.doubt, 'genesis-1-1', jan);
    await repo.record(SyncKind.doubt, 'genesis-1-1', feb);
    expect(await repo.getAll(SyncKind.doubt), {'genesis-1-1': feb});
  });

  test('clear removes one item (re-marked)', () async {
    await repo.record(SyncKind.doubt, 'genesis-1-1', jan);
    await repo.record(SyncKind.doubt, 'genesis-1-2', jan);
    await repo.clear(SyncKind.doubt, 'genesis-1-1');
    expect((await repo.getAll(SyncKind.doubt)).keys, ['genesis-1-2']);
  });

  test('v9: doubt_verses gets updated_at, backfilled from created_at', () async {
    final old = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await old.execute('''
      CREATE TABLE doubt_verses (
        id TEXT PRIMARY KEY, book_id TEXT NOT NULL, chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL, note TEXT, created_at TEXT NOT NULL
      )
    ''');
    await old.insert('doubt_verses', {
      'id': 'genesis-1-1',
      'book_id': 'genesis',
      'chapter_number': 1,
      'verse_number': 1,
      'created_at': '2026-01-01T10:00:00.000',
    });
    await AppDatabase.addDoubtUpdatedAt(old);
    expect((await old.query('doubt_verses')).single['updated_at'], '2026-01-01T10:00:00.000');
    await old.close();
  });

  test('replaceAll swaps only that kind', () async {
    await repo.record(SyncKind.doubt, 'genesis-1-1', jan);
    await repo.record(SyncKind.favorite, 'genesis-2-1', jan);
    await repo.replaceAll(SyncKind.doubt, {'exodo-3-14': feb});
    expect(await repo.getAll(SyncKind.doubt), {'exodo-3-14': feb});
    expect(await repo.getAll(SyncKind.favorite), {'genesis-2-1': jan});
  });
}
