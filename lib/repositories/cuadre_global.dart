import 'package:pharma_salud/database/database_helper.dart';

class CuadreGlobalRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Guardar o actualizar un cuadre global para una campaña
  Future<int> guardarCuadre({
    required int campanaId,
    required String campanaNombre,
    required String fechaCuadre,
    required String fechaInicioCampana,
    required String fechaFinCampana,
    required double totalSobranteInv,
    required double totalFaltanteInv,
    required double balanceInv,
    required double totalSobranteCaja,
    required double balanceGlobal,
    String? observaciones,
    int? adminId,
  }) async {
    final db = await _databaseHelper.database;

    // Verificar si ya existe un cuadre previo para esta campaña
    final existentes = await db.query(
      'CUADRE_GLOBAL_CAMPANA',
      where: 'CAMPANA_ID = ?',
      whereArgs: [campanaId],
    );

    final datos = {
      'CAMPANA_ID': campanaId,
      'CAMPANA_NOMBRE': campanaNombre,
      'FECHA_CUADRE': fechaCuadre,
      'FECHA_INICIO_CAMPANA': fechaInicioCampana,
      'FECHA_FIN_CAMPANA': fechaFinCampana,
      'TOTAL_SOBRANTE_INV': totalSobranteInv,
      'TOTAL_FALTANTE_INV': totalFaltanteInv,
      'BALANCE_INV': balanceInv,
      'TOTAL_SOBRANTE_CAJA': totalSobranteCaja,
      'BALANCE_GLOBAL': balanceGlobal,
      'OBSERVACIONES': observaciones ?? '',
      'ADMIN_ID': adminId,
    };

    if (existentes.isNotEmpty) {
      // Actualizar el registro existente
      final id = existentes.first['ID'] as int;
      await db.update(
        'CUADRE_GLOBAL_CAMPANA',
        datos,
        where: 'ID = ?',
        whereArgs: [id],
      );
      return id;
    } else {
      // Insertar nuevo registro
      return await db.insert('CUADRE_GLOBAL_CAMPANA', datos);
    }
  }

  /// Obtener el cuadre global de una campaña específica
  Future<Map<String, dynamic>?> obtenerCuadrePorCampana(int campanaId) async {
    final db = await _databaseHelper.database;
    final res = await db.query(
      'CUADRE_GLOBAL_CAMPANA',
      where: 'CAMPANA_ID = ?',
      whereArgs: [campanaId],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  /// Obtener todos los cuadres globales registrados
  Future<List<Map<String, dynamic>>> obtenerTodos() async {
    final db = await _databaseHelper.database;
    return await db.query(
      'CUADRE_GLOBAL_CAMPANA',
      orderBy: 'FECHA_CUADRE DESC',
    );
  }

  /// Eliminar un cuadre global por ID
  Future<int> eliminarCuadre(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'CUADRE_GLOBAL_CAMPANA',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}
