import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/usuario_repository.dart';

class AddUserScreen extends StatefulWidget {
  @override
  _AddUserScreenState createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  final TextEditingController _nombreUsuarioController = TextEditingController();
  final TextEditingController _claveController = TextEditingController();
  bool _isPasswordVisible = false;

  String _selectedRol = 'Vendedor'; // Valor por defecto
  final List<String> _roles = ['Administrador', 'Vendedor']; // Opciones de rol
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Clave para el formulario

  Future<void> _addUsuario() async {
    if (_formKey.currentState!.validate()) {
      // Si el formulario es válido, procede a agregar el usuario
      await _usuarioRepository.createUsuario({
        'NOMBRE_USUARIO': _nombreUsuarioController.text,
        'CLAVE': _claveController.text,
        'ROL': _selectedRol, // Usar el rol seleccionado
      });

      // Limpiar los campos después de añadir el usuario
      _nombreUsuarioController.clear();
      _claveController.clear();

      // Volver a la pantalla anterior
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 255, 4, 0), // Color rojo más claro
              const Color.fromARGB(255, 174, 0, 0), // Color rojo oscuro
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView( // Permitir desplazamiento si el contenido excede la altura
            child: Container(
              width: 500, // Ancho especificado
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white, // Fondo blanco
                borderRadius: BorderRadius.circular(12), // Bordes redondeados
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey, // Asignar la clave del formulario
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Alinear hijos al inicio
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red, // Fondo rojo
                          shape: BoxShape.circle, // Forma circular para el fondo
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white), // Icono blanco
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                    Text(
                      'Registrar Usuario',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 255, 0, 0)),
                      textAlign: TextAlign.center, // Centrando el texto
                    ),
                    SizedBox(height: 20),
                    Icon(
                      Icons.person,
                      size: 105,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _nombreUsuarioController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de Usuario',
                        prefixIcon: Icon(Icons.person), // Icono de usuario
                        border: OutlineInputBorder(), // Bordes para el campo
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese un nombre de usuario.';
                        }
                        return null; // Si está bien, retorna null
                      },
                    ),
                    SizedBox(height: 20), // Espaciado entre campos
                    TextFormField(
                      controller: _claveController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock), // Icono de candado
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(), // Bordes para el campo
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingrese una contraseña.';
                        } else if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres.';
                        }
                        return null; // Si está bien, retorna null
                      },
                    ),
                    SizedBox(height: 20),
                    // Dropdown para seleccionar el rol
                    DropdownButtonFormField<String>(
                      value: _selectedRol,
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(), // Bordes para el dropdown
                      ),
                      items: _roles.map((String rol) {
                        return DropdownMenuItem<String>(
                          value: rol,
                          child: Text(rol),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRol = newValue!;
                        });
                      },
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _addUsuario,
                      child: Text(
                        'Guardar',
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
    );
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }
}
