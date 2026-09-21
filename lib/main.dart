import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/bookmark_sync_repository.dart';
import 'data/repositories/doubt_sync_repository.dart';
import 'data/repositories/favorite_sync_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/repositories/verse_note_sync_repository.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'state/auth_provider.dart';
import 'state/bookmark_provider.dart';
import 'state/doubts_provider.dart';
import 'state/favorites_provider.dart';
import 'state/reading_plan_provider.dart';
import 'state/settings_provider.dart';
import 'state/verse_notes_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sync with Supabase is optional: without valid credentials the app keeps
  // working fully offline (all repos stay null, see below).
  SyncRepository? syncRepo;
  FavoriteSyncRepository? favoriteSyncRepo;
  VerseNoteSyncRepository? verseNoteSyncRepo;
  DoubtSyncRepository? doubtSyncRepo;
  BookmarkSyncRepository? bookmarkSyncRepo;
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
    }
  } catch (_) {
    // No .env bundled (e.g. a build without Supabase configured) — ignore.
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
      ],
      child: const LeituraDiariaApp(),
    ),
  );
}
