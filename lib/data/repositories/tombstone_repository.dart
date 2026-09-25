import 'package:sqflite/sqflite.dart';

import '../../logic/sync_merge.dart';
import '../database/app_database.dart';

/// Which synced list a deletion belongs to (the `kind` column).
enum SyncKind { favorite, verseNote, doubt }

/// Local record of deletions ("tombstones") per synced list — see
/// applyDeletions for why they're needed. Written on delete, cleared when the
/// same item is created again, and replaced wholesale after a sync merge.
class TombstoneRepository {
  Future<Deletions> getAll(SyncKind kind) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sync_tombstones', where: 'kind = ?', whereArgs: [kind.name]);
    return {for (final r in rows) r['item_id'] as String: DateTime.parse(r['deleted_at'] as String)};
  }

  Future<void> record(SyncKind kind, String itemId, DateTime deletedAt) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'sync_tombstones',
      {'kind': kind.name, 'item_id': itemId, 'deleted_at': deletedAt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The item exists again (re-marked / re-written) — no longer deleted.
  Future<void> clear(SyncKind kind, String itemId) async {
    final db = await AppDatabase.instance.database;
    await db.delete('sync_tombstones', where: 'kind = ? AND item_id = ?', whereArgs: [kind.name, itemId]);
  }

  Future<void> replaceAll(SyncKind kind, Deletions deletions) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('sync_tombstones', where: 'kind = ?', whereArgs: [kind.name]);
      final batch = txn.batch();
      deletions.forEach((id, at) {
        batch.insert('sync_tombstones', {'kind': kind.name, 'item_id': id, 'deleted_at': at.toIso8601String()});
      });
      await batch.commit(noResult: true);
    });
  }
}
