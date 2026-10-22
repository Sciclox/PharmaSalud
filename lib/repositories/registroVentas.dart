import 'package:pharma_salud/database/database_helper.dart';

class RegistroVentasRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Función para agregar un nuevo registro de venta
  Future<int> agregarRegistroVenta(Map<String, dynamic> registroVenta) async {
    final db = await _databaseHelper.database;
    return await db.insert('REGISTRO_DE_VENTAS', {
      'FECHA': registroVenta['FECHA'],
      'TOTAL': registroVenta['TOTAL'],
      'PAGO_CON': registroVenta['PAGO_CON'],
      'VUELTO': registroVenta['VUELTO'],
      'USUARIO_ID': registroVenta['USUARIO_ID'],
      'METODO_PAGO': registroVenta['METODO_PAGO'] ?? 'Efectivo',
    });
  }

  // Función para agregar un nuevo detalle de venta
  Future<int> agregarDetalleVenta(Map<String, dynamic> detalleVenta) async {
    final db = await _databaseHelper.database;
    // Inserta el detalle de venta y retorna el ID
    return await db.insert('DETALLES_VENTA', {
      'REGISTRO_VENTA_ID': detalleVenta['REGISTRO_VENTA_ID'],
      'PRODUCTO_ID': detalleVenta['PRODUCTO_ID'],
      'NOMBRE_PRODUCTO': detalleVenta['NOMBRE_PRODUCTO'], // Manejo de errores
      'USUARIO_ID': detalleVenta['USUARIO_ID'],
      'FECHA': detalleVenta['FECHA'],
      'TIPO_VENTA': detalleVenta['TIPO_VENTA'], // Manejo de errores
      'CANTIDAD': detalleVenta['CANTIDAD'],
      'PRECIO_VENTA': detalleVenta['PRECIO_VENTA'],
    });
  }

  // Función para obtener todos los detalles de venta
  Future<List<Map<String, dynamic>>> obtenerTodosLosDetallesVentas() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> detalles =
        await db.query('DETALLES_VENTA');
    return detalles;
  }

  // Función para obtener todos los detalles de venta según el id del usuario
  Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuario(
      int userId) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
    SELECT 
      DV.ID, 
      DV.REGISTRO_VENTA_ID, 
      DV.PRODUCTO_ID,
      DV.NOMBRE_PRODUCTO, 
      DV.CANTIDAD, 
      DV.TIPO_VENTA, 
      DV.PRECIO_VENTA, 
      DV.DEVOLUCION,
      RV.FECHA,
      P.Cantidad_Presentacion,
      P.Cantidad_Presentacion_blister
    FROM DETALLES_VENTA DV
    JOIN REGISTRO_DE_VENTAS RV ON DV.REGISTRO_VENTA_ID = RV.ID
    JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
    WHERE RV.USUARIO_ID = ?
  ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuarioConFecha(
      int userId, String fechaHoy) async {
    final db = await _databaseHelper.database;

    // Consulta que selecciona solo los productos registrados en el mismo día
    // fechaHoy debe venir en formato YYYY-MM-DD
    return await db.rawQuery('''
    SELECT 
      DV.ID, 
      DV.REGISTRO_VENTA_ID, 
      DV.PRODUCTO_ID,
      DV.NOMBRE_PRODUCTO, 
      DV.CANTIDAD, 
      DV.TIPO_VENTA, 
      DV.PRECIO_VENTA, 
      DV.DEVOLUCION,
      RV.FECHA,
      RV.METODO_PAGO,
      P.Cantidad_Presentacion,
      P.Cantidad_Presentacion_blister
    FROM DETALLES_VENTA DV
    JOIN REGISTRO_DE_VENTAS RV ON DV.REGISTRO_VENTA_ID = RV.ID
    JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
    WHERE RV.USUARIO_ID = ? 
    AND RV.FECHA LIKE ?
    ORDER BY DV.ID DESC
  ''', [userId, '$fechaHoy%']);
  }

  // Función para obtener todos los detalles de venta por fecha (sin filtrar por usuario)
  Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorFecha(
      String fechaHoy) async {
    final db = await _databaseHelper.database;

    return await db.rawQuery('''
    SELECT 
      DV.ID, 
      DV.REGISTRO_VENTA_ID, 
      DV.PRODUCTO_ID,
      DV.NOMBRE_PRODUCTO, 
      DV.CANTIDAD, 
      DV.TIPO_VENTA, 
      DV.PRECIO_VENTA, 
      DV.DEVOLUCION,
      RV.FECHA,
      RV.METODO_PAGO,
      P.Cantidad_Presentacion,
      P.Cantidad_Presentacion_blister
    FROM DETALLES_VENTA DV
    JOIN REGISTRO_DE_VENTAS RV ON DV.REGISTRO_VENTA_ID = RV.ID
    JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
    WHERE RV.FECHA LIKE ?
    ORDER BY DV.ID DESC
  ''', ['$fechaHoy%']);
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuarioConFechaV02(
      int userId, String fechaInicio, String fechaFin) async {
    final db = await _databaseHelper.database;

    // Consulta que selecciona solo los productos registrados entre la fecha de inicio y la fecha final
    // fechaInicio y fechaFin deben venir en formato YYYY-MM-DD
    return await db.rawQuery('''
    SELECT 
      DV.ID, 
      DV.REGISTRO_VENTA_ID, 
      DV.PRODUCTO_ID,
      DV.NOMBRE_PRODUCTO, 
      DV.CANTIDAD, 
      DV.TIPO_VENTA, 
      DV.PRECIO_VENTA, 
      DV.DEVOLUCION,
      RV.FECHA,
      P.Cantidad_Presentacion,
      P.Cantidad_Presentacion_blister
    FROM DETALLES_VENTA DV
    JOIN REGISTRO_DE_VENTAS RV ON DV.REGISTRO_VENTA_ID = RV.ID
    JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
    WHERE RV.USUARIO_ID = ? 
    AND RV.FECHA BETWEEN ? AND ?
  ''', [userId, fechaInicio, fechaFin]);
  }

  // Nueva función para obtener tickets filtrados por fecha, hora y vendedor
  Future<List<Map<String, dynamic>>> obtenerTicketsConFiltros({
    required String fechaInicio,
    required String fechaFin,
    int? usuarioId,
    bool soloConDevolucion = false,
    String? productoBuscar,
  }) async {
    final db = await _databaseHelper.database;

    String subqueryDevolucion = '''
      (SELECT 1 FROM DETALLES_VENTA DV 
       WHERE DV.REGISTRO_VENTA_ID = RV.ID AND DV.DEVOLUCION = 'Si')
    ''';

    String query = '''
      SELECT RV.*, U.NOMBRE_VENDEDOR as NOMBRE_USUARIO,
        CASE WHEN EXISTS $subqueryDevolucion THEN 1 ELSE 0 END as TIENE_DEVOLUCION
      FROM REGISTRO_DE_VENTAS RV
      JOIN USUARIO U ON RV.USUARIO_ID = U.ID_USUARIO
      WHERE RV.FECHA BETWEEN ? AND ?
    ''';

    List<dynamic> args = [fechaInicio, fechaFin];

    if (usuarioId != null) {
      query += ' AND RV.USUARIO_ID = ?';
      args.add(usuarioId);
    }

    if (soloConDevolucion) {
      query += " AND EXISTS $subqueryDevolucion";
    }

    if (productoBuscar != null && productoBuscar.trim().isNotEmpty) {
      query += ''' AND EXISTS (
        SELECT 1 FROM DETALLES_VENTA DV2 
        WHERE DV2.REGISTRO_VENTA_ID = RV.ID 
          AND DV2.NOMBRE_PRODUCTO LIKE ?
      )''';
      args.add('%${productoBuscar.trim()}%');
    }

    query += ' ORDER BY RV.FECHA DESC';

    return await db.rawQuery(query, args);
  }

  // Obtener detalles específicos de un ticket
  Future<List<Map<String, dynamic>>> obtenerDetallesDeTicket(
      int registroVentaId) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT DV.*, P.Cantidad_Presentacion, P.Cantidad_Presentacion_blister
      FROM DETALLES_VENTA DV
      JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
      WHERE DV.REGISTRO_VENTA_ID = ?
    ''', [registroVentaId]);
  }

  // Marcar un detalle como devuelto
  Future<int> marcarDetalleComoDevuelto(int id) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'DETALLES_VENTA',
      {'DEVOLUCION': 'Si'},
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}
