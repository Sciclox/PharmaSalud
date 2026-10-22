import 'package:pharma_salud/database/database_helper.dart';

class SobranteCajaRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Registrar un sobrante de caja
  Future<int> registrarSobrante({
    required int usuarioId,
    required double monto,
    String? nota,
    String tipo = 'SOBRANTE',
  }) async {
    final db = await _databaseHelper.database;
    final fecha = DateTime.now();
    final fechaStr =
        "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')} "
        "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}:${fecha.second.toString().padLeft(2, '0')}";

    return await db.insert('SOBRANTE_CAJA', {
      'USUARIO_ID': usuarioId,
      'FECHA': fechaStr,
      'MONTO': monto,
      'NOTA': nota ?? '',
      'TIPO': tipo,
    });
  }

  /// Obtener sobrantes de un usuario en una fecha específica (YYYY-MM-DD)
  Future<List<Map<String, dynamic>>> obtenerSobrantesPorUsuarioYFecha(
      int usuarioId, String fecha) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT SC.*, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      WHERE SC.USUARIO_ID = ? AND SC.FECHA LIKE ?
      ORDER BY SC.ID DESC
    ''', [usuarioId, '$fecha%']);
  }

  /// Obtener todos los sobrantes de una fecha (para el admin)
  Future<List<Map<String, dynamic>>> obtenerSobrantesPorFecha(
      String fecha) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT SC.*, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      WHERE SC.FECHA LIKE ?
      ORDER BY SC.FECHA DESC
    ''', ['$fecha%']);
  }

  /// Obtener sobrantes por rango de fechas (para ajuste de inventario y cuadre global)
  Future<List<Map<String, dynamic>>> obtenerSobrantesPorRango(
      String fechaDesde, String fechaHasta) async {
    final db = await _databaseHelper.database;
    final start = fechaDesde.contains(' ') ? fechaDesde : '$fechaDesde 00:00:00';
    final end = fechaHasta.contains(' ') ? fechaHasta : '$fechaHasta 23:59:59';
    return await db.rawQuery('''
      SELECT SC.*, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      WHERE SC.FECHA BETWEEN ? AND ? AND (SC.TIPO != 'AJUSTE' OR SC.TIPO IS NULL)
      ORDER BY SC.FECHA DESC
    ''', [start, end]);
  }

  /// Obtener total de sobrantes de caja en un rango de fechas (excluyendo ajustes)
  Future<double> obtenerTotalSobrantesPorRango(
      String fechaDesde, String fechaHasta) async {
    final db = await _databaseHelper.database;
    final start = fechaDesde.contains(' ') ? fechaDesde : '$fechaDesde 00:00:00';
    final end = fechaHasta.contains(' ') ? fechaHasta : '$fechaHasta 23:59:59';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(MONTO), 0) as TOTAL
      FROM SOBRANTE_CAJA
      WHERE FECHA BETWEEN ? AND ? AND (TIPO != 'AJUSTE' OR TIPO IS NULL)
    ''', [start, end]);
    return (result.first['TOTAL'] as num?)?.toDouble() ?? 0.0;
  }

  /// Obtener el total de sobrantes del día actual
  Future<double> obtenerTotalSobranteHoy(int usuarioId) async {
    final db = await _databaseHelper.database;
    final hoy = DateTime.now();
    final fechaHoy =
        "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(MONTO), 0) as TOTAL
      FROM SOBRANTE_CAJA
      WHERE USUARIO_ID = ? AND FECHA LIKE ? AND (TIPO != 'AJUSTE' OR TIPO IS NULL)
    ''', [usuarioId, '$fechaHoy%']);

    return (result.first['TOTAL'] as num?)?.toDouble() ?? 0.0;
  }

  /// Obtener el total general de sobrantes de hoy (todos los usuarios)
  Future<double> obtenerTotalGeneralHoy() async {
    final db = await _databaseHelper.database;
    final hoy = DateTime.now();
    final fechaHoy =
        "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(MONTO), 0) as TOTAL
      FROM SOBRANTE_CAJA
      WHERE FECHA LIKE ? AND (TIPO != 'AJUSTE' OR TIPO IS NULL)
    ''', ['$fechaHoy%']);

    return (result.first['TOTAL'] as num?)?.toDouble() ?? 0.0;
  }

  /// Obtener total general de sobrantes por fecha
  Future<double> obtenerTotalSobrantesPorFecha(String fecha) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(MONTO), 0) as TOTAL
      FROM SOBRANTE_CAJA
      WHERE FECHA LIKE ? AND (TIPO != 'AJUSTE' OR TIPO IS NULL)
    ''', ['$fecha%']);

    return (result.first['TOTAL'] as num?)?.toDouble() ?? 0.0;
  }

  /// Eliminar un sobrante por ID
  Future<void> eliminarSobrante(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('SOBRANTE_CAJA', where: 'ID = ?', whereArgs: [id]);
  }

  /// Eliminar todos los registros de ajuste de inventario erróneamente guardados en caja
  Future<int> purgarAjustesInventarioDeCaja() async {
    final db = await _databaseHelper.database;
    return await db.delete('SOBRANTE_CAJA',
        where: "TIPO = 'AJUSTE' OR NOTA LIKE 'Ajuste:%' OR NOTA LIKE '%AJUSTO EL INVENTARIO%' OR MONTO < 0");
  }

  /// Eliminar todos los registros históricos de tipo REINICIO (filas negativas artificiales)
  Future<int> purgarReiniciosDeCaja() async {
    final db = await _databaseHelper.database;
    return await db.delete('SOBRANTE_CAJA', where: "TIPO = 'REINICIO' OR MONTO < 0");
  }

  /// Obtener TODOS los sobrantes sin filtro de fecha (excluyendo ajustes y reinicios)
  Future<List<Map<String, dynamic>>> obtenerTodosLosSobrantes() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT SC.*, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      WHERE (SC.TIPO != 'AJUSTE' OR SC.TIPO IS NULL) AND (SC.TIPO != 'REINICIO')
      ORDER BY SC.FECHA DESC
    ''');
  }

  /// Obtener el total acumulado general de caja (sin filtro de fecha, excluyendo ajustes y reinicios)
  Future<double> obtenerTotalGeneral() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(MONTO), 0) as TOTAL FROM SOBRANTE_CAJA
      WHERE (TIPO != 'AJUSTE' OR TIPO IS NULL) AND (TIPO != 'REINICIO')
    ''');
    return (result.first['TOTAL'] as num?)?.toDouble() ?? 0.0;
  }

  /// Obtener sobrantes filtrados dinámicamente por fecha, rango de fechas, vendedor y/o tipo
  Future<List<Map<String, dynamic>>> obtenerSobrantesFiltrados({
    String? fecha,
    String? fechaInicio,
    String? fechaFin,
    int? usuarioId,
    String? tipo,
  }) async {
    final db = await _databaseHelper.database;
    String where = " (SC.TIPO != 'AJUSTE' OR SC.TIPO IS NULL) AND (SC.TIPO != 'REINICIO')";
    List<dynamic> args = [];

    if (fechaInicio != null && fechaInicio.isNotEmpty && fechaFin != null && fechaFin.isNotEmpty) {
      where += ' AND SC.FECHA BETWEEN ? AND ?';
      args.add('$fechaInicio 00:00:00');
      args.add('$fechaFin 23:59:59');
    } else if (fechaInicio != null && fechaInicio.isNotEmpty) {
      where += ' AND SC.FECHA >= ?';
      args.add('$fechaInicio 00:00:00');
    } else if (fechaFin != null && fechaFin.isNotEmpty) {
      where += ' AND SC.FECHA <= ?';
      args.add('$fechaFin 23:59:59');
    } else if (fecha != null && fecha.isNotEmpty) {
      where += ' AND SC.FECHA LIKE ?';
      args.add('$fecha%');
    }

    if (usuarioId != null) {
      where += ' AND SC.USUARIO_ID = ?';
      args.add(usuarioId);
    }
    if (tipo != null && tipo.isNotEmpty && tipo != 'Todos') {
      if (tipo == 'SOBRANTE') {
        where += " AND (SC.TIPO = ? OR SC.TIPO IS NULL OR SC.TIPO = '')";
      } else {
        where += " AND SC.TIPO = ?";
      }
      args.add(tipo);
    }

    return await db.rawQuery('''
      SELECT SC.*, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      WHERE $where
      ORDER BY SC.FECHA DESC
    ''', args);
  }

  /// Obtener la lista de vendedores que tienen sobrantes registrados
  Future<List<Map<String, dynamic>>> obtenerVendedoresConSobrantes() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT DISTINCT U.ID_USUARIO, U.NOMBRE_VENDEDOR
      FROM SOBRANTE_CAJA SC
      JOIN USUARIO U ON SC.USUARIO_ID = U.ID_USUARIO
      ORDER BY U.NOMBRE_VENDEDOR
    ''');
  }
}
