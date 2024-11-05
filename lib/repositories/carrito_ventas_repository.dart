import 'package:pharma_salud/database_helper.dart';

class CartItemRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Obtener todos los productos del carrito con los detalles del producto
  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT c.ID, c.PRODUCTO_ID, c.REGISTRO_VENTA_ID, c.CANTIDAD, c.PRECIO_VENTA, c.TIPO_VENTA, c.FECHA,
             p.Nombre_Producto, p.Precio_Unidad, p.Tipo_Producto,
             p.Cantidad_Presentacion, p.Cantidad_Presentacion_blister
      FROM CARRITO_DE_VENTAS c
      INNER JOIN PRODUCTO p ON c.PRODUCTO_ID = p.ID
    ''');
  }

  // Agregar un producto al carrito
  Future<void> addItemToCart(Map<String, dynamic> cartItem) async {
    final db = await _databaseHelper.database;
    if (!cartItem.containsKey('REGISTRO_VENTA_ID') || 
        !cartItem.containsKey('PRODUCTO_ID') ||
        !cartItem.containsKey('CANTIDAD') || 
        !cartItem.containsKey('PRECIO_VENTA') || 
        !cartItem.containsKey('FECHA') || 
        !cartItem.containsKey('TIPO_VENTA')) {
      throw Exception("Faltan campos obligatorios para agregar un producto al carrito");
    }
    await db.insert('CARRITO_DE_VENTAS', cartItem);
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

  // Limpiar todos los productos del carrito
  Future<void> clearCart() async {
    final db = await _databaseHelper.database;
    await db.delete('CARRITO_DE_VENTAS');
  }
}
