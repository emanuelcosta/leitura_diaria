import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leitura_diaria/app.dart';
import 'package:leitura_diaria/data/repositories/settings_repository.dart';
import 'package:leitura_diaria/state/reading_plan_provider.dart';
import 'package:leitura_diaria/state/settings_provider.dart';

// Full navigation through HomeShell hits real (ffi) SQLite via several
// concurrent FutureBuilders (IndexedStack keeps every tab mounted), which
// doesn't play well with flutter_test's fake-async pump loop (see the plan's
// "manual device pass" step for that end-to-end coverage). This smoke test
// sticks to what fake-async can verify reliably: the app boots, seeds the
// plan (real I/O bridged via tester.runAsync), and renders onboarding first.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows onboarding for a first-time user and seeds the plan', (tester) async {
    final settings = SettingsProvider(SettingsRepository());
    final plan = ReadingPlanProvider();
    await tester.runAsync(() async {
      await settings.load();
      await plan.initialize();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: plan),
        ],
        child: const LeituraDiariaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bíblia em 1 ano'), findsOneWidget);
    expect(find.text('Começar minha leitura'), findsOneWidget);
    expect(plan.meta.totalChapters, 1189);
  });
}
