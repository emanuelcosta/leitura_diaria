import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'reading_diary.db';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// Desktop only (call after switching to the ffi factory, before first
  /// use). sqflite_common_ffi's default path is `.dart_tool/...` relative to
  /// the working directory — on Windows that's inside the build output, so a
  /// rebuild/`flutter clean` or moving the app folder silently lost the DB.
  /// Moves it to the per-user app data dir (%APPDATA%\<company>\<product>),
  /// copying a DB found at the old location once so nothing already stored
  /// locally is lost.
  static Future<void> useAppSupportDirectory() async {
    final legacy = File(p.join(await getDatabasesPath(), _fileName));
    final dir = (await getApplicationSupportDirectory()).path;
    final target = File(p.join(dir, _fileName));
    if (!target.existsSync() && legacy.existsSync()) {
      await target.parent.create(recursive: true);
      await legacy.copy(target.path);
    }
    await databaseFactory.setDatabasesPath(dir);
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _fileName);
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, version) => createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        // Each step is additive (CREATE/ALTER), never DROP — see CLAUDE.md.
        if (oldVersion < 2) {
          await _createFavoriteVerses(db);
        }
        if (oldVersion < 3) {
          await _createVerseNotes(db);
        }
        if (oldVersion < 4) {
          await _createDoubtVerses(db);
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE doubt_verses ADD COLUMN note TEXT');
        }
        if (oldVersion < 6) {
          await addFavoriteColor(db);
        }
      },
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
    await _createFavoriteVerses(db);
    await addFavoriteColor(db);
    await _createVerseNotes(db);
    await _createDoubtVerses(db);
  }

  /// v6: each favorite gets its own marker color (existing ones become amber,
  /// the single color used until then) and an updated_at for newest-wins
  /// sync of color changes (backfilled from created_at).
  @visibleForTesting
  static Future<void> addFavoriteColor(Database db) async {
    await db.execute("ALTER TABLE favorite_verses ADD COLUMN color TEXT NOT NULL DEFAULT 'amber'");
    await db.execute('ALTER TABLE favorite_verses ADD COLUMN updated_at TEXT');
    await db.execute('UPDATE favorite_verses SET updated_at = created_at WHERE updated_at IS NULL');
  }

  static Future<void> _createFavoriteVerses(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_verses (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_favorite_verses_chapter '
      'ON favorite_verses(book_id, chapter_number)',
    );
  }

  /// A verse note is independent of favoriting — a verse can have a note
  /// without being favorited, and vice versa, so this stays its own table
  /// rather than a nullable column bolted onto favorite_verses (where a
  /// row's mere existence means "favorited").
  static Future<void> _createVerseNotes(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verse_notes (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL,
        note TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_verse_notes_chapter '
      'ON verse_notes(book_id, chapter_number)',
    );
  }

  /// Same shape/existence-means-marked convention as favorite_verses, but a
  /// separate concern: a verse can be favorited, doubted, both, or neither
  /// independently. [note] is optional — why the user marked it, so they
  /// remember what they were thinking later.
  static Future<void> _createDoubtVerses(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doubt_verses (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_number INTEGER NOT NULL,
        verse_number INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_doubt_verses_chapter '
      'ON doubt_verses(book_id, chapter_number)',
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
