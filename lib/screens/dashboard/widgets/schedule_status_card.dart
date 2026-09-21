import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../logic/schedule_calculator.dart';

class ScheduleStatusCard extends StatelessWidget {
  final ScheduleStatus status;

  const ScheduleStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (status.completed) {
      return Card(
        color: theme.colorScheme.primaryContainer,
        child: ListTile(
          leading: const Icon(Icons.celebration),
          title: const Text('Você concluiu a leitura da Bíblia!'),
          subtitle: status.completionDate != null
              ? Text('Concluído em ${dateFormat.format(status.completionDate!)}')
              : null,
        ),
      );
    }

    final ahead = status.daysAheadBehind;
    final String statusText;
    final Color color;
    final IconData icon;
    if (ahead > 0) {
      statusText = 'Você está $ahead ${ahead == 1 ? 'dia' : 'dias'} à frente do cronograma';
      color = Colors.green;
      icon = Icons.trending_up;
    } else if (ahead < 0) {
      statusText = 'Você está ${-ahead} ${-ahead == 1 ? 'dia' : 'dias'} atrás do cronograma';
      color = Colors.orange;
      icon = Icons.trending_down;
    } else {
      statusText = 'Você está em dia com o cronograma';
      color = theme.colorScheme.primary;
      icon = Icons.check_circle_outline;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(statusText, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dia ideal do plano: ${status.idealPlanDay}'),
            Text('Seu progresso equivale ao dia: ${status.achievedPlanDay}'),
            if (status.projectedFinishDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Previsão de conclusão: ${dateFormat.format(status.projectedFinishDate!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
