import '../data/models/doubt_verse.dart';
import '../data/models/favorite_verse.dart';
import '../data/models/verse_note.dart';

/// Union of [local] and [remote] keyed by [idOf]: an item present on only
/// one side is kept, and [resolve] picks the winner when both have it.
///
/// Used by every list-shaped sync (favorites, notes, doubts) so a sign-in or
/// a manual "Sincronizar agora" never drops data that only exists on this
/// device. Trade-off: a deletion made on another device comes back if this
/// device still has the item — same choice as [mergeChapterProgress]:
/// redoing a removal is better than losing data.
List<T> mergeById<T>(
  List<T> local,
  List<T> remote, {
  required String Function(T) idOf,
  required T Function(T local, T remote) resolve,
}) {
  final merged = {for (final r in remote) idOf(r): r};
  for (final l in local) {
    final r = merged[idOf(l)];
    merged[idOf(l)] = r == null ? l : resolve(l, r);
  }
  return merged.values.toList();
}

List<FavoriteVerse> mergeFavorites(List<FavoriteVerse> local, List<FavoriteVerse> remote) =>
    mergeById(
      local,
      remote,
      idOf: (f) => f.id,
      resolve: (l, r) => l.createdAt.isAfter(r.createdAt) ? r : l,
    );

/// Most recently edited note wins.
List<VerseNote> mergeVerseNotes(List<VerseNote> local, List<VerseNote> remote) => mergeById(
      local,
      remote,
      idOf: (n) => n.id,
      resolve: (l, r) => r.updatedAt.isAfter(l.updatedAt) ? r : l,
    );

/// Keeps the earliest mark date; local note wins when non-empty, since doubts
/// carry no edit timestamp to compare.
List<DoubtVerse> mergeDoubts(List<DoubtVerse> local, List<DoubtVerse> remote) => mergeById(
      local,
      remote,
      idOf: (d) => d.id,
      resolve: (l, r) {
        final hasLocalNote = l.note != null && l.note!.trim().isNotEmpty;
        return DoubtVerse(
          bookId: l.bookId,
          chapterNumber: l.chapterNumber,
          verseNumber: l.verseNumber,
          note: hasLocalNote ? l.note : r.note,
          createdAt: l.createdAt.isAfter(r.createdAt) ? r.createdAt : l.createdAt,
        );
      },
    );
