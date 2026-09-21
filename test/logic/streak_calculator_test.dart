import 'package:flutter_test/flutter_test.dart';
import 'package:leitura_diaria/logic/streak_calculator.dart';

void main() {
  test('empty dates -> zero streaks', () {
    final result = StreakCalculator.compute([]);
    expect(result.currentStreak, 0);
    expect(result.bestStreak, 0);
  });

  test('single day read today -> current and best streak of 1', () {
    final today = DateTime(2026, 1, 10);
    final result = StreakCalculator.compute([today], today: today);
    expect(result.currentStreak, 1);
    expect(result.bestStreak, 1);
  });

  test('consecutive run ending today', () {
    final today = DateTime(2026, 1, 10);
    final dates = [
      DateTime(2026, 1, 7),
      DateTime(2026, 1, 8),
      DateTime(2026, 1, 9),
      DateTime(2026, 1, 10),
    ];
    final result = StreakCalculator.compute(dates, today: today);
    expect(result.currentStreak, 4);
    expect(result.bestStreak, 4);
  });

  test('last read was yesterday -> streak still counts (not broken yet)', () {
    final today = DateTime(2026, 1, 10);
    final dates = [DateTime(2026, 1, 8), DateTime(2026, 1, 9)];
    final result = StreakCalculator.compute(dates, today: today);
    expect(result.currentStreak, 2);
  });

  test('last read was 2+ days ago -> current streak is broken (zero)', () {
    final today = DateTime(2026, 1, 10);
    final dates = [DateTime(2026, 1, 5), DateTime(2026, 1, 6), DateTime(2026, 1, 7)];
    final result = StreakCalculator.compute(dates, today: today);
    expect(result.currentStreak, 0);
    expect(result.bestStreak, 3);
  });

  test('gapped history keeps best streak even after it breaks', () {
    final today = DateTime(2026, 1, 20);
    final dates = [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 4),
      DateTime(2026, 1, 5), // run of 5
      DateTime(2026, 1, 10),
      DateTime(2026, 1, 11), // run of 2
    ];
    final result = StreakCalculator.compute(dates, today: today);
    expect(result.bestStreak, 5);
    expect(result.currentStreak, 0);
  });

  test('duplicate/out-of-order dates are handled', () {
    final today = DateTime(2026, 1, 3);
    final dates = [
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 2), // duplicate
    ];
    final result = StreakCalculator.compute(dates, today: today);
    expect(result.currentStreak, 3);
    expect(result.bestStreak, 3);
  });
}
