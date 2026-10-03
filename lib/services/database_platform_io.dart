import 'dart:ffi' show DynamicLibrary;
import 'dart:io' show File, Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/database/app_database.dart';

Future<void> initializeDatabasePlatform() async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

  if (Platform.isWindows) _preloadBundledSqlite();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  await AppDatabase.useAppSupportDirectory();
}

void _preloadBundledSqlite() {
  final dll = File('${File(Platform.resolvedExecutable).parent.path}\\sqlite3.dll');
  if (!dll.existsSync()) return;
  try {
    DynamicLibrary.open(dll.path);
  } catch (_) {
    // sqfliteFfiInit reports the loading error if the DLL cannot be used.
  }
}
