import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cerebro/timer_service.dart';
import 'datos/app_database.dart';
import 'datos/legacy_migration.dart';
import 'datos/sync_service.dart';
import 'providers/theme_provider.dart';
import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  await themeProvider.initTheme();

  // Base local primero: todo lo demás (chat, tareas, timers) vive ahí.
  final database = await AppDatabase.initialize();
  await LegacyMigration.run(database);

  // Retoma los temporizadores guardados y acredita los que terminaron con la app cerrada.
  await TimerService.shared.load();

  // Sincroniza con Supabase en segundo plano; sin red simplemente queda pendiente.
  SyncService.shared.start();
  SyncService.shared.remoteChanges.listen((tables) {
    if (tables.contains('timers')) TimerService.shared.load();
  });

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Mai - Asistente IA',
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const ChatScreen(),
          );
        },
      ),
    );
  }
}
