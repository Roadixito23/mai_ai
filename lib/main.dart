import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pantalla/chat_screen.dart';

Future<void> main() async {
  // Cargar variables de entorno ANTES de iniciar la app
  try {
    await dotenv.load(fileName: ".env");
    print('✅ DEBUG: Archivo .env encontrado y cargado.');
  } catch (e) {
    print('❌ DEBUG ERROR: No se pudo cargar el archivo .env.');
    print(e.toString());
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mai - Asistente IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}