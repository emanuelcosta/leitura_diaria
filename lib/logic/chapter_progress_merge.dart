import '../data/models/chapter.dart';

typedef RemoteChapterState = ({
  String bookId,
  int chapterNumber,
  bool isRead,
  DateTime? readAt,
  String? note,
});

/// Merges local chapter state with what came from sync, never discarding a
/// read mark from either side: a chapter read on any device stays read.
///
/// - `isRead`: true if read locally OR remotely.
/// - `readAt`: the earliest known read date (keeps streak/calendar history).
/// - `note`: local note wins when present, otherwise the remote one.
///
/// Trade-off: un-marking a chapter on one device doesn't propagate through
/// this merge (the other device's read mark comes back on its next sign-in).
/// Losing reading history is worse than an unmark that has to be redone.
List<Chapter> mergeChapterProgress(
  List<Chapter> local,
  Iterable<RemoteChapterState> remote,
) {
  final remoteByKey = {
    for (final r in remote) '${r.bookId}-${r.chapterNumber}': r,
  };

  return [
    for (final l in local) _mergeOne(l, remoteByKey['${l.bookId}-${l.chapterNumber}']),
  ];
}

Chapter _mergeOne(Chapter local, RemoteChapterState? remote) {
  if (remote == null) return local;

  final isRead = local.isRead || remote.isRead;
  final readDates = [
    if (local.isRead && local.readAt != null) local.readAt!,
    if (remote.isRead && remote.readAt != null) remote.readAt!,
  ]..sort();
  final hasLocalNote = local.note != null && local.note!.trim().isNotEmpty;

  return Chapter(
    id: local.id,
    bookId: local.bookId,
    chapterNumber: local.chapterNumber,
    planDay: local.planDay,
    isRead: isRead,
    readAt: isRead ? (readDates.isEmpty ? null : readDates.first) : null,
    note: hasLocalNote ? local.note : remote.note,
  );
}
