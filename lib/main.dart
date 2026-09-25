import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io' show File, Platform;

// On desktop (Windows / macOS / Linux) use the ffi implementation of
// sqflite. This must be initialized before any call to the global
// openDatabase/getDatabasesPath APIs (see runtime error in issue report).
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/bookmark_sync_repository.dart';
import 'data/repositories/doubt_sync_repository.dart';
import 'data/repositories/favorite_sync_repository.dart';
import 'data/repositories/push_subscription_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/repositories/verse_note_sync_repository.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'state/auth_provider.dart';
import 'state/bookmark_provider.dart';
import 'state/doubts_provider.dart';
import 'state/favorites_provider.dart';
import 'state/reading_plan_provider.dart';
import 'state/settings_provider.dart';
import 'state/verse_notes_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    if (Platform.isWindows) _preloadBundledSqlite();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDatabase.useAppSupportDirectory();
  }

  // Sync with Supabase is optional: without valid credentials the app keeps
  // working fully offline (all repos stay null, see below).
  SyncRepository? syncRepo;
  FavoriteSyncRepository? favoriteSyncRepo;
  VerseNoteSyncRepository? verseNoteSyncRepo;
  DoubtSyncRepository? doubtSyncRepo;
  BookmarkSyncRepository? bookmarkSyncRepo;
  PushSubscriptionRepository? pushSubscriptionRepo;
  try {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
    if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
      await AuthService.init(url: url, publishableKey: anonKey);
      syncRepo = SyncRepository();
      favoriteSyncRepo = FavoriteSyncRepository();
      verseNoteSyncRepo = VerseNoteSyncRepository();
      doubtSyncRepo = DoubtSyncRepository();
      bookmarkSyncRepo = BookmarkSyncRepository();
      pushSubscriptionRepo = PushSubscriptionRepository();
    }
  } catch (_) {
    // No .env bundled (e.g. a build without Supabase configured) — ignore.
  }

  // Firebase is optional too: a build without google-services.json /
  // GoogleService-Info.plist bundled yet (e.g. iOS before its Firebase app
  // is registered) keeps working, just without push notifications —
  // PushNotificationService's `_ready` guard handles that.
  // Desktop is skipped entirely: firebase_messaging has no Windows/Linux
  // support, and on Windows firebase_core's native C++ SDK aborts the
  // process without a config instead of throwing — the catch never runs.
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      // No Firebase config bundled for this platform/build — ignore.
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(SettingsRepository())..load()),
        ChangeNotifierProvider(create: (_) => ReadingPlanProvider(syncRepo: syncRepo)..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(syncRepo: favoriteSyncRepo)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => VerseNotesProvider(syncRepo: verseNoteSyncRepo)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => DoubtsProvider(syncRepo: doubtSyncRepo)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider(syncRepo: bookmarkSyncRepo)..load(),
        ),
        Provider(create: (_) => NotificationService()),
        Provider(
          create: (context) => PushNotificationService(
            notificationService: context.read<NotificationService>(),
            settingsRepo: SettingsRepository(),
            subscriptionRepo: pushSubscriptionRepo,
          ),
        ),
      ],
      child: const LeituraDiariaApp(),
    ),
  );
}

/// Windows release builds ship `sqlite3.dll` next to the exe but bundle an
/// empty NativeAssetsManifest.json (Flutter 3.41 toolchain), so
/// package:sqlite3 can't resolve its symbols and main() throws before
/// runApp — the window never appears. Its fallback searches modules already
/// loaded in the process, so loading the bundled DLL up front is enough.
/// Absolute path (not a bare name) so the DLL search order can't pick up
/// some other sqlite3.dll. Debug builds resolve via the manifest and may not
/// have the DLL beside the exe — hence the silent skip.
void _preloadBundledSqlite() {
  final dll = File('${File(Platform.resolvedExecutable).parent.path}\\sqlite3.dll');
  if (!dll.existsSync()) return;
  try {
    DynamicLibrary.open(dll.path);
  } catch (_) {
    // Fall through: sqfliteFfiInit will report the real error.
  }
}
