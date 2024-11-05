import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/usuario_repository.dart';
import 'package:pharma_salud/screens/editar_user_screen.dart';
import 'add_user_screen.dart'; // Asegúrate de importar la pantalla para agregar usuario

class UsuariosScreen extends StatefulWidget {
  @override
  _UsuariosScreenState createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  List<Map<String, dynamic>> _usuarios = [];
  
  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  Future<void> _loadUsuarios() async {
    _usuarios = await _usuarioRepository.readUsuarios();
    setState(() {});
  }

  Future<void> _deleteUsuario(int idUsuario) async {
    await _usuarioRepository.deleteUsuario(idUsuario);
    await _loadUsuarios();
  }

  Future<void> _confirmDeleteUsuario(int idUsuario) async {
    // Mostrar un cuadro de diálogo para confirmar la eliminación
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que deseas eliminar este usuario?'),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(false); // Cerrar el diálogo sin eliminar
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red, // Cambia el color del texto a rojo
              ),
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop(true); // Cerrar el diálogo y confirmar eliminación
              },
            ),
          ],
        );
      },
    );

    // Si el usuario confirma, proceder a eliminar
    if (confirm == true) {
      await _usuarioRepository.deleteUsuario(idUsuario);
      await _loadUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Container reemplazando el AppBar
          Container(
            height: 56, // Altura del Container similar al AppBar
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            color: const Color.fromARGB(255, 255, 0, 0), // Color de fondo del Container
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usuarios',
                  style: TextStyle(
                    color: Colors.white, // Color del texto
                    fontSize: 20, // Tamaño de la fuente
                    fontWeight: FontWeight.bold, // Texto en negrita
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () {
                    // Navegar a la pantalla de agregar usuario
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddUserScreen()),
                    ).then((_) => _loadUsuarios()); // Recargar la lista de usuarios al volver
                  },
                  tooltip: 'Agregar Usuario',
                  iconSize: 30.0,
                  padding: const EdgeInsets.all(10.0),
                  splashColor: const Color.fromARGB(255, 236, 64, 52).withOpacity(0.5),
                  highlightColor: const Color.fromARGB(255, 233, 104, 94).withOpacity(0.5),
                ),
              ],
            ),
          ),
          // Resto de la pantalla
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10.0), // Añadir padding alrededor de la lista
              child: ListView.builder(
                itemCount: _usuarios.length,
                itemBuilder: (context, index) {
                  final usuario = _usuarios[index];
                  return Card( // Usar un Card para mejorar el diseño
                    color: Colors.white, // Color de fondo blanco para la tarjeta
                    elevation: 4, // Sombra del card
                    margin: const EdgeInsets.symmetric(vertical: 8.0), // Espaciado vertical entre tarjetas
                    child: ListTile(
                      title: Text(
                        usuario['NOMBRE_USUARIO'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Clave: ${usuario['CLAVE']}'),
                          Text('Rol: ${usuario['ROL']}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color.fromARGB(255, 55, 0, 255)), // Color personalizado
                            onPressed: () {
                              // Navegar a la pantalla de editar usuario, pasando el usuario
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditUserScreen(user: usuario), // Asegúrate de pasar el usuario aquí
                                ),
                              ).then((_) => _loadUsuarios()); // Recargar la lista de usuarios al volver
                            },
                            tooltip: 'Editar Usuario',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDeleteUsuario(usuario['ID_USUARIO']),
                            tooltip: 'Eliminar Usuario',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
