/// Pure schedule math: no Flutter/DB imports, so it's trivially unit-testable.
/// Full write-up with worked examples: docs/schedule-calculation.md.
///
/// The plan has [totalPlanDays] days and [totalChapters] chapters overall.
/// [planCumulative] must have length totalPlanDays + 1, where planCumulative[d]
/// is the number of distinct chapters introduced by days 1..d (planCumulative[0] == 0).
class ScheduleStatus {
  final int idealPlanDay;
  final int achievedPlanDay;
  final int daysAheadBehind; // positive = ahead, negative = behind, 0 = on schedule
  final bool completed;
  final DateTime? projectedFinishDate;
  final DateTime? completionDate;
  final int remainingUnits;
  final int requiredUnitsPerDay;
  final int targetDurationDays;
  /// Median chapters read on an active day, which is resistant to bulk
  /// marking on an unusually productive day.
  final double? historicalChaptersPerDay;
  final DateTime? historicalProjectedFinishDate;
  final double? calendarChaptersPerDay;
  final DateTime? calendarProjectedFinishDate;

  const ScheduleStatus({
    required this.idealPlanDay,
    required this.achievedPlanDay,
    required this.daysAheadBehind,
    required this.completed,
    this.projectedFinishDate,
    this.completionDate,
    this.remainingUnits = 0,
    this.requiredUnitsPerDay = 0,
    this.targetDurationDays = 365,
    this.historicalChaptersPerDay,
    this.historicalProjectedFinishDate,
    this.calendarChaptersPerDay,
    this.calendarProjectedFinishDate,
  });
}

class ScheduleCalculator {
  final List<int> planCumulative; // index 0..totalPlanDays
  final int totalPlanDays;
  final int totalChapters;

  ScheduleCalculator({
    required this.planCumulative,
    required this.totalPlanDays,
  }) : totalChapters = planCumulative.last {
    assert(planCumulative.length == totalPlanDays + 1);
    assert(planCumulative.first == 0);
  }

  int _clamp(int value, int min, int max) => value < min ? min : (value > max ? max : value);

  /// [today] and [startDate] should be date-only (time-of-day ignored by caller).
  ScheduleStatus computeStatus({
    required DateTime startDate,
    required DateTime today,
    required int actualReadCount,
    DateTime? lastReadAt,
    int targetDurationDays = 365,
    int? historicalReadCount,
    int? historicalTotalCount,
    int? activeReadingDays,
    List<int>? historicalDailyCounts,
  }) {
    if (targetDurationDays < 1) {
      throw ArgumentError.value(targetDurationDays, 'targetDurationDays', 'must be positive');
    }
    final daysSinceStart = today.difference(startDate).inDays;
    final idealDayLimit = targetDurationDays == 365 ? totalPlanDays : targetDurationDays;
    final idealPlanDay = _clamp(daysSinceStart + 1, 1, idealDayLimit);

    if (actualReadCount >= totalChapters) {
      return ScheduleStatus(
        idealPlanDay: idealPlanDay,
        achievedPlanDay: totalPlanDays,
        daysAheadBehind: 0,
        completed: true,
        completionDate: lastReadAt,
        targetDurationDays: targetDurationDays,
      );
    }

    // planCumulative is monotonic and planCumulative[totalPlanDays] == totalChapters,
    // which is strictly greater than actualReadCount here (the >= totalChapters case
    // already returned above), so this always finds a match without falling through.
    var achievedPlanDay = totalPlanDays;
    for (var d = 0; d <= totalPlanDays; d++) {
      if (planCumulative[d] >= actualReadCount) {
        achievedPlanDay = d;
        break;
      }
    }

    final daysAheadBehind = achievedPlanDay - idealPlanDay;

    final remaining = totalChapters - actualReadCount;
    final historicalCount = historicalReadCount ?? actualReadCount;
    final historicalTotal = historicalTotalCount ?? totalChapters;
    final elapsedDays = daysSinceStart + 1;
    final activeDays = activeReadingDays ?? elapsedDays;
    final historicalAverage = historicalDailyCounts != null && historicalDailyCounts.isNotEmpty
        ? _median(historicalDailyCounts)
        : activeDays > 0 && historicalCount > 0
            ? historicalCount / activeDays
            : null;
    final calendarAverage = elapsedDays > 0 && historicalCount > 0 ? historicalCount / elapsedDays : null;
    final historicalRemaining = historicalTotal - historicalCount;
    final historicalDaysRemaining = historicalAverage != null && historicalRemaining > 0
        ? (historicalRemaining / historicalAverage).ceil()
        : null;
    final targetDate = startDate.add(Duration(days: targetDurationDays - 1));
    final daysUntilTarget = targetDate.difference(today).inDays + 1;
    final daysAvailable = daysUntilTarget > 0 ? daysUntilTarget : 1;
    final requiredUnitsPerDay = (remaining / daysAvailable).ceil();
    final daysRemaining = remaining == 0 ? 0 : (remaining / requiredUnitsPerDay).ceil();
    final projectedFinish = today.add(Duration(days: daysRemaining));
    final calendarDaysRemaining = calendarAverage != null && historicalRemaining > 0
        ? (historicalRemaining / calendarAverage).ceil()
        : null;

    return ScheduleStatus(
      idealPlanDay: idealPlanDay,
      achievedPlanDay: achievedPlanDay,
      daysAheadBehind: daysAheadBehind,
      completed: false,
      projectedFinishDate: projectedFinish,
      remainingUnits: remaining,
      requiredUnitsPerDay: requiredUnitsPerDay,
      targetDurationDays: targetDurationDays,
      historicalChaptersPerDay: historicalAverage,
      historicalProjectedFinishDate: historicalDaysRemaining == null
          ? null
          : today.add(Duration(days: historicalDaysRemaining)),
      calendarChaptersPerDay: calendarAverage,
      calendarProjectedFinishDate: calendarDaysRemaining == null
          ? null
          : today.add(Duration(days: calendarDaysRemaining)),
    );
  }

  double _median(List<int> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle].toDouble();
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
