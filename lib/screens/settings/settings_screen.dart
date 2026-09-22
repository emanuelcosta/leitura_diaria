import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/bible_text_repository.dart';
import '../../services/push_notification_service.dart';
import '../../services/translation_service.dart';
import '../../state/auth_provider.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';

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
    PushNotificationService pushNotifications,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await pushNotifications.requestPermission();
      if (!granted) return;
      await settings.setReminder(enabled: true);
      await pushNotifications.enableDailyReminder(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      );
    } else {
      await settings.setReminder(enabled: false);
      await pushNotifications.disableDailyReminder();
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    SettingsProvider settings,
    PushNotificationService pushNotifications,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked != null) {
      await settings.setReminder(enabled: settings.reminderEnabled, hour: picked.hour, minute: picked.minute);
      if (settings.reminderEnabled) {
        await pushNotifications.enableDailyReminder(hour: picked.hour, minute: picked.minute);
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
    final auth = context.watch<AuthProvider>();
    final pushNotifications = context.read<PushNotificationService>();
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
          const SectionHeader(title: 'Leitura'),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Data de início'),
            subtitle: Text(formattedDate),
            onTap: () => _editStartDate(context, settings),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Tradução da Bíblia'),
            subtitle: Text('${settings.translation.abbreviation} — ${settings.translation.label}'),
            trailing: DropdownButton<BibleTranslation>(
              value: settings.translation,
              underline: const SizedBox.shrink(),
              items: BibleTranslation.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.abbreviation)))
                  .toList(),
              onChanged: (t) {
                if (t != null) settings.setTranslation(t);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Tema'),
            subtitle: Text(switch (settings.themeMode) {
              ThemeMode.system => 'Automático (segue o sistema)',
              ThemeMode.light => 'Claro',
              ThemeMode.dark => 'Escuro',
            }),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Automático')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
              ],
              onChanged: (mode) {
                if (mode != null) settings.setThemeMode(mode);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Idioma de tradução'),
            subtitle: Text('Usado no botão "Traduzir" (ex: dicionário) — hoje: ${settings.translationLanguage.label}'),
            trailing: DropdownButton<TranslationLanguage>(
              value: settings.translationLanguage,
              underline: const SizedBox.shrink(),
              items: TranslationLanguage.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (l) {
                if (l != null) settings.setTranslationLanguage(l);
              },
            ),
          ),
          const SectionHeader(title: 'Notificações'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Lembrete diário'),
            subtitle: Text(
              !auth.isSignedIn
                  ? 'Entre na sua conta para ativar o lembrete diário'
                  : settings.reminderEnabled
                      ? 'Ativado às $formattedTime'
                      : 'Desativado',
            ),
            value: settings.reminderEnabled,
            onChanged: auth.isSignedIn
                ? (v) => _toggleReminder(context, settings, pushNotifications, v)
                : null,
          ),
          if (auth.isSignedIn && settings.reminderEnabled)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Horário do lembrete'),
              subtitle: Text(formattedTime),
              onTap: () => _pickTime(context, settings, pushNotifications),
            ),
          const SectionHeader(title: 'Zona de risco'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Resetar progresso', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Desmarca todos os capítulos lidos e apaga suas notas. Não pode ser desfeito.'),
            onTap: () => _resetProgress(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
