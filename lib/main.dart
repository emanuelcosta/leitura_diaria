import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/settings_repository.dart';
import 'services/notification_service.dart';
import 'state/reading_plan_provider.dart';
import 'state/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(SettingsRepository())..load()),
        ChangeNotifierProvider(create: (_) => ReadingPlanProvider()..initialize()),
        Provider(create: (_) => NotificationService()),
      ],
      child: const LeituraDiariaApp(),
    ),
  );
}
