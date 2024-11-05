import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/usuario_repository.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserScreen({Key? key, required this.user}) : super(key: key);

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  late TextEditingController _nombreUsuarioController;
  late TextEditingController _claveController;
  late String _selectedRol;
  bool _isPasswordVisible = false;
  final List<String> _roles = ['Administrador', 'Vendedor'];
  final _formKey = GlobalKey<FormState>(); // Clave para el formulario

  @override
  void initState() {
    super.initState();
    _nombreUsuarioController = TextEditingController(text: widget.user['NOMBRE_USUARIO']);
    _claveController = TextEditingController(text: widget.user['CLAVE']);
    _selectedRol = _roles.contains(widget.user['ROL']) ? widget.user['ROL'] : 'Administrador';
  }

  Future<void> _updateUsuario() async {
    if (_formKey.currentState!.validate()) { // Validar el formulario
      await _usuarioRepository.updateUsuario({
        'ID_USUARIO': widget.user['ID_USUARIO'],
        'NOMBRE_USUARIO': _nombreUsuarioController.text,
        'CLAVE': _claveController.text,
        'ROL': _selectedRol,
      });

      _nombreUsuarioController.clear();
      _claveController.clear();
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
          child: SingleChildScrollView(
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
                key: _formKey, // Asignar la clave al formulario
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'Editar Usuario',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 255, 0, 0)),
                      textAlign: TextAlign.center,
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
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese un nombre de usuario';
                        }
                        return null; // No hay error
                      },
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _claveController,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
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
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingrese una contraseña';
                        } else if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null; // No hay error
                      },
                    ),
                    SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedRol,
                      decoration: InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
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
                      validator: (value) {
                        if (value == null) {
                          return 'Por favor seleccione un rol';
                        }
                        return null; // No hay error
                      },
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _updateUsuario,
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
