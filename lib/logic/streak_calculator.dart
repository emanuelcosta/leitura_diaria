class StreakResult {
  final int currentStreak;
  final int bestStreak;

  const StreakResult({required this.currentStreak, required this.bestStreak});
}

class StreakCalculator {
  /// [readDates] must be distinct calendar dates (time-of-day ignored), any order.
  static StreakResult compute(List<DateTime> readDates, {DateTime? today}) {
    if (readDates.isEmpty) {
      return const StreakResult(currentStreak: 0, bestStreak: 0);
    }

    final dates = readDates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
      ..sort();

    var bestStreak = 1;
    var runLength = 1;
    for (var i = 1; i < dates.length; i++) {
      final gap = dates[i].difference(dates[i - 1]).inDays;
      if (gap == 1) {
        runLength += 1;
      } else {
        runLength = 1;
      }
      if (runLength > bestStreak) bestStreak = runLength;
    }

    final todayDate = () {
      final t = today ?? DateTime.now();
      return DateTime(t.year, t.month, t.day);
    }();
    final lastDate = dates.last;
    final gapFromToday = todayDate.difference(lastDate).inDays;

    var currentStreak = 0;
    if (gapFromToday == 0 || gapFromToday == 1) {
      // Walk backwards from the last read date counting the consecutive run.
      currentStreak = 1;
      for (var i = dates.length - 1; i > 0; i--) {
        final gap = dates[i].difference(dates[i - 1]).inDays;
        if (gap == 1) {
          currentStreak += 1;
        } else {
          break;
        }
      }
    }

    return StreakResult(currentStreak: currentStreak, bestStreak: bestStreak);
  }
}
