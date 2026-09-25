import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/verse_note.dart';
import '../data/repositories/verse_note_repository.dart';
import '../data/repositories/verse_note_sync_repository.dart';
import '../logic/sync_merge.dart';

class VerseNotesProvider extends ChangeNotifier {
  final VerseNoteRepository _repo;
  final VerseNoteSyncRepository? _syncRepo;
  StreamSubscription<AuthState>? _authSub;

  Map<String, String> _notesById = {};
  bool _loaded = false;

  VerseNotesProvider({VerseNoteRepository? repo, VerseNoteSyncRepository? syncRepo})
      : _repo = repo ?? VerseNoteRepository(),
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

  String? noteFor(String bookId, int chapterNumber, int verseNumber) =>
      _notesById['$bookId-$chapterNumber-$verseNumber'];

  Future<void> load() async {
    final notes = await _repo.getAll();
    _notesById = {for (final n in notes) n.id: n.note};
    _loaded = true;
    notifyListeners();
  }

  Future<List<VerseNote>> getAll() => _repo.getAll();

  Future<void> setNote(String bookId, int chapterNumber, int verseNumber, String text) async {
    await _repo.set(bookId, chapterNumber, verseNumber, text);
    final id = '$bookId-$chapterNumber-$verseNumber';
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _notesById.remove(id);
    } else {
      _notesById[id] = trimmed;
    }
    notifyListeners();

    final syncRepo = _syncRepo;
    if (syncRepo == null) return;
    if (trimmed.isEmpty) {
      unawaited(syncRepo.remove(bookId, chapterNumber, verseNumber).catchError((_) {}));
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
    final merged = mergeVerseNotes(await _repo.getAll(), await syncRepo.pullAll());
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
