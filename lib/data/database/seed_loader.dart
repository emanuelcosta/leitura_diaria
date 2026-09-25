import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../models/book.dart';
import '../models/chapter.dart';

/// Parses assets/reading_plan.json and bulk-inserts books + chapters into an
/// empty database inside a single transaction. Guarded by
/// SettingsRepository.hasSeeded plus BookRepository.hasBooks — only runs
/// again if the books table turns out empty (inserts use replace, so a
/// re-run can't duplicate rows).
class SeedLoader {
  static Future<void> seed(Database db) async {
    final raw = await rootBundle.loadString('assets/reading_plan.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final books = (json['books'] as List)
        .cast<Map<String, dynamic>>()
        .map(Book.fromJson)
        .toList();
    final planDays = (json['plan'] as List)
        .cast<Map<String, dynamic>>()
        .map(PlanDay.fromJson)
        .toList();

    final chapterNumberById = <String, int>{};
    final bookIdById = <String, String>{};
    for (final book in books) {
      for (var n = 1; n <= book.chapterCount; n++) {
        final id = '${book.id}-$n';
        chapterNumberById[id] = n;
        bookIdById[id] = book.id;
      }
    }

    await db.transaction((txn) async {
      final booksBatch = txn.batch();
      for (final book in books) {
        booksBatch.insert(
          'books',
          book.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await booksBatch.commit(noResult: true);

      final chaptersBatch = txn.batch();
      for (final planDay in planDays) {
        for (final chapterId in planDay.chapterIds) {
          final chapter = Chapter(
            id: chapterId,
            bookId: bookIdById[chapterId]!,
            chapterNumber: chapterNumberById[chapterId]!,
            planDay: planDay.day,
            isRead: false,
          );
          chaptersBatch.insert(
            'chapters',
            chapter.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await chaptersBatch.commit(noResult: true);
    });
  }
}
