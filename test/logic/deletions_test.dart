import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/data/models/doubt_verse.dart';
import 'package:leitura_diaria/logic/sync_merge.dart';
import 'package:leitura_diaria/logic/verse_id.dart';

DoubtVerse _doubt(int verse, DateTime createdAt) =>
    DoubtVerse(bookId: 'genesis', chapterNumber: 1, verseNumber: verse, createdAt: createdAt);

void main() {
  final jan = DateTime(2026, 1, 1);
  final feb = DateTime(2026, 2, 1);
  final mar = DateTime(2026, 3, 1);

  ({List<DoubtVerse> live, Deletions deleted}) run(
    List<DoubtVerse> local,
    List<DoubtVerse> remote, {
    Deletions localDeleted = const {},
    Deletions remoteDeleted = const {},
  }) =>
      applyDeletions(
        merged: mergeDoubts(local, remote),
        allVersions: [...local, ...remote],
        localDeleted: localDeleted,
        remoteDeleted: remoteDeleted,
        idOf: (d) => d.id,
        modifiedAt: (d) => d.createdAt,
      );

  test('the reported bug: deleted on desktop, still on Android -> stays deleted', () {
    // Android (local) still has it; the server says desktop deleted it later.
    final result = run([_doubt(1, jan)], [], remoteDeleted: {'genesis-1-1': feb});
    expect(result.live, isEmpty);
    expect(result.deleted, {'genesis-1-1': feb});
  });

  test('deleted here, other side still has the old version -> stays deleted', () {
    final result = run([], [_doubt(1, jan)], localDeleted: {'genesis-1-1': feb});
    expect(result.live, isEmpty);
  });

  test('re-marked after the deletion -> comes back, deletion dropped', () {
    final result = run([_doubt(1, mar)], [], remoteDeleted: {'genesis-1-1': feb});
    expect(result.live.single.verseNumber, 1);
    expect(result.deleted, isEmpty);
  });

  test('a tie goes to the deletion', () {
    final result = run([_doubt(1, feb)], [], remoteDeleted: {'genesis-1-1': feb});
    expect(result.live, isEmpty);
  });

  test('the newest of two deletions is kept', () {
    final result = run([], [], localDeleted: {'genesis-1-1': jan}, remoteDeleted: {'genesis-1-1': mar});
    expect(result.deleted, {'genesis-1-1': mar});
  });

  test('unrelated items are untouched', () {
    final result = run([_doubt(1, jan), _doubt(2, jan)], [], remoteDeleted: {'genesis-1-1': feb});
    expect(result.live.map((d) => d.verseNumber), [2]);
  });

  test('pruneDeletions drops records older than the retention window', () {
    final now = DateTime(2026, 9, 30);
    final pruned = pruneDeletions({
      'old': now.subtract(const Duration(days: 31)),
      'recent': now.subtract(const Duration(days: 29)),
    }, now);
    expect(pruned.keys, ['recent']);
    expect(pruneDeletions({'x': now}, now, retention: Duration.zero), isEmpty);
  });

  group('missedDeletions (offline longer than the server keeps deletions)', () {
    final lastSync = DateTime(2026, 1, 1);
    final longAfter = lastSync.add(const Duration(days: 40));

    Deletions missed(List<DoubtVerse> local, Set<String> remoteIds, {DateTime? lastSyncedAt, DateTime? now}) =>
        missedDeletions(
          local: local,
          remoteIds: remoteIds,
          lastSyncedAt: lastSyncedAt,
          now: now ?? longAfter,
          idOf: (d) => d.id,
          modifiedAt: (d) => d.createdAt,
        );

    test('first sync ever (no checkpoint) -> nothing counts as deleted', () {
      expect(missed([_doubt(1, jan)], {}), isEmpty);
    });

    test('gap within retention -> nothing, the server tombstones still exist', () {
      final now = lastSync.add(const Duration(days: 30));
      expect(missed([_doubt(1, DateTime(2025, 12, 1))], {}, lastSyncedAt: lastSync, now: now), isEmpty);
    });

    test('gap past retention, old item gone from the server -> deleted as of the last sync', () {
      final result = missed([_doubt(1, DateTime(2025, 12, 1))], {}, lastSyncedAt: lastSync);
      expect(result, {'genesis-1-1': lastSync});
    });

    test('an item changed exactly at the last sync was already there -> deleted', () {
      expect(missed([_doubt(1, lastSync)], {}, lastSyncedAt: lastSync).keys, ['genesis-1-1']);
    });

    test('item created after the last sync is new here -> kept', () {
      expect(missed([_doubt(1, DateTime(2026, 1, 15))], {}, lastSyncedAt: lastSync), isEmpty);
    });

    test('item still on the server -> kept', () {
      expect(missed([_doubt(1, DateTime(2025, 12, 1))], {'genesis-1-1'}, lastSyncedAt: lastSync), isEmpty);
    });

    test('with applyDeletions + pruneDeletions: item dropped and the record not pushed back', () {
      final local = [_doubt(1, DateTime(2025, 12, 1)), _doubt(2, DateTime(2026, 2, 1))];
      final result = run(local, [], localDeleted: missed(local, {}, lastSyncedAt: lastSync));
      expect(result.live.map((d) => d.verseNumber), [2]);
      expect(pruneDeletions(result.deleted, longAfter), isEmpty);
    });
  });

  test('parseVerseId splits from the end', () {
    expect(parseVerseId('genesis-3-16'), (bookId: 'genesis', chapterNumber: 3, verseNumber: 16));
    expect(parseVerseId('1pedro-5-7')?.bookId, '1pedro');
    expect(parseVerseId('some-book-2-3')?.bookId, 'some-book');
    expect(parseVerseId('genesis-3'), isNull);
    expect(parseVerseId('genesis-x-1'), isNull);
  });
}
