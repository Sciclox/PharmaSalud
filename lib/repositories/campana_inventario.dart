import 'package:pharma_salud/database/database_helper.dart';

class CampanaInventarioRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Iniciar una nueva campaña de inventario
  Future<int> iniciarCampana(String nombre, DateTime inicio) async {
    final db = await _databaseHelper.database;
    final inicioStr = inicio.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    
    // Primero, si hay alguna campaña activa, la cerramos automáticamente
    await db.update(
      'CAMPANA_INVENTARIO',
      {
        'FECHA_FIN': inicioStr,
        'ESTADO': 'COMPLETADO',
      },
      where: "ESTADO = 'ACTIVO'",
    );

    return await db.insert('CAMPANA_INVENTARIO', {
      'NOMBRE': nombre,
      'FECHA_INICIO': inicioStr,
      'ESTADO': 'ACTIVO',
    });
  }

  /// Finalizar una campaña de inventario activa
  Future<int> finalizarCampana(int id, DateTime fin) async {
    final db = await _databaseHelper.database;
    final finStr = fin.toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    return await db.update(
      'CAMPANA_INVENTARIO',
      {
        'FECHA_FIN': finStr,
        'ESTADO': 'COMPLETADO',
      },
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Editar las fechas (hitos) de una campaña
  Future<int> editarFechas(int id, DateTime inicio, DateTime? fin) async {
    final db = await _databaseHelper.database;
    final inicioStr = inicio.toIso8601String().replaceFirst('T', ' ').substring(0, 19);
    final finStr = fin?.toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    final Map<String, dynamic> data = {
      'FECHA_INICIO': inicioStr,
    };
    if (finStr != null) {
      data['FECHA_FIN'] = finStr;
    }

    return await db.update(
      'CAMPANA_INVENTARIO',
      data,
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Eliminar una campaña de inventario
  Future<int> eliminarCampana(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'CAMPANA_INVENTARIO',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Obtener todas las campañas registradas
  Future<List<Map<String, dynamic>>> obtenerTodas() async {
    final db = await _databaseHelper.database;
    return await db.query('CAMPANA_INVENTARIO', orderBy: 'ID DESC');
  }

  /// Obtener la campaña activa (si la hay)
  Future<Map<String, dynamic>?> obtenerActiva() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'CAMPANA_INVENTARIO',
      where: "ESTADO = 'ACTIVO'",
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Obtener todos los ajustes hechos en un rango de fechas
  Future<List<Map<String, dynamic>>> obtenerAjustesEnRango(
      String inicioStr, String finStr) async {
    final db = await _databaseHelper.database;

    // Buscamos en el Kardex todos los movimientos de tipo ajuste en el rango de fechas
    return await db.rawQuery('''
      SELECT K.*, P.Tipo_Producto, P.Costo_Unidad, P.Precio_Unidad, P.Cantidad_Presentacion
      FROM KARDEX K
      LEFT JOIN PRODUCTO P ON K.NOMBRE_PRODUCTO = P.Nombre_Producto
      WHERE (K.TIPO_MOVIMIENTO = 'Ajuste Inventario (+)' OR K.TIPO_MOVIMIENTO = 'Ajuste Inventario (-)')
        AND K.FECHA_MOVIMIENTO >= ? AND K.FECHA_MOVIMIENTO <= ?
      ORDER BY K.ID DESC
    ''', [inicioStr, finStr]);
  }
}
