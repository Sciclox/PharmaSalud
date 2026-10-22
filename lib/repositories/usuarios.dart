import 'package:pharma_salud/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Validación de campos obligatorios
    if (!usuario.containsKey('NOMBRE_USUARIO') ||
        !usuario.containsKey('NOMBRE_VENDEDOR') ||
        !usuario.containsKey('CLAVE') ||
        !usuario.containsKey('ROL') ||
        !usuario.containsKey('GENERO') ||
        !usuario.containsKey('ESTADO')) {
      throw Exception("Faltan campos obligatorios para crear el usuario");
    }

    // Verificar si ya existe un usuario con el mismo nombre
    final existingUser = await db.query(
      'USUARIO',
      where: 'NOMBRE_USUARIO = ?',
      whereArgs: [usuario['NOMBRE_USUARIO']],
    );

    if (existingUser.isNotEmpty) {
      throw Exception("El nombre de usuario ya existe. Por favor, elige otro.");
    }

    // Insertar el nuevo usuario si no existe otro con el mismo nombre
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
    // Creamos una copia para no intentar actualizar la PK
    final Map<String, dynamic> values = Map<String, dynamic>.from(usuario);
    final id = values.remove('ID_USUARIO');

    await db.update(
      'USUARIO',
      values,
      where: 'ID_USUARIO = ?',
      whereArgs: [id],
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
      columns: ['ID_USUARIO'], // Asegúrate de que este sea el nombre correcto
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

  Future<String> getUserNameById(int idUsuario) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      columns: ['NOMBRE_VENDEDOR'],
      where: 'ID_USUARIO = ?',
      whereArgs: [idUsuario],
    );

    return result.first['NOMBRE_VENDEDOR'];
  }

  Future<String> getUserGenderById(int idUsuario) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      columns: ['GENERO'],
      where: 'ID_USUARIO = ?',
      whereArgs: [idUsuario],
    );

    return result.first['GENERO'];
  }

  Future<bool> userExists(String username) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      where: 'NOMBRE_USUARIO = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty;
  }

  Future<String?> getUserStatus(String username) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'USUARIO',
      columns: ['ESTADO'],
      where: 'NOMBRE_USUARIO = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty ? result.first['ESTADO'] as String? : null;
  }

  // Obtener el PIN maestro configurado para el modo discreto (por defecto '1234')
  Future<String> getPinModoOculto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pin_modo_oculto') ?? '1234';
  }

  // Guardar un nuevo PIN maestro para el modo discreto
  Future<void> setPinModoOculto(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_modo_oculto', newPin.trim());
  }

  // Verifica si la clave ingresada corresponde al PIN secreto maestro o a un Administrador activo
  Future<bool> verifyAdminOrSecretPassword(String password) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) return false;

    // 1. PIN maestro configurado (por defecto '1234')
    final pinMaestro = await getPinModoOculto();
    if (trimmed == pinMaestro) {
      return true;
    }

    // 2. Verificar contra la clave de cualquier Administrador activo
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> admins = await db.query(
      'USUARIO',
      where: "ROL = 'Administrador' AND CLAVE = ? AND ESTADO = 'Activo'",
      whereArgs: [trimmed],
    );

    return admins.isNotEmpty;
  }
}
