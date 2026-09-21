import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'reading_diary.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => createSchema(db),
    );
  }

  /// Shared by the real app and by tests seeding an in-memory ffi database.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        testament TEXT NOT NULL,
        track INTEGER NOT NULL,
        book_order INTEGER NOT NULL,
        chapter_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL REFERENCES books(id),
        chapter_number INTEGER NOT NULL,
        plan_day INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_at TEXT,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_chapters_book_id ON chapters(book_id)');
    await db.execute('CREATE INDEX idx_chapters_plan_day ON chapters(plan_day)');
    await db.execute(
      'CREATE INDEX idx_chapters_read_at ON chapters(read_at) WHERE is_read = 1',
    );
  }

  /// For tests: allows injecting an in-memory ffi database.
  void setTestDatabase(Database db) {
    _db = db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
