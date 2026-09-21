import 'package:flutter/material.dart';

class DayNavigator extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final ValueChanged<int> onDayChanged;

  const DayNavigator({
    super.key,
    required this.currentDay,
    required this.totalDays,
    required this.onDayChanged,
  });

  Future<void> _jumpToDay(BuildContext context) async {
    final controller = TextEditingController(text: currentDay.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ir para o dia'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Dia (1-$totalDays)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) {
                Navigator.pop(context, value.clamp(1, totalDays));
              }
            },
            child: const Text('Ir'),
          ),
        ],
      ),
    );
    if (result != null) onDayChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentDay > 1 ? () => onDayChanged(currentDay - 1) : null,
        ),
        TextButton(
          onPressed: () => _jumpToDay(context),
          child: Text('Dia $currentDay de $totalDays', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentDay < totalDays ? () => onDayChanged(currentDay + 1) : null,
        ),
      ],
    );
  }
}
