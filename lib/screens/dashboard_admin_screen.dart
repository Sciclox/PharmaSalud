import 'dart:ui'; // Agrega esta importación
import 'package:flutter/material.dart';
import 'package:pharma_salud/screens/admin_registroventas.dart';
import 'package:pharma_salud/screens/dashboard_inicial_screen.dart';
import 'package:pharma_salud/screens/producto_screen.dart';
import 'package:pharma_salud/screens/usuarios_screen.dart';

// Pantalla principal del dashboard
class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  _DashboardAdminScreenState createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  Widget _currentScreen =  DashboardInicialScreen(); // Pantalla por defecto
// Título de la pantalla por defecto
  int _selectedIndex = 0; // Índice del ítem seleccionado por defecto

  void _selectScreen(int index, Widget screen, String title) {
    setState(() {
      _currentScreen = screen; // Cambiar pantalla actual
// Cambiar título de pantalla seleccionada
      _selectedIndex = index; // Actualizar índice seleccionado
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationDrawer(
            selectedIndex: _selectedIndex,
            onSelectScreen: _selectScreen,
          ),
          Expanded(
            // Pantalla actual a la derecha del Drawer
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _currentScreen,
            ),
          ),
        ],
      ),
    );
  }
}

// Sidebar Navigation (Menú)
class NavigationDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int, Widget, String) onSelectScreen;

  const NavigationDrawer({
    Key? key,
    required this.selectedIndex,
    required this.onSelectScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // Sin radio
      ),
      child: Stack(
        children: [
          // Fondo acrílico
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // Ajusta el desenfoque según necesites
              child: Container(
                color: Colors.black.withOpacity(0.5), // Color de fondo del Drawer
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 50, // Establece la altura deseada para el encabezado
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 0, 0), // Rojo para el encabezado
                ),
                child: Center(
                  child: Text(
                    'Pharma Salud',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Ajusta el tamaño de fuente si es necesario
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _createDrawerItem(
                icon: Icons.dashboard,
                text: 'Dashboard',
                index: 0,
                selectedIndex: selectedIndex,
                onTap: () => onSelectScreen(0,  DashboardInicialScreen(), 'Dashboard'),
              ),
                            SizedBox(height: 20),

              _createDrawerItem(
                icon: Icons.person,
                text: 'Usuarios',
                index: 1,
                selectedIndex: selectedIndex,
                onTap: () => onSelectScreen(1, UsuariosScreen(), 'Usuarios'),
              ),
                            SizedBox(height: 20),

              _createDrawerItem(
                icon: Icons.add_box,
                text: 'Productos',
                index: 2,
                selectedIndex: selectedIndex,
                onTap: () => onSelectScreen(2, const ProductoScreen(), 'Productos'),
              ),
                            SizedBox(height: 20),

              _createDrawerItem(
                icon: Icons.shopping_cart,
                text: 'Registro de ventas',
                index: 3,
                selectedIndex: selectedIndex,
                onTap: () => onSelectScreen(3, AdminRegistroVentasWidget(), 'Registro de ventas'),
              ),

              SizedBox(height: 20),

              _createDrawerItem(
                icon: Icons.logout,
                text: 'Cerrar sesión',
                index: 5,
                selectedIndex: selectedIndex,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _createDrawerItem({
    required IconData icon,
    required String text,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    bool isSelected = index == selectedIndex;

    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white, // Ícono blanco siempre
      ),
      title: Text(
        text,
        style: TextStyle(
          color: Colors.white, // Texto blanco siempre
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected
          ? const Color.fromARGB(255, 255, 0, 0) // Fondo rojo si está seleccionado
          : const Color.fromARGB(255, 255, 255, 255), // Fondo negro si no está seleccionado
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar cierre de sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo sin hacer nada
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
                Navigator.pushReplacementNamed(context, '/'); // Redirigir al login
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );
  }
}

