import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/notification_service.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/confirm_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editStartDate(BuildContext context, SettingsProvider settings) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: settings.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      await settings.setStartDate(picked);
    }
  }

  Future<void> _toggleReminder(
    BuildContext context,
    SettingsProvider settings,
    NotificationService notifications,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await notifications.requestPermission();
      if (!granted) return;
      await settings.setReminder(enabled: true);
      await notifications.scheduleDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );
    } else {
      await settings.setReminder(enabled: false);
      await notifications.cancelDailyReminder();
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsProvider settings,
    NotificationService notifications,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked != null) {
      await settings.setReminder(enabled: settings.reminderEnabled, hour: picked.hour, minute: picked.minute);
      if (settings.reminderEnabled) {
        await notifications.scheduleDailyReminder(hour: picked.hour, minute: picked.minute);
      }
    }
  }

  Future<void> _resetProgress(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Resetar progresso',
      message: 'Isso vai desmarcar todos os capítulos lidos e apagar suas notas. '
          'Essa ação não pode ser desfeita. Deseja continuar?',
      confirmLabel: 'Resetar',
      destructive: true,
    );
    if (confirmed && context.mounted) {
      await context.read<ReadingPlanProvider>().resetAllProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progresso resetado.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final notifications = context.read<NotificationService>();
    final startDate = settings.startDate;
    final formattedDate = startDate == null
        ? '-'
        : '${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year}';
    final formattedTime =
        '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Data de início'),
            subtitle: Text(formattedDate),
            onTap: () => _editStartDate(context, settings),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Lembrete diário'),
            subtitle: Text(settings.reminderEnabled ? 'Ativado às $formattedTime' : 'Desativado'),
            value: settings.reminderEnabled,
            onChanged: (v) => _toggleReminder(context, settings, notifications, v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Horário do lembrete'),
              subtitle: Text(formattedTime),
              onTap: () => _pickTime(context, settings, notifications),
            ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Resetar progresso', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _resetProgress(context),
          ),
        ],
      ),
    );
  }
}
