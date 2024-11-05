import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart'; // Importa el paquete
import 'package:pharma_salud/screens/login_screen.dart';

void main() {
  // Inicializa el control de la ventana
  WidgetsFlutterBinding.ensureInitialized();
  
  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = const Size(800, 500); // Establece el tamaño mínimo
    win.maximize(); // Maximiza la ventana automáticamente
    win.title = "Sistema de Farmacia"; // Establece el título de la ventana
    win.show(); // Muestra la ventana
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Farmacia',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[200], // Cambia el color de fondo
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
      },
    );
  }
}
