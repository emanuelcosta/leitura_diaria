import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/favorite_verse.dart';

class FavoriteVerseRepository {
  Future<List<FavoriteVerse>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('favorite_verses', orderBy: 'created_at DESC');
    return rows.map(FavoriteVerse.fromMap).toList();
  }

  Future<void> add(String bookId, int chapterNumber, int verseNumber) async {
    final db = await AppDatabase.instance.database;
    final favorite = FavoriteVerse(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      createdAt: DateTime.now(),
    );
    await db.insert(
      'favorite_verses',
      favorite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'favorite_verses',
      where: 'id = ?',
      whereArgs: ['$bookId-$chapterNumber-$verseNumber'],
    );
  }

  /// Overwrites local favorites with the given set (used after a remote
  /// pull), so devices converge instead of just accumulating unions forever.
  Future<void> replaceAll(List<FavoriteVerse> favorites) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('favorite_verses');
      final batch = txn.batch();
      for (final favorite in favorites) {
        batch.insert('favorite_verses', favorite.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
