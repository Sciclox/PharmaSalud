import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/usuario_repository.dart';
import 'package:pharma_salud/screens/dashboard_admin_screen.dart';
import 'package:pharma_salud/screens/vendedor_screen.dart'; // Asegúrate de importar esta pantalla también

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

Future<void> _login() async {
  if (_formKey.currentState!.validate()) {
    // Mostrar el diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre al tocar fuera del cuadro de diálogo
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text('Cargando...', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      },
    );

    final userRepository = UsuarioRepository();

    // Intentar autenticar al usuario
    final isAuthenticated = await userRepository.authenticateUser(
      _usernameController.text,
      _passwordController.text,
    );

    // Cerrar el diálogo de carga
    Navigator.of(context).pop();

    if (isAuthenticated) {
      final userRole = await userRepository.getUserRole(_usernameController.text);
      final userId = await userRepository.getUserId(_usernameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inicio de sesión exitoso')),
      );

      // Redirigir según el rol del usuario
      if (userRole == 'Administrador') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardAdminScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VendedorScreen(userId: userId)),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credenciales incorrectas')),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Agregar un fondo degradado
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 255, 4, 0), // Color rojo más claro
              const Color.fromARGB(255, 174, 0, 0), // Color rojo oscuro
            ],
            begin: Alignment.topCenter, // Comienza en el centro superior
            end: Alignment.bottomCenter, // Termina en el centro inferior
          ),
        ),
        child: Center(
          child: Container(
            width: 500, // Establecer el ancho
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Pharma Salud',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 0, 0)),
                      ),
                      const SizedBox(height: 20), // Espacio entre el título y el ícono
                      const Icon(
                        Icons.lock_person, // Icono de inicio de sesión
                        size: 105, // Tamaño del ícono
                      ),
                      const SizedBox(height: 20), // Espacio entre el ícono y el campo de usuario
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de usuario',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(),
                          ),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa tu nombre de usuario';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(),
                          ),
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa tu contraseña';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 35),
ElevatedButton(
  onPressed: _login,
  child: Text(
    'Iniciar Sesión',
    style: TextStyle(color: Colors.white, fontSize: 20), // Texto blanco
  ),
  style: ElevatedButton.styleFrom(
    foregroundColor: Colors.white, backgroundColor: Colors.red, // Color del texto al presionar
    minimumSize: Size(double.infinity,60), // Tamaño del botón
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpiar los controladores
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
