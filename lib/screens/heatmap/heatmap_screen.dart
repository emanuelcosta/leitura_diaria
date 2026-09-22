import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/reading_plan_provider.dart';
import 'widgets/heatmap_grid.dart';

/// Full reading-consistency calendar (20 weeks) — reached from the compact
/// preview on the Início tab ("Ver tudo"), not a bottom-nav destination of
/// its own since it's checked occasionally, not on every visit.
class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Constância de leitura')),
      body: ListView(
        children: [
          FutureBuilder<Map<String, int>>(
            key: ValueKey(plan.overallProgress.readCount),
            future: plan.getReadCountsByDate(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return HeatmapGrid(countsByDate: snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}
