import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_salud/screens/Login/login.dart';

Future<void> _migrarArchivosAntiguos() async {
  try {
    final docsDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();

    final viejaCarpeta = Directory('${docsDir.path}/PharmaSalud/tickets');
    if (!await viejaCarpeta.exists()) return;

    final nuevaCarpeta = Directory('${supportDir.path}/PharmaSalud/tickets');
    await nuevaCarpeta.create(recursive: true);

    final archivos = await viejaCarpeta.list().toList();
    for (final archivo in archivos) {
      if (archivo is File) {
        final destino =
            File('${nuevaCarpeta.path}/${archivo.uri.pathSegments.last}');
        await archivo.copy(destino.path);
      }
    }

    await viejaCarpeta.delete(recursive: true);
    debugPrint('Migración completada: ${archivos.length} archivos movidos');
  } catch (e) {
    debugPrint('Error en migración (no crítico): $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _migrarArchivosAntiguos();
  await initializeDateFormatting('es_ES', null);

  runApp(const MyApp());

  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = const Size(800, 800);
    win.maximize();
    win.title = "Sistema de Farmacia";
    win.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Farmacia',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Outfit',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B30), // Pharma Red
          primary: const Color(0xFFFF3B30),
          surface: const Color(0xFFF5F5F7), // Apple System Gray (Light)
          onSurface: const Color(0xFF1D1D1F), // Apple Deep Charcoal
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1D1D1F),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
