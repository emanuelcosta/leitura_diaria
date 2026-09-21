import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/queries.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/empty_state.dart';
import 'widgets/chapter_card.dart';
import 'widgets/day_navigator.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final plan = context.watch<ReadingPlanProvider>();
    final startDate = settings.startDate ?? DateTime.now();
    final idealDay = plan.idealPlanDayFor(startDate, DateTime.now());
    final day = _selectedDay ?? idealDay;

    return Column(
      children: [
        const SizedBox(height: 8),
        DayNavigator(
          currentDay: day,
          totalDays: plan.meta.totalPlanDays,
          onDayChanged: (d) => setState(() => _selectedDay = d),
        ),
        if (day != idealDay)
          TextButton(
            onPressed: () => setState(() => _selectedDay = null),
            child: Text('Voltar para hoje (dia $idealDay)'),
          ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<ChapterView>>(
            key: ValueKey('${day}_${plan.overallProgress.readCount}'),
            future: plan.getChaptersForPlanDay(day),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final chapters = snapshot.data!;
              if (chapters.isEmpty) {
                return const EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'Nenhum capítulo novo neste dia do plano.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
                itemBuilder: (context, i) => ChapterCard(view: chapters[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
