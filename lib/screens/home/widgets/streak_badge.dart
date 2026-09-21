import 'package:flutter/material.dart';

class StreakBadge extends StatelessWidget {
  final int current;
  final int best;

  const StreakBadge({super.key, required this.current, required this.best});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StreakTile(icon: Icons.local_fire_department, label: 'Sequência atual', value: current)),
        const SizedBox(width: 12),
        Expanded(child: _StreakTile(icon: Icons.emoji_events_outlined, label: 'Recorde', value: best)),
      ],
    );
  }
}

class _StreakTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _StreakTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text('$value ${value == 1 ? 'dia' : 'dias'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
