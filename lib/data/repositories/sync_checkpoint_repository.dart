import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'tombstone_repository.dart';

/// When each synced list last completed a full pull + push — read by
/// missedDeletions to catch deletions the server already purged.
class SyncCheckpointRepository {
  Future<DateTime?> get(SyncKind kind) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('sync_checkpoints', where: 'kind = ?', whereArgs: [kind.name]);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['last_synced_at'] as String);
  }

  Future<void> set(SyncKind kind, DateTime syncedAt) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'sync_checkpoints',
      {'kind': kind.name, 'last_synced_at': syncedAt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
