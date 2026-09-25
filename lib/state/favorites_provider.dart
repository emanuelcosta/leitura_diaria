import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/favorite_verse.dart';
import '../data/repositories/favorite_sync_repository.dart';
import '../data/repositories/favorite_verse_repository.dart';
import '../logic/sync_merge.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoriteVerseRepository _repo;
  final FavoriteSyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  Set<String> _favoriteIds = {};
  bool _loaded = false;

  FavoritesProvider({FavoriteVerseRepository? repo, FavoriteSyncRepository? syncRepo})
      : _repo = repo ?? FavoriteVerseRepository(),
        _syncRepo = syncRepo {
    if (_syncRepo != null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) {
          pullFromRemoteAndMerge();
        }
      });
    }
  }

  bool get loaded => _loaded;

  bool isFavorite(String bookId, int chapterNumber, int verseNumber) =>
      _favoriteIds.contains('$bookId-$chapterNumber-$verseNumber');

  Future<void> load() async {
    final favorites = await _repo.getAll();
    _favoriteIds = favorites.map((f) => f.id).toSet();
    _loaded = true;
    notifyListeners();
  }

  Future<List<FavoriteVerse>> getAll() => _repo.getAll();

  Future<void> toggle(String bookId, int chapterNumber, int verseNumber) async {
    if (isFavorite(bookId, chapterNumber, verseNumber)) {
      await _repo.remove(bookId, chapterNumber, verseNumber);
      _favoriteIds.remove('$bookId-$chapterNumber-$verseNumber');
      notifyListeners();
      unawaited(_syncRepo?.remove(bookId, chapterNumber, verseNumber).catchError((_) {}));
    } else {
      await _repo.add(bookId, chapterNumber, verseNumber);
      _favoriteIds.add('$bookId-$chapterNumber-$verseNumber');
      notifyListeners();
      final favorite = FavoriteVerse(
        bookId: bookId,
        chapterNumber: chapterNumber,
        verseNumber: verseNumber,
        createdAt: DateTime.now(),
      );
      unawaited(_syncRepo?.push(favorite).catchError((_) {}));
    }
  }

  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    final merged = mergeFavorites(await _repo.getAll(), await syncRepo.pullAll());
    await _repo.replaceAll(merged);
    await syncRepo.pushAll(merged);
    await load();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
