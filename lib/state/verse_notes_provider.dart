import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/verse_note.dart';
import '../data/repositories/sync_checkpoint_repository.dart';
import '../data/repositories/tombstone_repository.dart';
import '../data/repositories/verse_note_repository.dart';
import '../data/repositories/verse_note_sync_repository.dart';
import '../logic/sync_merge.dart';
import '../services/auth_service.dart';

class VerseNotesProvider extends ChangeNotifier {
  final VerseNoteRepository _repo;
  final VerseNoteSyncRepository? _syncRepo;
  final TombstoneRepository _tombstones;
  final SyncCheckpointRepository _checkpoints;
  StreamSubscription<AuthState>? _authSub;

  Map<String, String> _notesById = {};
  bool _loaded = false;

  VerseNotesProvider({
    VerseNoteRepository? repo,
    VerseNoteSyncRepository? syncRepo,
    TombstoneRepository? tombstones,
    SyncCheckpointRepository? checkpoints,
  })  : _repo = repo ?? VerseNoteRepository(),
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

  String? noteFor(String bookId, int chapterNumber, int verseNumber) =>
      _notesById['$bookId-$chapterNumber-$verseNumber'];

  Future<void> load() async {
    final notes = await _repo.getAll();
    _notesById = {for (final n in notes) n.id: n.note};
    _loaded = true;
    notifyListeners();
  }

  Future<List<VerseNote>> getAll() => _repo.getAll();

  /// Empty text deletes the note — recorded as a tombstone so the deletion
  /// syncs instead of another device pushing the note back.
  Future<void> setNote(String bookId, int chapterNumber, int verseNumber, String text) async {
    await _repo.set(bookId, chapterNumber, verseNumber, text);
    final id = '$bookId-$chapterNumber-$verseNumber';
    final trimmed = text.trim();
    final now = DateTime.now();
    if (trimmed.isEmpty) {
      _notesById.remove(id);
      await _tombstones.record(SyncKind.verseNote, id, now);
    } else {
      _notesById[id] = trimmed;
      await _tombstones.clear(SyncKind.verseNote, id);
    }
    notifyListeners();

    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    if (trimmed.isEmpty) {
      unawaited(syncRepo.pushDeleted({id: now}).catchError((_) {}));
    } else {
      final note = VerseNote(
        bookId: bookId,
        chapterNumber: chapterNumber,
        verseNumber: verseNumber,
        note: trimmed,
        updatedAt: DateTime.now(),
      );
      unawaited(syncRepo.push(note).catchError((_) {}));
    }
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
      lastSyncedAt: await _checkpoints.get(SyncKind.verseNote),
      now: startedAt,
      idOf: (n) => n.id,
      modifiedAt: (n) => n.updatedAt,
    );
    final result = applyDeletions(
      merged: mergeVerseNotes(local, remote.live),
      allVersions: [...local, ...remote.live],
      localDeleted: {...missed, ...await _tombstones.getAll(SyncKind.verseNote)},
      remoteDeleted: remote.deleted,
      idOf: (n) => n.id,
      modifiedAt: (n) => n.updatedAt,
    );
    await _repo.replaceAll(result.live);
    // Expired deletion records are purged here and on the server alike.
    final deleted = pruneDeletions(result.deleted, DateTime.now());
    await _tombstones.replaceAll(SyncKind.verseNote, deleted);
    await syncRepo.pushAll(result.live);
    await syncRepo.pushDeleted(deleted);
    // Only after a complete sync: the start time, so anything edited
    // meanwhile counts as newer than this checkpoint.
    await _checkpoints.set(SyncKind.verseNote, startedAt);
    await load();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
