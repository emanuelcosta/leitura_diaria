import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/progress_mode.dart';
import '../../../data/repositories/chapter_repository.dart';
import '../../../state/reading_plan_provider.dart';
import '../../../state/settings_provider.dart';
import 'progress_ring.dart';

/// Capítulos/Versículos selector + the progress ring. The chosen mode is a
/// saved setting (SettingsProvider), so it sticks across app restarts.
/// Chapter progress is already in memory; verse progress needs the Bible
/// text's verse counts, so it's only computed while that mode is shown.
class ProgressSection extends StatelessWidget {
  final OverallProgress chapterProgress;

  const ProgressSection({super.key, required this.chapterProgress});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final mode = settings.progressMode;

    return Column(
      children: [
        SegmentedButton<ProgressMode>(
          segments: [
            for (final m in ProgressMode.values) ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => settings.setProgressMode(selection.first),
        ),
        const SizedBox(height: 16),
        switch (mode) {
          ProgressMode.chapters => _ring(chapterProgress, mode),
          ProgressMode.verses => FutureBuilder<OverallProgress>(
              // Recompute when a chapter is (un)marked or the translation
              // changes (verse counts differ slightly between them).
              key: ValueKey('${chapterProgress.readCount}_${settings.translation.name}'),
              future: context.read<ReadingPlanProvider>().getVerseProgress(settings.translation),
              builder: (context, snapshot) {
                final progress = snapshot.data;
                if (progress == null) {
                  return const SizedBox.square(
                    dimension: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _ring(progress, mode);
              },
            ),
        },
      ],
    );
  }

  Widget _ring(OverallProgress progress, ProgressMode mode) => ProgressRing(
        fraction: progress.fraction,
        readCount: progress.readCount,
        totalCount: progress.totalCount,
        unit: mode.unit,
      );
}
