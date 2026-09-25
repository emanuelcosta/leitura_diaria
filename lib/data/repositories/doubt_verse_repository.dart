import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/doubt_verse.dart';

class DoubtVerseRepository {
  Future<List<DoubtVerse>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('doubt_verses', orderBy: 'created_at DESC');
    return rows.map(DoubtVerse.fromMap).toList();
  }

  Future<void> add(String bookId, int chapterNumber, int verseNumber, {String? note}) async {
    final db = await AppDatabase.instance.database;
    final doubt = DoubtVerse(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      note: note,
      createdAt: DateTime.now(),
    );
    await db.insert('doubt_verses', doubt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Updates just the note on an already-marked doubt, keeping its original
  /// createdAt (unlike [add], which would reset it) and stamping [updatedAt]
  /// so this edit wins over older copies on other devices.
  Future<void> setNote(String bookId, int chapterNumber, int verseNumber, String? note, DateTime updatedAt) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'doubt_verses',
      {'note': note, 'updated_at': updatedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: ['$bookId-$chapterNumber-$verseNumber'],
    );
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final db = await AppDatabase.instance.database;
    await db.delete('doubt_verses', where: 'id = ?', whereArgs: ['$bookId-$chapterNumber-$verseNumber']);
  }

  Future<void> replaceAll(List<DoubtVerse> doubts) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('doubt_verses');
      final batch = txn.batch();
      for (final doubt in doubts) {
        batch.insert('doubt_verses', doubt.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
