import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/bible_text_repository.dart';
import '../../services/notification_service.dart';
import '../../services/translation_service.dart';
import '../../state/auth_provider.dart';
import '../../state/reading_plan_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/auth_dialog.dart';

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

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta',
      message: 'Seu progresso continua salvo neste aparelho. Você pode entrar novamente '
          'a qualquer momento para voltar a sincronizar.',
      confirmLabel: 'Sair',
    );
    if (confirmed && context.mounted) {
      await context.read<AuthProvider>().signOut();
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
          const _SectionHeader('Conta'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Conta'),
            subtitle: Text(
              auth.isSignedIn
                  ? 'Sincronizado como ${auth.user!.email}'
                  : 'Entrar para sincronizar entre aparelhos',
            ),
            trailing: auth.isSignedIn
                ? TextButton(onPressed: () => _signOut(context), child: const Text('Sair'))
                : null,
            onTap: auth.isSignedIn ? null : () => showAuthDialog(context),
          ),
          const _SectionHeader('Leitura'),
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
          const _SectionHeader('Notificações'),
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
          const _SectionHeader('Zona de risco'),
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

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
