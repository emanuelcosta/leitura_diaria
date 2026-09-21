import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/logic/schedule_calculator.dart';

void main() {
  // A tiny fake plan: 5 days, cumulative chapters [0,2,5,7,10,12].
  final cumulative = [0, 2, 5, 7, 10, 12];
  final calc = ScheduleCalculator(planCumulative: cumulative, totalPlanDays: 5);

  final start = DateTime(2026, 1, 1);

  test('on schedule: day 3, read exactly the expected 7 chapters', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 3), // daysSinceStart=2 -> idealPlanDay=3
      actualReadCount: 7,
    );
    expect(status.idealPlanDay, 3);
    expect(status.achievedPlanDay, 3);
    expect(status.daysAheadBehind, 0);
    expect(status.completed, false);
  });

  test('ahead of schedule: day 2 but already read 10 chapters (day-4 worth)', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 2), // idealPlanDay=2
      actualReadCount: 10,
    );
    expect(status.idealPlanDay, 2);
    expect(status.achievedPlanDay, 4);
    expect(status.daysAheadBehind, 2);
  });

  test('behind schedule: day 5 but only read 5 chapters (day-2 worth)', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 5), // idealPlanDay=5 (clamped to totalPlanDays)
      actualReadCount: 5,
    );
    expect(status.idealPlanDay, 5);
    expect(status.achievedPlanDay, 2);
    expect(status.daysAheadBehind, -3);
  });

  test('idealPlanDay clamps at totalPlanDays even far past the end', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 3, 1),
      actualReadCount: 0,
    );
    expect(status.idealPlanDay, 5);
    expect(status.achievedPlanDay, 0);
  });

  test('completed when actualReadCount reaches total chapters', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 4),
      actualReadCount: 12,
      lastReadAt: DateTime(2026, 1, 4, 20, 0),
    );
    expect(status.completed, true);
    expect(status.achievedPlanDay, 5);
    expect(status.completionDate, DateTime(2026, 1, 4, 20, 0));
  });

  test('projected finish date extrapolates from actual pace', () {
    // day 1 (idealPlanDay=1), read 2 chapters in 1 day -> avgPerDay=2, remaining=10 -> 5 more days
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 1),
      actualReadCount: 2,
    );
    expect(status.projectedFinishDate, DateTime(2026, 1, 6));
  });

  test('no projection when nothing read yet', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 1),
      actualReadCount: 0,
    );
    expect(status.projectedFinishDate, isNull);
  });
}
