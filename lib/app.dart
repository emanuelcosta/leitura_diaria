import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'state/reading_plan_provider.dart';
import 'state/settings_provider.dart';

class LeituraDiariaApp extends StatelessWidget {
  const LeituraDiariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitura Diária',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6E52)),
        useMaterial3: true,
      ),
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final plan = context.watch<ReadingPlanProvider>();

    if (!settings.loaded || !plan.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!settings.hasStarted) {
      return const OnboardingScreen();
    }

    return const HomeShell();
  }
}
