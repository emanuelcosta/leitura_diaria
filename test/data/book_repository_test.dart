import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/data/database/app_database.dart';
import 'package:leitura_diaria/data/repositories/book_repository.dart';

void main() {
  late Database db;
  final bookRepo = BookRepository();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await AppDatabase.instance.close();
  });

  test('hasBooks is false on a fresh schema (seed never ran for this DB)', () async {
    expect(await bookRepo.hasBooks(), isFalse);
  });

  test('hasBooks is true once any book exists', () async {
    await db.insert('books', {
      'id': 'genesis',
      'name': 'Gênesis',
      'testament': 'AT',
      'track': 2,
      'book_order': 1,
      'chapter_count': 50,
    });
    expect(await bookRepo.hasBooks(), isTrue);
  });
}
