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

/// Item id → when it was deleted ("tombstone"). Without these, the union
/// merge above can't tell "the other device hasn't got this yet" from "the
/// other device deleted this" — so deletions came back on the next sync.
typedef Deletions = Map<String, DateTime>;

/// How long a deletion record is kept before it's purged for good — here
/// (pruneDeletions) and on the server (pg_cron job, migration 0011). Must
/// match both sides: a device that syncs within this window learns about
/// the deletion; one offline for longer may bring the item back (same
/// trade-off as a "Lixeira" in Notion/Keep).
const deletionRetention = Duration(days: 30);

/// Drops deletions older than [retention]. Run before storing/pushing the
/// merged deletions, so the app doesn't recreate records the server already
/// purged.
Deletions pruneDeletions(Deletions deletions, DateTime now, {Duration retention = deletionRetention}) {
  final cutoff = now.subtract(retention);
  return {
    for (final e in deletions.entries)
      if (e.value.isAfter(cutoff)) e.key: e.value,
  };
}

/// Applies deletions to an already-merged live list: the latest event wins.
/// An item stays deleted unless some version of it (on either side) was
/// modified *after* the deletion — e.g. re-marked later, which resurrects
/// it. Ties go to the deletion. Returns the surviving items and the
/// deletions still in force (a deletion superseded by a newer edit is
/// dropped).
({List<T> live, Deletions deleted}) applyDeletions<T>({
  required List<T> merged,
  required Iterable<T> allVersions,
  required Deletions localDeleted,
  required Deletions remoteDeleted,
  required String Function(T) idOf,
  required DateTime Function(T) modifiedAt,
}) {
  final deleted = <String, DateTime>{...localDeleted};
  remoteDeleted.forEach((id, at) {
    final current = deleted[id];
    if (current == null || at.isAfter(current)) deleted[id] = at;
  });

  final latestLive = <String, DateTime>{};
  for (final item in allVersions) {
    final id = idOf(item);
    final at = modifiedAt(item);
    final current = latestLive[id];
    if (current == null || at.isAfter(current)) latestLive[id] = at;
  }

  final live = <T>[];
  for (final item in merged) {
    final id = idOf(item);
    final deletedAt = deleted[id];
    if (deletedAt != null && !latestLive[id]!.isAfter(deletedAt)) continue;
    live.add(item);
    deleted.remove(id); // resurrected by a newer edit
  }
  return (live: live, deleted: deleted);
}

/// Deletions this device missed because it was away longer than the server
/// keeps them (the pg_cron purge, migration 0011): a local item missing from
/// the server that already existed at the last successful sync was on the
/// server then, so it was deleted — and purged — since. Items changed after
/// that sync are new here and are kept. Only applies when the gap exceeds
/// [retention]; within it, the server's own tombstones say what was deleted.
///
/// Each record is dated [lastSyncedAt], so applyDeletions drops the item
/// (ties go to the deletion) and pruneDeletions then discards the record
/// instead of pushing it back.
Deletions missedDeletions<T>({
  required Iterable<T> local,
  required Set<String> remoteIds,
  required DateTime? lastSyncedAt,
  required DateTime now,
  required String Function(T) idOf,
  required DateTime Function(T) modifiedAt,
  Duration retention = deletionRetention,
}) {
  if (lastSyncedAt == null || now.difference(lastSyncedAt) <= retention) return {};
  return {
    for (final item in local)
      if (!remoteIds.contains(idOf(item)) && !modifiedAt(item).isAfter(lastSyncedAt)) idOf(item): lastSyncedAt,
  };
}

/// Most recently recolored wins the marker color; the earliest createdAt is
/// kept (when the verse was first marked).
List<FavoriteVerse> mergeFavorites(List<FavoriteVerse> local, List<FavoriteVerse> remote) => mergeById(
      local,
      remote,
      idOf: (f) => f.id,
      resolve: (l, r) {
        final newest = r.updatedAt.isAfter(l.updatedAt) ? r : l;
        final earliest = l.createdAt.isAfter(r.createdAt) ? r.createdAt : l.createdAt;
        return FavoriteVerse(
          bookId: l.bookId,
          chapterNumber: l.chapterNumber,
          verseNumber: l.verseNumber,
          color: newest.color,
          createdAt: earliest,
          updatedAt: newest.updatedAt,
        );
      },
    );

/// Most recently edited note wins.
List<VerseNote> mergeVerseNotes(List<VerseNote> local, List<VerseNote> remote) => mergeById(
      local,
      remote,
      idOf: (n) => n.id,
      resolve: (l, r) => r.updatedAt.isAfter(l.updatedAt) ? r : l,
    );

/// The most recently edited comment wins (updatedAt), whichever side it's
/// on — before doubts had updatedAt, "local wins" let a device with a stale
/// comment overwrite an edit made on another device. On a tie (rows
/// backfilled with updatedAt = createdAt), a non-empty local comment wins,
/// as before. The earliest mark date is kept.
List<DoubtVerse> mergeDoubts(List<DoubtVerse> local, List<DoubtVerse> remote) => mergeById(
      local,
      remote,
      idOf: (d) => d.id,
      resolve: (l, r) {
        final hasLocalNote = l.note != null && l.note!.trim().isNotEmpty;
        final DoubtVerse winner;
        if (r.updatedAt.isAfter(l.updatedAt)) {
          winner = r;
        } else if (l.updatedAt.isAfter(r.updatedAt)) {
          winner = l;
        } else {
          winner = hasLocalNote ? l : r;
        }
        return DoubtVerse(
          bookId: l.bookId,
          chapterNumber: l.chapterNumber,
          verseNumber: l.verseNumber,
          note: winner.note,
          createdAt: l.createdAt.isAfter(r.createdAt) ? r.createdAt : l.createdAt,
          updatedAt: winner.updatedAt,
        );
      },
    );
