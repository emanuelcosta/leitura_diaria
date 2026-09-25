import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/data/database/app_database.dart';
import 'package:leitura_diaria/data/repositories/sync_checkpoint_repository.dart';
import 'package:leitura_diaria/data/repositories/tombstone_repository.dart';

void main() {
  late Database db;
  final repo = SyncCheckpointRepository();
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

  test('never synced -> null', () async {
    expect(await repo.get(SyncKind.favorite), isNull);
  });

  test('set then get, setting again overwrites', () async {
    await repo.set(SyncKind.favorite, jan);
    expect(await repo.get(SyncKind.favorite), jan);
    await repo.set(SyncKind.favorite, feb);
    expect(await repo.get(SyncKind.favorite), feb);
  });

  test('kinds kept apart', () async {
    await repo.set(SyncKind.doubt, jan);
    await repo.set(SyncKind.verseNote, feb);
    expect(await repo.get(SyncKind.doubt), jan);
    expect(await repo.get(SyncKind.verseNote), feb);
    expect(await repo.get(SyncKind.favorite), isNull);
  });
}
