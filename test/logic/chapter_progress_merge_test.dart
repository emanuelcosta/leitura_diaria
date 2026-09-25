import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/data/models/chapter.dart';
import 'package:leitura_diaria/logic/chapter_progress_merge.dart';

Chapter _local(int n, {bool isRead = false, DateTime? readAt, String? note}) => Chapter(
      id: 'GEN-$n',
      bookId: 'GEN',
      chapterNumber: n,
      planDay: 1,
      isRead: isRead,
      readAt: readAt,
      note: note,
    );

RemoteChapterState _remote(int n, {bool isRead = false, DateTime? readAt, String? note}) => (
      bookId: 'GEN',
      chapterNumber: n,
      isRead: isRead,
      readAt: readAt,
      note: note,
    );

void main() {
  test('empty remote -> local unchanged', () {
    final local = [_local(1, isRead: true, readAt: DateTime(2026, 1, 1))];
    final merged = mergeChapterProgress(local, []);
    expect(merged.single.isRead, isTrue);
    expect(merged.single.readAt, DateTime(2026, 1, 1));
  });

  test('read locally, unread remotely -> stays read (local read is never lost)', () {
    final merged = mergeChapterProgress(
      [_local(1, isRead: true, readAt: DateTime(2026, 1, 1))],
      [_remote(1)],
    );
    expect(merged.single.isRead, isTrue);
    expect(merged.single.readAt, DateTime(2026, 1, 1));
  });

  test('unread locally, read remotely -> becomes read with remote date', () {
    final merged = mergeChapterProgress(
      [_local(1)],
      [_remote(1, isRead: true, readAt: DateTime(2026, 2, 1))],
    );
    expect(merged.single.isRead, isTrue);
    expect(merged.single.readAt, DateTime(2026, 2, 1));
  });

  test('read on both sides -> keeps earliest read date', () {
    final merged = mergeChapterProgress(
      [_local(1, isRead: true, readAt: DateTime(2026, 3, 1))],
      [_remote(1, isRead: true, readAt: DateTime(2026, 2, 1))],
    );
    expect(merged.single.readAt, DateTime(2026, 2, 1));
  });

  test('unread on both sides -> stays unread with no date', () {
    final merged = mergeChapterProgress([_local(1)], [_remote(1)]);
    expect(merged.single.isRead, isFalse);
    expect(merged.single.readAt, isNull);
  });

  test('note: local wins when present, blank local falls back to remote', () {
    final merged = mergeChapterProgress(
      [_local(1, note: 'local'), _local(2, note: '  ')],
      [_remote(1, note: 'remote'), _remote(2, note: 'remote')],
    );
    expect(merged[0].note, 'local');
    expect(merged[1].note, 'remote');
  });

  test('remote rows for chapters missing locally are ignored', () {
    final merged = mergeChapterProgress([_local(1)], [_remote(99, isRead: true)]);
    expect(merged, hasLength(1));
    expect(merged.single.isRead, isFalse);
  });
}
