import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'pantalla/chat_screen.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno ANTES de iniciar la app
  try {
    await dotenv.load(fileName: ".env");
    print('✅ DEBUG: Archivo .env encontrado y cargado.');
  } catch (e) {
    print('❌ DEBUG ERROR: No se pudo cargar el archivo .env.');
    print(e.toString());
  }

  // Inicializar el tema
  final themeProvider = ThemeProvider();
  await themeProvider.initTheme();

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