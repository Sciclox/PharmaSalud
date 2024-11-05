import 'package:pharma_salud/database_helper.dart';

class RegistroVentasRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Función para agregar un nuevo registro de venta
  Future<int> agregarRegistroVenta(Map<String, dynamic> registroVenta) async {
    final db = await _databaseHelper.database;
    return await db.insert('REGISTRO_DE_VENTAS', {
      'FECHA': registroVenta['FECHA'],
      'TOTAL': registroVenta['TOTAL'],
      'USUARIO_ID': registroVenta['USUARIO_ID'],
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
    final List<Map<String, dynamic>> detalles = await db.query('DETALLES_VENTA');
    return detalles;
   }

   // Función para obtener todos los detalles de venta según el id del usuario
Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuario(int userId) async {
  final db = await _databaseHelper.database;
  final List<Map<String, dynamic>> detalles = await db.query(
    'DETALLES_VENTA',
    where: 'USUARIO_ID = ?',  // Cambiado a USUARIO_ID
    whereArgs: [userId],  // Pasar el userId como argumento
  );
  return detalles;
}

Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuarioConFecha(int userId, String fechaHoy) async {
  final db = await _databaseHelper.database;

  // Consulta que selecciona solo los productos registrados en el mismo día
  return await db.rawQuery('''
    SELECT * FROM DETALLES_VENTA 
    WHERE USUARIO_ID = ? 
    AND SUBSTR(FECHA, 1, 10) = ?
  ''', [userId, fechaHoy]);
}

Future<List<Map<String, dynamic>>> obtenerDetallesVentasPorUsuarioConFechaV02(int userId, String fechaInicio, String fechaFin) async {
  final db = await _databaseHelper.database;

  // Consulta que selecciona solo los productos registrados entre la fecha de inicio y la fecha final
  return await db.rawQuery('''
    SELECT * FROM DETALLES_VENTA 
    WHERE USUARIO_ID = ? 
    AND SUBSTR(FECHA, 1, 10) BETWEEN ? AND ?
  ''', [userId, fechaInicio, fechaFin]);
}
  }

