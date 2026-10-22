import 'package:pharma_salud/database/database_helper.dart';

class CartItemRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Obtener todos los productos del carrito con los detalles del producto
  Future<List<Map<String, dynamic>>> getCartItems(int userId) async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT c.ID, c.PRODUCTO_ID, c.REGISTRO_VENTA_ID, c.CANTIDAD, c.PRECIO_VENTA, c.TIPO_VENTA, c.FECHA,c.ID_KARDEX,c.ID_USUARIO,
             p.Nombre_Producto, p.Precio_Unidad, p.Precio_Caja, p.Precio_Blister, p.Cantidad_Total, p.Tipo_Producto,
             p.Cantidad_Presentacion, p.Cantidad_Presentacion_blister,
             p.RECETA_MEDICA
      FROM CARRITO_DE_VENTAS c
      INNER JOIN PRODUCTO p ON c.PRODUCTO_ID = p.ID
      WHERE c.ID_USUARIO = ?
    ''', [userId]);
  }

  // Obtener el conteo total de items distintos en el carrito
  Future<int> getCartItemCount(int userId) async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as total FROM CARRITO_DE_VENTAS WHERE ID_USUARIO = ?
    ''', [userId]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // Agregar un producto al carrito
  Future<void> addItemToCart(Map<String, dynamic> cartItem) async {
    final db = await _databaseHelper.database;
    cartItem['ID_KARDEX'] = cartItem['ID_KARDEX'] ?? 0;
    if (!cartItem.containsKey('REGISTRO_VENTA_ID') ||
        !cartItem.containsKey('PRODUCTO_ID') ||
        !cartItem.containsKey('CANTIDAD') ||
        !cartItem.containsKey('PRECIO_VENTA') ||
        !cartItem.containsKey('FECHA') ||
        !cartItem.containsKey('TIPO_VENTA') ||
        !cartItem.containsKey('ID_USUARIO')) {
      throw Exception(
          "Faltan campos obligatorios para agregar un producto al carrito");
    }
    await db.insert('CARRITO_DE_VENTAS', cartItem);
  }

  // Obtener la cantidad total de unidades comprometidas en el carrito de un usuario agrupadas por PRODUCTO_ID
  Future<Map<int, int>> getCantidadesEnCarritoPorUsuario(int userId) async {
    final db = await _databaseHelper.database;
    final items = await db.rawQuery('''
      SELECT c.PRODUCTO_ID, c.CANTIDAD, c.TIPO_VENTA,
             p.Cantidad_Presentacion, p.Cantidad_Presentacion_blister
      FROM CARRITO_DE_VENTAS c
      INNER JOIN PRODUCTO p ON c.PRODUCTO_ID = p.ID
      WHERE c.ID_USUARIO = ?
    ''', [userId]);

    final Map<int, int> resultado = {};
    for (var row in items) {
      final int prodId = (row['PRODUCTO_ID'] as num?)?.toInt() ?? 0;
      final int cantidad = (row['CANTIDAD'] as num?)?.toInt() ?? 0;
      final String tipoVenta = row['TIPO_VENTA'] as String? ?? 'Venta por unidad';
      final int presCaja = (row['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
      final int presBlister = (row['Cantidad_Presentacion_blister'] as num?)?.toInt() ?? 1;

      int unidadesItem = cantidad;
      if (tipoVenta == 'Venta por caja') {
        unidadesItem = cantidad * (presCaja > 0 ? presCaja : 1);
      } else if (tipoVenta == 'Venta por blister') {
        unidadesItem = cantidad * (presBlister > 0 ? presBlister : 1);
      }

      resultado[prodId] = (resultado[prodId] ?? 0) + unidadesItem;
    }
    return resultado;
  }

  // Obtener las unidades comprometidas de un producto específico en el carrito del usuario
  Future<int> getUnidadesEnCarritoDeProducto(int productoId, int userId) async {
    final mapa = await getCantidadesEnCarritoPorUsuario(userId);
    return mapa[productoId] ?? 0;
  }

  // Actualizar un producto en el carrito
  Future<void> updateCartItem(Map<String, dynamic> cartItem) async {
    final db = await _databaseHelper.database;
    await db.update(
      'CARRITO_DE_VENTAS',
      cartItem,
      where: 'ID = ?',
      whereArgs: [cartItem['ID']],
    );
  }

  // Eliminar un producto del carrito por ID
  Future<void> removeItemFromCart(int id) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'CARRITO_DE_VENTAS',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

// Limpiar solo los productos del carrito del vendedor actual
  Future<void> clearCart(int usuarioId) async {
    final db = await _databaseHelper.database;
    await db.delete(
      'CARRITO_DE_VENTAS',
      where: 'ID_USUARIO = ?',
      whereArgs: [usuarioId],
    );
  }

  // Actualizar solo la cantidad de un producto en el carrito
  Future<void> updateQuantity(int id, double nuevaCantidad) async {
    final db = await _databaseHelper.database;
    await db.update(
      'CARRITO_DE_VENTAS',
      {'CANTIDAD': nuevaCantidad},
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  // Actualizar tipo de venta, cantidad y precio de un producto del carrito
  Future<void> actualizarItemDelCarrito(
    int id, {
    required String tipoVenta,
    required int cantidad,
    required double precioVenta,
  }) async {
    final db = await _databaseHelper.database;

    await db.update(
      'CARRITO_DE_VENTAS',
      {
        'TIPO_VENTA': tipoVenta,
        'CANTIDAD': cantidad,
        'PRECIO_VENTA': precioVenta,
      },
      where: 'ID = ?',
      whereArgs: [id],
    );
  }
}
