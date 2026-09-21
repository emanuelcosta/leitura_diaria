/// Pure schedule math: no Flutter/DB imports, so it's trivially unit-testable.
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

  const ScheduleStatus({
    required this.idealPlanDay,
    required this.achievedPlanDay,
    required this.daysAheadBehind,
    required this.completed,
    this.projectedFinishDate,
    this.completionDate,
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
  }) {
    final daysSinceStart = today.difference(startDate).inDays;
    final idealPlanDay = _clamp(daysSinceStart + 1, 1, totalPlanDays);

    if (actualReadCount >= totalChapters) {
      return ScheduleStatus(
        idealPlanDay: idealPlanDay,
        achievedPlanDay: totalPlanDays,
        daysAheadBehind: 0,
        completed: true,
        completionDate: lastReadAt,
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

    DateTime? projectedFinish;
    final daysElapsed = daysSinceStart + 1;
    if (daysElapsed > 0 && actualReadCount > 0) {
      final avgPerDay = actualReadCount / daysElapsed;
      final remaining = totalChapters - actualReadCount;
      final daysRemaining = (remaining / avgPerDay).ceil();
      projectedFinish = today.add(Duration(days: daysRemaining));
    }

    return ScheduleStatus(
      idealPlanDay: idealPlanDay,
      achievedPlanDay: achievedPlanDay,
      daysAheadBehind: daysAheadBehind,
      completed: false,
      projectedFinishDate: projectedFinish,
    );
  }
}
