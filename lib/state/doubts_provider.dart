import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/doubt_verse.dart';
import '../data/repositories/doubt_sync_repository.dart';
import '../data/repositories/doubt_verse_repository.dart';
import '../logic/sync_merge.dart';
import '../services/auth_service.dart';

/// Mirrors FavoritesProvider's pattern for the "tenho dúvida" highlight,
/// plus an optional note per doubt (what the user was thinking).
class DoubtsProvider extends ChangeNotifier {
  final DoubtVerseRepository _repo;
  final DoubtSyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  Map<String, DoubtVerse> _doubtsById = {};
  bool _loaded = false;

  DoubtsProvider({DoubtVerseRepository? repo, DoubtSyncRepository? syncRepo})
      : _repo = repo ?? DoubtVerseRepository(),
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

  Future<void> unmark(String bookId, int chapterNumber, int verseNumber) async {
    await _repo.remove(bookId, chapterNumber, verseNumber);
    _doubtsById.remove('$bookId-$chapterNumber-$verseNumber');
    notifyListeners();
    unawaited(_syncRepo?.remove(bookId, chapterNumber, verseNumber).catchError((_) {}));
  }

  /// Edits the note on an already-marked doubt without resetting its
  /// createdAt (unlike calling [mark] again).
  Future<void> updateNote(String bookId, int chapterNumber, int verseNumber, String? note) async {
    final id = '$bookId-$chapterNumber-$verseNumber';
    final existing = _doubtsById[id];
    if (existing == null) return;
    await _repo.setNote(bookId, chapterNumber, verseNumber, note);
    final updated = DoubtVerse(
      bookId: bookId,
      chapterNumber: chapterNumber,
      verseNumber: verseNumber,
      note: note,
      createdAt: existing.createdAt,
    );
    _doubtsById[id] = updated;
    notifyListeners();
    unawaited(_syncRepo?.push(updated).catchError((_) {}));
  }

  Future<void> pullFromRemoteAndMerge() async {
    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    final merged = mergeDoubts(await _repo.getAll(), await syncRepo.pullAll());
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
