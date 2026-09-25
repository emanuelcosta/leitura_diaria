import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'bookmark_provider.dart';
import 'doubts_provider.dart';
import 'favorites_provider.dart';
import 'reading_plan_provider.dart';
import 'verse_notes_provider.dart';

/// Pull + merge every synced feature at once. Shared by the "Sincronizar
/// agora" button and the resume-from-background sync (HomeShell), so a new
/// synced provider only has to be added here. Each provider is a no-op when
/// Supabase isn't configured; throws if any of them fails (callers decide
/// whether to surface or swallow that).
Future<void> pullAllFromRemote(BuildContext context) {
  return Future.wait([
    context.read<ReadingPlanProvider>().pullFromRemoteAndMerge(),
    context.read<FavoritesProvider>().pullFromRemoteAndMerge(),
    context.read<VerseNotesProvider>().pullFromRemoteAndMerge(),
    context.read<DoubtsProvider>().pullFromRemoteAndMerge(),
    context.read<BookmarkProvider>().pullFromRemoteAndMerge(),
  ]);
}
