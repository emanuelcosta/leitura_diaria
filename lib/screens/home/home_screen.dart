import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/queries.dart';
import '../../logic/streak_calculator.dart';
import '../../state/bookmark_provider.dart';
import '../../state/doubts_provider.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/chapter_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../heatmap/heatmap_screen.dart';
import '../heatmap/widgets/heatmap_grid.dart';
import 'widgets/continue_reading_card.dart';
import 'widgets/day_navigator.dart';
import 'widgets/doubts_summary_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/schedule_status_card.dart';
import 'widgets/streak_badge.dart';

/// The app's home tab: today's reading (day navigator + chapter list) with
/// progress/motivation below it. Merges what used to be two separate tabs
/// (Hoje, Painel) into one hub — checking progress and reading today's
/// chapters happen on the same daily visit, so splitting them made the user
/// pick a tab before knowing which one had what they needed.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final plan = context.watch<ReadingPlanProvider>();
    final doubts = context.watch<DoubtsProvider>();
    final bookmark = context.watch<BookmarkProvider>().bookmark;
    final startDate = settings.startDate ?? DateTime.now();
    final idealDay = plan.idealPlanDayFor(startDate, DateTime.now());
    final day = _selectedDay ?? idealDay;
    final progress = plan.overallProgress;

    return FutureBuilder<List<ChapterView>>(
      key: ValueKey('${day}_${progress.readCount}'),
      future: plan.getChaptersForPlanDay(day),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chapters = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (bookmark != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ContinueReadingCard(bookmark: bookmark),
              ),
            if (doubts.count > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DoubtsSummaryCard(count: doubts.count),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DayNavigator(
                currentDay: day,
                totalDays: plan.meta.totalPlanDays,
                onDayChanged: (d) => setState(() => _selectedDay = d),
              ),
            ),
            if (day != idealDay)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _selectedDay = null),
                  child: Text('Voltar para hoje (dia $idealDay)'),
                ),
              ),
            const Divider(height: 17),
            if (chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'Nenhum capítulo novo neste dia do plano.',
                ),
              )
            else
              ...chapters.map((c) => ChapterCard(view: c)),
            const Divider(height: 33),
            const SectionHeader(title: 'Seu progresso'),
            const SizedBox(height: 16),
            Center(
              child: ProgressRing(
                fraction: progress.fraction,
                readCount: progress.readCount,
                totalCount: progress.totalCount,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<StreakResult>(
                key: ValueKey(progress.readCount),
                future: plan.computeStreak(),
                builder: (context, snapshot) {
                  final streak = snapshot.data;
                  return StreakBadge(current: streak?.currentStreak ?? 0, best: streak?.bestStreak ?? 0);
                },
              ),
            ),
            SectionHeader(
              title: 'Constância',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HeatmapScreen()),
                ),
                child: const Text('Ver tudo'),
              ),
            ),
            FutureBuilder<Map<String, int>>(
              key: ValueKey(progress.readCount),
              future: plan.getReadCountsByDate(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                }
                return HeatmapGrid(countsByDate: snapshot.data!, weeksToShow: 8);
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: progress.totalCount > 0 && progress.readCount >= progress.totalCount
                  // Only the completed state needs lastReadAt (for "Concluído
                  // em DD/MM/AAAA"), so only fetch it once the plan is
                  // actually done — no point querying MAX(read_at) on every
                  // build.
                  ? FutureBuilder<DateTime?>(
                      future: plan.getLastReadAt(),
                      builder: (context, snapshot) => ScheduleStatusCard(
                        status: plan.computeScheduleStatus(
                          startDate: startDate,
                          today: DateTime.now(),
                          lastReadAt: snapshot.data,
                        ),
                      ),
                    )
                  : ScheduleStatusCard(
                      status: plan.computeScheduleStatus(startDate: startDate, today: DateTime.now()),
                    ),
            ),
          ],
        );
      },
    );
  }
}
