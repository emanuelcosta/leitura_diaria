import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/verse_note.dart';

class VerseNoteRepository {
  Future<List<VerseNote>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('verse_notes', orderBy: 'updated_at DESC');
    return rows.map(VerseNote.fromMap).toList();
  }

  /// Empty/whitespace-only text deletes the note instead of storing a blank
  /// row, mirroring ChapterRepository.setNote's null-clears convention.
  Future<void> set(String bookId, int chapterNumber, int verseNumber, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await remove(bookId, chapterNumber, verseNumber);
      return;
    }
    final db = await AppDatabase.instance.database;
    final note = VerseNote(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      note: trimmed,
      updatedAt: DateTime.now(),
    );
    await db.insert('verse_notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final db = await AppDatabase.instance.database;
    await db.delete('verse_notes', where: 'id = ?', whereArgs: ['$bookId-$chapterNumber-$verseNumber']);
  }

  Future<void> replaceAll(List<VerseNote> notes) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('verse_notes');
      final batch = txn.batch();
      for (final note in notes) {
        batch.insert('verse_notes', note.toMap());
      }
      await batch.commit(noResult: true);
    });
  }
}
