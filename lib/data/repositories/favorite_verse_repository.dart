import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/favorite_color.dart';
import '../models/favorite_verse.dart';

class FavoriteVerseRepository {
  Future<List<FavoriteVerse>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('favorite_verses', orderBy: 'created_at DESC');
    return rows.map(FavoriteVerse.fromMap).toList();
  }

  /// Marks the verse with [color] — creating the favorite, or recoloring an
  /// existing one while keeping its original created_at. Returns the saved
  /// row (for the sync push).
  Future<FavoriteVerse> setColor(String bookId, int chapterNumber, int verseNumber, FavoriteColor color) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    final id = '$bookId-$chapterNumber-$verseNumber';
    final existing = await db.query('favorite_verses', where: 'id = ?', whereArgs: [id]);
    final favorite = existing.isEmpty
        ? FavoriteVerse(
            bookId: bookId,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            color: color,
            createdAt: now,
          )
        : FavoriteVerse.fromMap(existing.first).withColor(color, now);
    await db.insert('favorite_verses', favorite.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return favorite;
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
