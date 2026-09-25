import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double fraction; // 0..1
  final int readCount;
  final int totalCount;
  final String unit; // e.g. "capítulos", "versículos"

  const ProgressRing({
    super.key,
    required this.fraction,
    required this.readCount,
    required this.totalCount,
    this.unit = 'capítulos',
  });

  @override
  Widget build(BuildContext context) {
    final percent = (fraction * 100).clamp(0, 100).toStringAsFixed(1);
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: fraction.clamp(0, 1),
              strokeWidth: 14,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$readCount / $totalCount $unit', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
