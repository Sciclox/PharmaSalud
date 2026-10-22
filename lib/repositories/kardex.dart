import 'package:pharma_salud/database/database_helper.dart';

class KardexRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Obtener registros de KARDEX filtrados por NOMBRE_PRODUCTO (búsqueda parcial)
  Future<List<Map<String, dynamic>>> getKardexByProductName(
      String productName) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT K.*, P.Cantidad_Presentacion, P.Cantidad_Presentacion_blister,
             DV.DEVOLUCION
      FROM KARDEX K
      LEFT JOIN PRODUCTO P ON K.NOMBRE_PRODUCTO = P.Nombre_Producto
      LEFT JOIN DETALLES_VENTA DV ON K.ID_DETALLE_VENTA = DV.ID
      WHERE K.NOMBRE_PRODUCTO LIKE ?
      ORDER BY K.ID DESC
    ''';

    return await db.rawQuery(query, ['%$productName%']);
  }

  Future<List<Map<String, dynamic>>> getKardexByDate(
      String fechaMovimiento) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT K.*, P.Cantidad_Presentacion, P.Cantidad_Presentacion_blister,
             DV.DEVOLUCION
      FROM KARDEX K
      LEFT JOIN PRODUCTO P ON K.NOMBRE_PRODUCTO = P.Nombre_Producto
      LEFT JOIN DETALLES_VENTA DV ON K.ID_DETALLE_VENTA = DV.ID
      WHERE K.FECHA_MOVIMIENTO LIKE ?
      ORDER BY K.ID DESC
    ''';

    return await db.rawQuery(query, ['${fechaMovimiento.trim()}%']);
  }

  // Obtener registros de KARDEX filtrados por TIPO_MOVIMIENTO
  Future<List<Map<String, dynamic>>> getKardexByType(
      String tipoMovimiento) async {
    final db = await _dbHelper.database;

    final query = '''
      SELECT K.*, P.Cantidad_Presentacion, P.Cantidad_Presentacion_blister,
             DV.DEVOLUCION
      FROM KARDEX K
      LEFT JOIN PRODUCTO P ON K.NOMBRE_PRODUCTO = P.Nombre_Producto
      LEFT JOIN DETALLES_VENTA DV ON K.ID_DETALLE_VENTA = DV.ID
      WHERE K.TIPO_MOVIMIENTO = ?
      ORDER BY K.ID DESC
    ''';

    return await db.rawQuery(query, [tipoMovimiento]);
  }

  // Insertar un nuevo registro en KARDEX
  Future<int> insertKardexEntry(Map<String, dynamic> producto) async {
    final db = await _dbHelper.database;
    // Insertar el registro y devolver el ID del nuevo registro
    return await db.insert('KARDEX', producto);
  }

  // Borrar un registro específico en KARDEX por ID
  Future<int> deleteKardexEntryById(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'KARDEX',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getKardexByFilters({
    String? productName,
    String? date,
    String? movementType,
    bool soloDevueltos = false,
    bool soloAjustes = false,
  }) async {
    final db = await _dbHelper.database;

    // Construimos las condiciones dinámicamente
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (productName != null && productName.isNotEmpty) {
      whereClauses.add('K.NOMBRE_PRODUCTO LIKE ?');
      whereArgs.add('%$productName%');
    }

    if (date != null && date.isNotEmpty) {
      whereClauses.add('K.FECHA_MOVIMIENTO LIKE ?');
      whereArgs.add('${date.trim()}%');
    }

    if (movementType != null && movementType.isNotEmpty) {
      whereClauses.add('K.TIPO_MOVIMIENTO = ?');
      whereArgs.add(movementType);
    }

    if (soloDevueltos) {
      whereClauses.add("(DV.DEVOLUCION = 'Si' OR K.TIPO_MOVIMIENTO LIKE '%Devoluci%')");
    }

    if (soloAjustes) {
      whereClauses.add("(K.TIPO_MOVIMIENTO LIKE 'Ajuste%' OR K.TIPO_MOVIMIENTO = 'Ajuste de inventario')");
    }

    // Combina las condiciones con 'AND'
    final whereString =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final query = '''
      SELECT K.*, P.Cantidad_Presentacion, P.Cantidad_Presentacion_blister,
             DV.DEVOLUCION
      FROM KARDEX K
      LEFT JOIN PRODUCTO P ON K.NOMBRE_PRODUCTO = P.Nombre_Producto
      LEFT JOIN DETALLES_VENTA DV ON K.ID_DETALLE_VENTA = DV.ID
      $whereString
      ORDER BY K.ID DESC
    ''';

    // Realiza la consulta con los filtros aplicados
    return await db.rawQuery(query, whereArgs);
  }

  // Actualizar un registro existente en KARDEX
  Future<void> actualizarKardex(
    int id, {
    required int cantidad,
    required String tipoMovimiento,
  }) async {
    final db = await _dbHelper.database;

    await db.update(
      'KARDEX',
      {
        'CANTIDAD': cantidad,
        'TIPO_MOVIMIENTO': tipoMovimiento,
      },
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Vincula un registro de Kardex con su detalle de venta correspondiente.
  Future<void> vincularDetalleVenta(int kardexId, int detalleVentaId) async {
    final db = await _dbHelper.database;
    await db.update(
      'KARDEX',
      {'ID_DETALLE_VENTA': detalleVentaId},
      where: 'ID = ?',
      whereArgs: [kardexId],
    );
  }
}
