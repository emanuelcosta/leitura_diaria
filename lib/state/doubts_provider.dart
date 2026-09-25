import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/doubt_verse.dart';
import '../data/repositories/doubt_sync_repository.dart';
import '../data/repositories/doubt_verse_repository.dart';
import '../data/repositories/sync_checkpoint_repository.dart';
import '../data/repositories/tombstone_repository.dart';
import '../logic/sync_merge.dart';
import '../services/auth_service.dart';

/// Mirrors FavoritesProvider's pattern for the "tenho dúvida" highlight,
/// plus an optional note per doubt (what the user was thinking).
class DoubtsProvider extends ChangeNotifier {
  final DoubtVerseRepository _repo;
  final DoubtSyncRepository? _syncRepo;
  final TombstoneRepository _tombstones;
  final SyncCheckpointRepository _checkpoints;
  StreamSubscription<AuthState>? _authSub;

  Map<String, DoubtVerse> _doubtsById = {};
  bool _loaded = false;

  DoubtsProvider({
    DoubtVerseRepository? repo,
    DoubtSyncRepository? syncRepo,
    TombstoneRepository? tombstones,
    SyncCheckpointRepository? checkpoints,
  })  : _repo = repo ?? DoubtVerseRepository(),
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

  bool isDoubt(String bookId, int chapterNumber, int verseNumber) =>
      _doubtsById.containsKey('$bookId-$chapterNumber-$verseNumber');

  String? noteFor(String bookId, int chapterNumber, int verseNumber) =>
      _doubtsById['$bookId-$chapterNumber-$verseNumber']?.note;

  /// How many verses are marked as doubts — used for the Dashboard's
  /// pending-doubts summary card.
  int get count => _doubtsById.length;

  Future<void> load() async {
    final doubts = await _repo.getAll();
    _doubtsById = {for (final d in doubts) d.id: d};
    _loaded = true;
    notifyListeners();
  }

  Future<List<DoubtVerse>> getAll() => _repo.getAll();

  /// Marks a verse as a doubt, with an optional note on why. Overwrites any
  /// existing note if it was already marked (see also [updateNote] to
  /// change the note without touching the mark itself).
  Future<void> mark(String bookId, int chapterNumber, int verseNumber, {String? note}) async {
    await _repo.add(bookId, chapterNumber, verseNumber, note: note);
    await _tombstones.clear(SyncKind.doubt, '$bookId-$chapterNumber-$verseNumber'); // marked again
    final doubt = DoubtVerse(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      note: note,
      createdAt: DateTime.now(),
    );
    _doubtsById[doubt.id] = doubt;
    notifyListeners();
    unawaited(_syncRepo?.push(doubt).catchError((_) {}));
  }

  /// Unmarks locally and records a tombstone, so the next sync spreads the
  /// removal instead of another device pushing the doubt back.
  Future<void> unmark(String bookId, int chapterNumber, int verseNumber) async {
    final id = '$bookId-$chapterNumber-$verseNumber';
    final at = DateTime.now();
    await _repo.remove(bookId, chapterNumber, verseNumber);
    await _tombstones.record(SyncKind.doubt, id, at);
    _doubtsById.remove(id);
    notifyListeners();
    unawaited(_syncRepo?.pushDeleted({id: at}).catchError((_) {}));
  }

  /// Edits the note on an already-marked doubt without resetting its
  /// createdAt (unlike calling [mark] again).
  Future<void> updateNote(String bookId, int chapterNumber, int verseNumber, String? note) async {
    final id = '$bookId-$chapterNumber-$verseNumber';
    final existing = _doubtsById[id];
    if (existing == null) return;
    final now = DateTime.now();
    await _repo.setNote(bookId, chapterNumber, verseNumber, note, now);
    final updated = DoubtVerse(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      note: note,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    _doubtsById[id] = updated;
    notifyListeners();
    unawaited(_syncRepo?.push(updated).catchError((_) {}));
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
      lastSyncedAt: await _checkpoints.get(SyncKind.doubt),
      now: startedAt,
      idOf: (d) => d.id,
      // Same "changed" rule as applyDeletions below.
      modifiedAt: (d) => d.createdAt,
    );
    final result = applyDeletions(
      merged: mergeDoubts(local, remote.live),
      allVersions: [...local, ...remote.live],
      localDeleted: {...missed, ...await _tombstones.getAll(SyncKind.doubt)},
      remoteDeleted: remote.deleted,
      idOf: (d) => d.id,
      // Doubts have no edit timestamp: a doubt counts as "changed" when it
      // was (re)marked, so editing only its comment doesn't undo a removal
      // made on another device.
      modifiedAt: (d) => d.createdAt,
    );
    await _repo.replaceAll(result.live);
    // Expired deletion records are purged here and on the server alike.
    final deleted = pruneDeletions(result.deleted, DateTime.now());
    await _tombstones.replaceAll(SyncKind.doubt, deleted);
    await syncRepo.pushAll(result.live);
    await syncRepo.pushDeleted(deleted);
    // Only after a complete sync: the start time, so anything edited
    // meanwhile counts as newer than this checkpoint.
    await _checkpoints.set(SyncKind.doubt, startedAt);
    await load();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
