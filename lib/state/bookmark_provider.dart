import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/reading_bookmark.dart';
import '../data/repositories/bookmark_repository.dart';
import '../data/repositories/bookmark_sync_repository.dart';

/// "Continuar de onde parei". Unlike the list-shaped sync providers
/// (favorites, notes, doubts), this holds one mutable value, so a sign-in
/// merge is last-write-wins by [ReadingBookmark.savedAt] instead of
/// "remote empty ? push local : adopt remote" — either side could hold the
/// more recent save.
class BookmarkProvider extends ChangeNotifier {
  final BookmarkRepository _repo;
  final BookmarkSyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  ReadingBookmark? _bookmark;
  bool _loaded = false;

  BookmarkProvider({BookmarkRepository? repo, BookmarkSyncRepository? syncRepo})
      : _repo = repo ?? BookmarkRepository(),
        _syncRepo = syncRepo {
    if (_syncRepo != null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) {
          pullFromRemoteAndMerge();
        }
      });
    }
  }

  ReadingBookmark? get bookmark => _bookmark;
  bool get loaded => _loaded;

  Future<void> load() async {
    _bookmark = await _repo.get();
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    required String bookId,
    required int bookOrder,
    required String bookName,
    required int chapterNumber,
    int? verseNumber,
  }) async {
    final bookmark = ReadingBookmark(
      bookId: bookId,
      bookOrder: bookOrder,
      bookName: bookName,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      savedAt: DateTime.now(),
    );
    await _repo.set(bookmark);
    _bookmark = bookmark;
    notifyListeners();
    unawaited(_syncRepo?.push(bookmark).catchError((_) {}));
  }

  Future<void> clear() async {
    await _repo.clear();
    _bookmark = null;
    notifyListeners();
    unawaited(_syncRepo?.clear().catchError((_) {}));
  }

  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    final remote = await syncRepo.pull();
    final local = _bookmark;
    if (remote == null && local == null) return;
    if (remote != null && (local == null || remote.savedAt.isAfter(local.savedAt))) {
      await _repo.set(remote);
      _bookmark = remote;
      notifyListeners();
    } else if (local != null && (remote == null || local.savedAt.isAfter(remote.savedAt))) {
      await syncRepo.push(local);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
