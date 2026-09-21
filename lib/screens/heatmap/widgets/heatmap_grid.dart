import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// GitHub-style activity grid: one column per week, 7 rows (Sun..Sat).
class HeatmapGrid extends StatelessWidget {
  final Map<String, int> countsByDate; // "yyyy-MM-dd" -> chapters read that day
  final int weeksToShow;

  const HeatmapGrid({super.key, required this.countsByDate, this.weeksToShow = 20});

  Color _colorFor(BuildContext context, int count) {
    final base = Theme.of(context).colorScheme.primary;
    if (count <= 0) return Theme.of(context).colorScheme.surfaceContainerHighest;
    final opacity = (0.25 + (count.clamp(1, 5) / 5) * 0.75).clamp(0.25, 1.0);
    return base.withValues(alpha: opacity);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    // Align the grid to end on the Saturday of the current week.
    final endOfWeek = todayDateOnly.add(Duration(days: 6 - todayDateOnly.weekday % 7));
    final totalDays = weeksToShow * 7;
    final start = endOfWeek.subtract(Duration(days: totalDays - 1));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final displayFormat = DateFormat('dd/MM/yyyy');

    final weeks = <List<DateTime>>[];
    for (var w = 0; w < weeksToShow; w++) {
      weeks.add(List.generate(7, (d) => start.add(Duration(days: w * 7 + d))));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weeks.map((week) {
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(
                children: week.map((date) {
                  final key = dateFormat.format(date);
                  final count = countsByDate[key] ?? 0;
                  final isFuture = date.isAfter(todayDateOnly);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Tooltip(
                      message: '${displayFormat.format(date)}: $count capítulo(s)',
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isFuture ? Colors.transparent : _colorFor(context, count),
                          borderRadius: BorderRadius.circular(3),
                          border: isFuture
                              ? Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)
                              : null,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
