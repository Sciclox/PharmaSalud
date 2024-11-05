import 'package:pharma_salud/database_helper.dart';

class UsuarioRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<bool> authenticateUser(String username, String password) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      where: 'NOMBRE_USUARIO = ? AND CLAVE = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }

  Future<void> createUsuario(Map<String, dynamic> usuario) async {
    final db = await _databaseHelper.database;
    if (!usuario.containsKey('NOMBRE_USUARIO') || 
        !usuario.containsKey('CLAVE') || 
        !usuario.containsKey('ROL')) {
      throw Exception("Faltan campos obligatorios para crear el usuario");
    }
    await db.insert('USUARIO', usuario);
  }

  Future<List<Map<String, dynamic>>> readUsuarios() async {
    final db = await _databaseHelper.database;
    return await db.query('USUARIO');
  }

  Future<List<Map<String, dynamic>>> readUsuariosV02() async {
  final db = await _databaseHelper.database;

  // Consulta para obtener solo los usuarios con rol de Vendedor
  return await db.query(
    'USUARIO',
    where: 'ROL = ?',
    whereArgs: ['Vendedor'], // Aquí especificas el rol que deseas filtrar
  );
}

  Future<void> updateUsuario(Map<String, dynamic> usuario) async {
    final db = await _databaseHelper.database;
    await db.update(
      'USUARIO',
      usuario,
      where: 'ID_USUARIO = ?',
      whereArgs: [usuario['ID_USUARIO']],
    );
  }

  Future<void> deleteUsuario(int idUsuario) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'USUARIO',
      where: 'ID_USUARIO = ?',
      whereArgs: [idUsuario],
    );
  }

  Future<String?> getUserRole(String username) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      columns: ['ROL'],
      where: 'NOMBRE_USUARIO = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty ? result.first['ROL'] as String? : null;
  }

Future<int> getUserId(String username) async {
  final db = await _databaseHelper.database;
  final List<Map<String, dynamic>> result = await db.query(
    'USUARIO',
    columns: ['ID_USUARIO'],  // Asegúrate de que este sea el nombre correcto
    where: 'NOMBRE_USUARIO = ?',
    whereArgs: [username],
  );

  // Verificamos si hay resultados
  if (result.isNotEmpty) {
    return result.first['ID_USUARIO'] as int; // Accede a 'ID_USUARIO'
  } else {
    throw Exception('Usuario no encontrado'); // Lanzar una excepción
  }
}
}
