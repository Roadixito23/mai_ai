import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cerebro/timer_service.dart';
import 'datos/app_database.dart';
import 'datos/auth_service.dart';
import 'datos/legacy_migration.dart';
import 'datos/sync_service.dart';
import 'providers/theme_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'sistema/lanzador.dart';
import 'sistema/presencia_escritorio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  await themeProvider.initTheme();

  // Base local primero: todo lo demás (chat, tareas, timers) vive ahí.
  final database = await AppDatabase.initialize();
  await LegacyMigration.run(database);

  // Retoma los temporizadores guardados y acredita los que terminaron con la app cerrada.
  await TimerService.shared.load();

  // Recupera la sesión guardada (no necesita red). Sin env.json, modo local.
  await AuthService.shared.init();

  // Sincroniza con Supabase en segundo plano; sin red simplemente queda pendiente.
  SyncService.shared.start();
  var wasSignedIn = AuthService.shared.isSignedIn;
  AuthService.shared.addListener(() {
    final signedIn = AuthService.shared.isSignedIn;
    if (signedIn && !wasSignedIn) SyncService.shared.sync(); // recién inició sesión
    wasSignedIn = signedIn;
  });
  SyncService.shared.remoteChanges.listen((tables) {
    if (tables.contains('timers')) TimerService.shared.load();
  });

  // Presencia en el sistema: bandeja y atajo global en escritorio; tile de
  // ajustes rápidos y Compartir en Android.
  await PresenciaEscritorio.shared.init();
  await Lanzador.shared.initAndroid();

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
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// Con Supabase configurado, pide iniciar sesión hasta que haya una; sin
/// configurar, entra directo en modo local.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthService.configured) return const ChatScreen();
    return ListenableBuilder(
      listenable: AuthService.shared,
      builder: (context, _) =>
          AuthService.shared.isSignedIn ? const ChatScreen() : const LoginScreen(),
    );
  }
}
