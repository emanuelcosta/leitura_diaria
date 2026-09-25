import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/data/models/doubt_verse.dart';
import 'package:leitura_diaria/data/models/favorite_color.dart';
import 'package:leitura_diaria/data/models/favorite_verse.dart';
import 'package:leitura_diaria/data/models/verse_note.dart';
import 'package:leitura_diaria/logic/sync_merge.dart';

FavoriteVerse _fav(int verse, DateTime createdAt) =>
    FavoriteVerse(bookId: 'GEN', chapterNumber: 1, verseNumber: verse, createdAt: createdAt);

VerseNote _note(int verse, String text, DateTime updatedAt) => VerseNote(
    bookId: 'GEN', chapterNumber: 1, verseNumber: verse, note: text, updatedAt: updatedAt);

DoubtVerse _doubt(int verse, DateTime createdAt, {String? note}) => DoubtVerse(
    bookId: 'GEN', chapterNumber: 1, verseNumber: verse, note: note, createdAt: createdAt);

void main() {
  final jan = DateTime(2026, 1, 1);
  final feb = DateTime(2026, 2, 1);

  group('mergeById', () {
    test('keeps items that exist only locally (local data is never lost)', () {
      final merged = mergeFavorites([_fav(1, jan)], []);
      expect(merged.map((f) => f.verseNumber), [1]);
    });

    test('keeps items that exist only remotely', () {
      final merged = mergeFavorites([], [_fav(2, jan)]);
      expect(merged.map((f) => f.verseNumber), [2]);
    });

    test('union of disjoint sides, no duplicates for shared ids', () {
      final merged = mergeFavorites([_fav(1, jan), _fav(2, jan)], [_fav(2, jan), _fav(3, jan)]);
      expect(merged.map((f) => f.verseNumber).toSet(), {1, 2, 3});
      expect(merged, hasLength(3));
    });
  });

  test('favorites: same verse on both sides keeps earliest createdAt', () {
    final merged = mergeFavorites([_fav(1, feb)], [_fav(1, jan)]);
    expect(merged.single.createdAt, jan);
  });

  test('favorites: most recently recolored wins the color, whichever side it is on', () {
    final mar = DateTime(2026, 3, 1);
    FavoriteVerse colored(FavoriteColor c, DateTime updated) => FavoriteVerse(
        bookId: 'GEN', chapterNumber: 1, verseNumber: 1, color: c, createdAt: jan, updatedAt: updated);

    final remoteNewer = mergeFavorites([colored(FavoriteColor.amber, feb)], [colored(FavoriteColor.green, mar)]);
    expect(remoteNewer.single.color, FavoriteColor.green);
    expect(remoteNewer.single.updatedAt, mar);

    final localNewer = mergeFavorites([colored(FavoriteColor.pink, mar)], [colored(FavoriteColor.green, feb)]);
    expect(localNewer.single.color, FavoriteColor.pink);
  });

  test('notes: most recently edited wins, whichever side it is on', () {
    expect(mergeVerseNotes([_note(1, 'local', feb)], [_note(1, 'remote', jan)]).single.note, 'local');
    expect(mergeVerseNotes([_note(1, 'local', jan)], [_note(1, 'remote', feb)]).single.note, 'remote');
  });

  test('doubts: local note wins, blank local note falls back to remote; earliest date kept', () {
    final withNote = mergeDoubts([_doubt(1, feb, note: 'local')], [_doubt(1, jan, note: 'remote')]);
    expect(withNote.single.note, 'local');
    expect(withNote.single.createdAt, jan);

    final blank = mergeDoubts([_doubt(1, jan, note: ' ')], [_doubt(1, feb, note: 'remote')]);
    expect(blank.single.note, 'remote');
    expect(blank.single.createdAt, jan);
  });
}
