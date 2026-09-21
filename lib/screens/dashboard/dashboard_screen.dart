import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/streak_calculator.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import 'widgets/progress_ring.dart';
import 'widgets/schedule_status_card.dart';
import 'widgets/streak_badge.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    final settings = context.watch<SettingsProvider>();
    final progress = plan.overallProgress;
    final startDate = settings.startDate ?? DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ProgressRing(
            fraction: progress.fraction,
            readCount: progress.readCount,
            totalCount: progress.totalCount,
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<StreakResult>(
          key: ValueKey(progress.readCount),
          future: plan.computeStreak(),
          builder: (context, snapshot) {
            final streak = snapshot.data;
            return StreakBadge(current: streak?.currentStreak ?? 0, best: streak?.bestStreak ?? 0);
          },
        ),
        const SizedBox(height: 16),
        ScheduleStatusCard(
          status: plan.computeScheduleStatus(startDate: startDate, today: DateTime.now()),
        ),
      ],
    );
  }
}
