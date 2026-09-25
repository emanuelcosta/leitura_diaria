import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/logic/verse_progress.dart';

void main() {
  // Book 1: chapters of 10 and 30 verses; book 2: one chapter of 60.
  const counts = [
    [10, 30],
    [60],
  ];

  test('nothing read -> 0 of the total verse count', () {
    final result = computeVerseProgress(counts, []);
    expect(result.read, 0);
    expect(result.total, 100);
  });

  test('sums verse counts of read chapters, not the number of chapters', () {
    final result = computeVerseProgress(counts, [
      (bookOrder: 1, chapterNumber: 2),
      (bookOrder: 2, chapterNumber: 1),
    ]);
    // 2 of 3 chapters (66%) but 90 of 100 verses.
    expect(result.read, 90);
    expect(result.total, 100);
  });

  test('everything read -> read equals total', () {
    final result = computeVerseProgress(counts, [
      (bookOrder: 1, chapterNumber: 1),
      (bookOrder: 1, chapterNumber: 2),
      (bookOrder: 2, chapterNumber: 1),
    ]);
    expect(result.read, result.total);
  });

  test('out-of-range refs are ignored instead of throwing', () {
    final result = computeVerseProgress(counts, [
      (bookOrder: 0, chapterNumber: 1),
      (bookOrder: 3, chapterNumber: 1),
      (bookOrder: 1, chapterNumber: 5),
      (bookOrder: 1, chapterNumber: 1),
    ]);
    expect(result.read, 10);
  });
}
