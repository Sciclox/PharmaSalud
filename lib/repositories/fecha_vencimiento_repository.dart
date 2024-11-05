import 'package:pharma_salud/database_helper.dart';

class FechaVencimientoRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Insertar una nueva fecha de vencimiento
  Future<int> insertFechaVencimiento(int productoId, String fechaVencimiento, int cantidad) async {
    final db = await _databaseHelper.database;

    Map<String, dynamic> data = {
      'Producto_ID': productoId,
      'Fecha_Vencimiento': fechaVencimiento,
      'Cantidad': cantidad,
    };

    return await db.insert('FECHA_VENCIMIENTO', data);
  }

  // Obtener todas las fechas de vencimiento
  Future<List<Map<String, dynamic>>> getAllFechasVencimiento() async {
    final db = await _databaseHelper.database;

    return await db.query('FECHA_VENCIMIENTO');
  }

  // Obtener las fechas de vencimiento por producto ID
  Future<List<Map<String, dynamic>>> getFechasVencimientoByProductoId(int productoId) async {
    final db = await _databaseHelper.database;

    return await db.query(
      'FECHA_VENCIMIENTO',
      where: 'Producto_ID = ?',
      whereArgs: [productoId],
    );
  }

  // Actualizar una fecha de vencimiento
  Future<int> updateFechaVencimiento(int id, String fechaVencimiento, int cantidad) async {
    final db = await _databaseHelper.database;

    Map<String, dynamic> data = {
      'Fecha_Vencimiento': fechaVencimiento,
      'Cantidad': cantidad,
    };

    return await db.update(
      'FECHA_VENCIMIENTO',
      data,
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  // Eliminar fechas de vencimiento según el ID del producto
  Future<int> deleteFechaVencimientoPorProductoId(int productoId) async {
  final db = await _databaseHelper.database;

  return await db.delete(
    'FECHA_VENCIMIENTO',
    where: 'Producto_ID = ?',
    whereArgs: [productoId],
  );
  }

// Función para restar cantidad de las fechas de vencimiento
Future<void> restarCantidad(int productoId, int cantidadARestar) async {
  final db = await _databaseHelper.database;

  // Obtener las fechas de vencimiento del producto y ordenarlas por fecha
  final List<Map<String, dynamic>> fechasVencimiento = await db.query(
    'FECHA_VENCIMIENTO',
    where: 'Producto_ID = ?',
    whereArgs: [productoId],
    orderBy: 'Fecha_Vencimiento ASC', // Ordenar por fecha de vencimiento más cercana
  );

  // Verificar si no hay fechas de vencimiento
  if (fechasVencimiento.isEmpty) {
    print('No hay fechas de vencimiento para el producto con ID: $productoId');
    return; // No hay nada que restar
  }

  int cantidadRestante = cantidadARestar;

  // Recorremos las fechas de vencimiento para restar la cantidad
  for (var fecha in fechasVencimiento) {
    final int cantidadDisponible = fecha['Cantidad'];

    // Verificamos si la cantidad disponible es 0
    if (cantidadDisponible <= 0) {
      print('No hay cantidad disponible para la fecha de vencimiento ID: ${fecha['ID']}');
      continue; // Pasamos a la siguiente fecha de vencimiento
    }

    if (cantidadRestante <= 0) {
      // Ya no hay más cantidad por restar, salimos del loop
      break;
    }

    if (cantidadDisponible >= cantidadRestante) {
      // Si la cantidad disponible es suficiente, restamos y actualizamos
      final int nuevaCantidad = cantidadDisponible - cantidadRestante;

      await db.update(
        'FECHA_VENCIMIENTO',
        {'Cantidad': nuevaCantidad},
        where: 'ID = ?',
        whereArgs: [fecha['ID']],
      );

      cantidadRestante = 0; // Todo restado
    } else {
      // Si la cantidad disponible no es suficiente, restamos lo que queda y eliminamos el registro
      cantidadRestante -= cantidadDisponible;

      // Actualizamos la cantidad a 0 o eliminamos el registro (opcional)
      await db.delete(
        'FECHA_VENCIMIENTO',
        where: 'ID = ?',
        whereArgs: [fecha['ID']],
      );
    }
  }

  if (cantidadRestante > 0) {
    // Si aún queda cantidad sin restar, es posible que haya un problema de inventario
    print('No hay suficiente inventario para cubrir la cantidad solicitada');
    return; // O puedes lanzar una excepción si prefieres
  }
}

// Función para sumar cantidad a la fecha de vencimiento más cercana
Future<void> sumarCantidad(int productoId, int cantidadASumar) async {
  final db = await _databaseHelper.database;

  // Obtener las fechas de vencimiento del producto y ordenarlas por fecha (más cercana primero)
  final List<Map<String, dynamic>> fechasVencimiento = await db.query(
    'FECHA_VENCIMIENTO',
    where: 'Producto_ID = ?',
    whereArgs: [productoId],
    orderBy: 'Fecha_Vencimiento ASC', // Ordenar por fecha de vencimiento más cercana
    limit: 1, // Solo obtener la más cercana
  );

  // Verificar si hay fechas de vencimiento
  if (fechasVencimiento.isEmpty) {
    print('No hay fechas de vencimiento para el producto con ID: $productoId');
    return; // No hay nada que sumar
  }

  // Obtener la fecha más cercana
  final fechaMasCercana = fechasVencimiento.first;
  final int cantidadDisponible = fechaMasCercana['Cantidad'];

  // Sumar la cantidad a la fecha de vencimiento más cercana
  final int nuevaCantidad = cantidadDisponible + cantidadASumar;

  // Actualizar el registro en la base de datos
  await db.update(
    'FECHA_VENCIMIENTO',
    {'Cantidad': nuevaCantidad},
    where: 'ID = ?',
    whereArgs: [fechaMasCercana['ID']],
  );

  print('Se actualizó la cantidad en la fecha de vencimiento más cercana para el producto ID: $productoId. Nueva cantidad: $nuevaCantidad');
}

}
