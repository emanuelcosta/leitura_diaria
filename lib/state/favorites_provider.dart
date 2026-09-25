import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/favorite_color.dart';
import '../data/models/favorite_verse.dart';
import '../data/repositories/favorite_sync_repository.dart';
import '../data/repositories/favorite_verse_repository.dart';
import '../data/repositories/sync_checkpoint_repository.dart';
import '../data/repositories/tombstone_repository.dart';
import '../logic/sync_merge.dart';
import '../services/auth_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoriteVerseRepository _repo;
  final FavoriteSyncRepository? _syncRepo;
  final TombstoneRepository _tombstones;
  final SyncCheckpointRepository _checkpoints;
  StreamSubscription<AuthState>? _authSub;

  Map<String, FavoriteColor> _colorsById = {};
  bool _loaded = false;

  FavoritesProvider({
    FavoriteVerseRepository? repo,
    FavoriteSyncRepository? syncRepo,
    TombstoneRepository? tombstones,
    SyncCheckpointRepository? checkpoints,
  })  : _repo = repo ?? FavoriteVerseRepository(),
        _syncRepo = syncRepo,
        _tombstones = tombstones ?? TombstoneRepository(),
        _checkpoints = checkpoints ?? SyncCheckpointRepository() {
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
    await _tombstones.clear(SyncKind.favorite, saved.id); // marked again: no longer deleted
    _colorsById[saved.id] = color;
    notifyListeners();
    // Failures swallowed on purpose (known gap, see CLAUDE.md): the next
    // pull/merge reconciles.
    unawaited(_syncRepo?.push(saved).catchError((_) {}));
  }

  /// Deletes locally and records a tombstone, so the next sync spreads the
  /// deletion instead of another device pushing the marker back.
  Future<void> remove(String bookId, int chapterNumber, int verseNumber) async {
    final id = '$bookId-$chapterNumber-$verseNumber';
    final at = DateTime.now();
    await _repo.remove(bookId, chapterNumber, verseNumber);
    await _tombstones.record(SyncKind.favorite, id, at);
    _colorsById.remove(id);
    notifyListeners();
    unawaited(_syncRepo?.pushDeleted({id: at}).catchError((_) {}));
  }

  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    final startedAt = DateTime.now();
    final local = await _repo.getAll();
    final remote = await syncRepo.pullAll();
    // Away longer than the server keeps deletions: apply the ones it purged.
    final missed = missedDeletions(
      local: local,
      remoteIds: {for (final r in remote.live) r.id},
      lastSyncedAt: await _checkpoints.get(SyncKind.favorite),
      now: startedAt,
      idOf: (f) => f.id,
      modifiedAt: (f) => f.updatedAt,
    );
    final result = applyDeletions(
      merged: mergeFavorites(local, remote.live),
      allVersions: [...local, ...remote.live],
      localDeleted: {...missed, ...await _tombstones.getAll(SyncKind.favorite)},
      remoteDeleted: remote.deleted,
      idOf: (f) => f.id,
      modifiedAt: (f) => f.updatedAt,
    );
    await _repo.replaceAll(result.live);
    // Expired deletion records are purged here and on the server alike.
    final deleted = pruneDeletions(result.deleted, DateTime.now());
    await _tombstones.replaceAll(SyncKind.favorite, deleted);
    await syncRepo.pushAll(result.live);
    await syncRepo.pushDeleted(deleted);
    // Only after a complete sync: the start time, so anything edited
    // meanwhile counts as newer than this checkpoint.
    await _checkpoints.set(SyncKind.favorite, startedAt);
    await load();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
