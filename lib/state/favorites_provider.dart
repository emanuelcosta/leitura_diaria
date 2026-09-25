import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/favorite_color.dart';
import '../data/models/favorite_verse.dart';
import '../data/repositories/favorite_sync_repository.dart';
import '../data/repositories/favorite_verse_repository.dart';
import '../logic/sync_merge.dart';
import '../services/auth_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoriteVerseRepository _repo;
  final FavoriteSyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  Map<String, FavoriteColor> _colorsById = {};
  bool _loaded = false;

  FavoritesProvider({FavoriteVerseRepository? repo, FavoriteSyncRepository? syncRepo})
      : _repo = repo ?? FavoriteVerseRepository(),
        _syncRepo = syncRepo {
    if (_syncRepo != null) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (AuthService.startsSession(state)) {
          // Background pull: failures (e.g. offline at startup) are swallowed
          // on purpose — "Sincronizar agora" is where sync errors surface.
          unawaited(pullFromRemoteAndMerge().catchError((_) {}));
        }
      });
    }
  }

  bool get loaded => _loaded;

  bool isFavorite(String bookId, int chapterNumber, int verseNumber) =>
      _colorsById.containsKey('$bookId-$chapterNumber-$verseNumber');

  /// The verse's marker color, or null if it isn't marked.
  FavoriteColor? colorOf(String bookId, int chapterNumber, int verseNumber) =>
      _colorsById['$bookId-$chapterNumber-$verseNumber'];

  Future<void> load() async {
    final favorites = await _repo.getAll();
    _colorsById = {for (final f in favorites) f.id: f.color};
    _loaded = true;
    notifyListeners();
  }

  Future<List<FavoriteVerse>> getAll() => _repo.getAll();

  /// Marks the verse with [color] (new favorite, or recolor of an existing
  /// one). Pushing is fire-and-forget like every other sync write.
  Future<void> setColor(String bookId, int chapterNumber, int verseNumber, FavoriteColor color) async {
    final saved = await _repo.setColor(bookId, chapterNumber, verseNumber, color);
    _colorsById[saved.id] = color;
    notifyListeners();
    // Failures swallowed on purpose (known gap, see CLAUDE.md): the next
    // pull/merge reconciles.
    unawaited(_syncRepo?.push(saved).catchError((_) {}));
  }

  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    await _repo.remove(bookId, chapterNumber, verseNumber);
    _colorsById.remove('$bookId-$chapterNumber-$verseNumber');
    notifyListeners();
    unawaited(_syncRepo?.remove(bookId, chapterNumber, verseNumber).catchError((_) {}));
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
