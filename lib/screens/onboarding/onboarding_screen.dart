import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    await context.read<SettingsProvider>().setStartDate(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo.png', width: 96, height: 96),
              const SizedBox(height: 24),
              Text(
                'Bíblia em 1 ano',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Acompanhe sua leitura diária, marque os capítulos lidos, adicione notas '
                'e veja seu progresso pela Bíblia inteira. Você define o ritmo — pode '
                'terminar em menos de um ano se quiser.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text('Quando você quer começar?', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(formatted),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _start,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Começar minha leitura'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
