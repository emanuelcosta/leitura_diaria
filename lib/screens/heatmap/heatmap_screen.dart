import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/reading_plan_provider.dart';
import '../../widgets/section_header.dart';
import 'widgets/heatmap_grid.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<ReadingPlanProvider>();
    return ListView(
      children: [
        const SectionHeader(title: 'Constância de leitura'),
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
    );
  }
}
