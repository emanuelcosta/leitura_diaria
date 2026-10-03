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

  test('projected finish date follows the configured target', () {
    // 12 chapters in 12 days: with 6 days left, 10 remaining means 2/day.
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 7),
      actualReadCount: 2,
      targetDurationDays: 12,
    );
    expect(status.requiredUnitsPerDay, 2);
    expect(status.remainingUnits, 10);
    expect(status.projectedFinishDate, DateTime(2026, 1, 12));
  });

  test('projection is available before any reading', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 1),
      actualReadCount: 0,
    );
    expect(status.requiredUnitsPerDay, 1);
    expect(status.projectedFinishDate, DateTime(2026, 1, 13));
  });

  test('target shorter than remaining time increases the daily target', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 1),
      actualReadCount: 2,
      targetDurationDays: 5,
    );
    expect(status.requiredUnitsPerDay, 2);
    expect(status.projectedFinishDate, DateTime(2026, 1, 6));
  });

  test('calculates a second projection from the historical chapter pace', () {
    final status = calc.computeStatus(
      startDate: start,
      today: DateTime(2026, 1, 5),
      actualReadCount: 5,
      targetDurationDays: 12,
      activeReadingDays: 2,
      historicalDailyCounts: [8, 1, 1, 1],
    );
    expect(status.historicalChaptersPerDay, 1);
    expect(status.historicalProjectedFinishDate, DateTime(2026, 1, 12));
    expect(status.calendarChaptersPerDay, 1);
    expect(status.calendarProjectedFinishDate, DateTime(2026, 1, 12));
  });
}
