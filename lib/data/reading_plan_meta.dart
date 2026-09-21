import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models/book.dart';
import 'models/chapter.dart';

/// In-memory metadata about the static plan (books + the day->chapters map),
/// loaded once from assets/reading_plan.json. Used for schedule math and for
/// looking up plan-day chapter lists without hitting the DB.
class ReadingPlanMeta {
  final List<Book> books;
  final List<PlanDay> planDays;
  final List<int> cumulativeByDay; // length planDays.length + 1, [0] == 0

  ReadingPlanMeta({required this.books, required this.planDays})
      : cumulativeByDay = _buildCumulative(planDays);

  int get totalPlanDays => planDays.length;
  int get totalChapters => cumulativeByDay.last;

  static List<int> _buildCumulative(List<PlanDay> days) {
    final result = List<int>.filled(days.length + 1, 0);
    for (var i = 0; i < days.length; i++) {
      result[i + 1] = result[i] + days[i].chapterIds.length;
    }
    return result;
  }

  static Future<ReadingPlanMeta> load() async {
    final raw = await rootBundle.loadString('assets/reading_plan.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final books =
        (json['books'] as List).cast<Map<String, dynamic>>().map(Book.fromJson).toList();
    final planDays =
        (json['plan'] as List).cast<Map<String, dynamic>>().map(PlanDay.fromJson).toList();
    return ReadingPlanMeta(books: books, planDays: planDays);
  }
}
