import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/data/database/app_database.dart';
import 'package:leitura_diaria/data/repositories/book_repository.dart';
import 'package:leitura_diaria/data/repositories/chapter_repository.dart';

void main() {
  late Database db;
  final chapterRepo = ChapterRepository();
  final bookRepo = BookRepository();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    await db.insert('books', {
      'id': 'genesis',
      'name': 'Gênesis',
      'testament': 'AT',
      'track': 2,
      'book_order': 1,
      'chapter_count': 3,
    });
    await db.insert('books', {
      'id': 'salmos',
      'name': 'Salmos',
      'testament': 'AT',
      'track': 3,
      'book_order': 19,
      'chapter_count': 2,
    });
    for (var n = 1; n <= 3; n++) {
      await db.insert('chapters', {
        'id': 'genesis-$n',
        'book_id': 'genesis',
        'chapter_number': n,
        'plan_day': n,
        'is_read': 0,
      });
    }
    for (var n = 1; n <= 2; n++) {
      await db.insert('chapters', {
        'id': 'salmos-$n',
        'book_id': 'salmos',
        'chapter_number': n,
        'plan_day': n,
        'is_read': 0,
      });
    }
    AppDatabase.instance.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('setRead marks a chapter read with timestamp and optional note', () async {
    await chapterRepo.setRead('genesis-1', isRead: true, note: 'Criação do mundo');
    final view = await chapterRepo.getChapter('genesis-1');
    expect(view!.chapter.isRead, true);
    expect(view.chapter.readAt, isNotNull);
    expect(view.chapter.note, 'Criação do mundo');
  });

  test('unmarking a chapter clears read_at and note', () async {
    await chapterRepo.setRead('genesis-1', isRead: true, note: 'algo');
    await chapterRepo.setRead('genesis-1', isRead: false);
    final view = await chapterRepo.getChapter('genesis-1');
    expect(view!.chapter.isRead, false);
    expect(view.chapter.readAt, isNull);
    expect(view.chapter.note, isNull);
  });

  test('getOverallProgress counts read vs total across all books', () async {
    await chapterRepo.setRead('genesis-1', isRead: true);
    await chapterRepo.setRead('genesis-2', isRead: true);
    final progress = await chapterRepo.getOverallProgress();
    expect(progress.totalCount, 5);
    expect(progress.readCount, 2);
  });

  test('getProgressByBook groups read counts per book', () async {
    await chapterRepo.setRead('genesis-1', isRead: true);
    await chapterRepo.setRead('salmos-1', isRead: true);
    await chapterRepo.setRead('salmos-2', isRead: true);
    final byBook = await bookRepo.getProgressByBook();
    final genesis = byBook.firstWhere((b) => b.book.id == 'genesis');
    final salmos = byBook.firstWhere((b) => b.book.id == 'salmos');
    expect(genesis.readCount, 1);
    expect(salmos.readCount, 2);
  });

  test('getAllDistinctReadDates returns one entry per calendar day', () async {
    await chapterRepo.setRead('genesis-1', isRead: true);
    await chapterRepo.setRead('genesis-2', isRead: true);
    final dates = await chapterRepo.getAllDistinctReadDates();
    expect(dates.length, 1); // both marked "now" -> same day
  });

  test('getReadChapterRefs returns book order + chapter of read chapters only', () async {
    await chapterRepo.setRead('genesis-2', isRead: true);
    await chapterRepo.setRead('salmos-1', isRead: true);
    final refs = await chapterRepo.getReadChapterRefs();
    expect(refs.toSet(), {
      (bookOrder: 1, chapterNumber: 2),
      (bookOrder: 19, chapterNumber: 1),
    });
  });

  test('resetAllProgress clears state without deleting rows', () async {
    await chapterRepo.setRead('genesis-1', isRead: true, note: 'nota');
    await chapterRepo.resetAllProgress();
    final progress = await chapterRepo.getOverallProgress();
    expect(progress.totalCount, 5);
    expect(progress.readCount, 0);
    final view = await chapterRepo.getChapter('genesis-1');
    expect(view!.chapter.note, isNull);
  });
}
