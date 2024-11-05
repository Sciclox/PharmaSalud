import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fast_csv/fast_csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_salud/database_helper.dart';

class ProductoRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

// Crear un nuevo producto
Future<int?> createProducto(Map<String, dynamic> producto) async {
  final db = await _databaseHelper.database;
  try {
    // Inserta el producto y obtiene el ID
    final productoId = await db.insert('PRODUCTO', producto);
    return productoId; // Retorna el ID del producto creado
  } catch (e) {
    // Manejo de errores
    return null; // Retorna null si hubo un error
  }
}


  // Obtener todos los productos
  Future<List<Map<String, dynamic>>> getAllProductos() async {
    final db = await _databaseHelper.database;
    return await db.query('PRODUCTO');
  }

  // Obtener todos los productos con sus fechas de vencimiento
  Future<List<Map<String, dynamic>>> getAllProductosFechaVencimiento() async {
    final db = await _databaseHelper.database;

    final List<Map<String, dynamic>> productos = await db.rawQuery('''
     SELECT p.*, v.Fecha_Vencimiento, v.Cantidad
     FROM PRODUCTO p
     LEFT JOIN FECHA_VENCIMIENTO v ON p.ID = v.Producto_ID
     ''');

    return productos;
  }

  // Obtener un producto por ID
  Future<Map<String, dynamic>?> getProductoById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> result = await db.query('PRODUCTO', where: 'ID = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  // Actualizar un producto
  Future<int> updateProducto(Map<String, dynamic> producto) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'PRODUCTO',
      producto,
      where: 'ID = ?',
      whereArgs: [producto['ID']],
    );
  }

  // Eliminar un producto
  Future<int> deleteProducto(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('PRODUCTO', where: 'ID = ?', whereArgs: [id]);
  }

// Nuevo método para buscar productos por nombre
Future<List<Map<String, dynamic>>> searchProductos(String query) async {
  final db = await _databaseHelper.database;
  try {
    final List<Map<String, dynamic>> productos = await db.query(
      'PRODUCTO', // Asegúrate de que el nombre de la tabla sea correcto
      where: 'Nombre_Producto LIKE ?', // Usa el nombre de la columna correcto
      whereArgs: ['%$query%'], // Uso de wildcards para buscar en el nombre
    );

    return productos;
  } catch (e) {
    // Manejo de errores en caso de que falle la consulta
    return []; // Retorna una lista vacía en caso de error
  }
}

  // Nuevo método para exportar productos a CSV
  Future<void> exportProductosToCSV() async {
    // Obtener todos los productos
    List<Map<String, dynamic>> productos = await getAllProductos();

    // Convertir la lista de productos a formato CSV
    List<List<dynamic>> rows = [];
    rows.add(["ID", "Nombre Producto", "Tipo Producto", "Cantidad Total", "Precio Caja", "Precio Unidad","Cantidad Presentacion"]); // Encabezados

    for (var producto in productos) {
      rows.add([
        producto['Nombre_Producto'],
        producto['Tipo_Producto'],
        producto['Cantidad_Total'],
        producto['Precio_Caja'],
        producto['Precio_Unidad'],
        producto['Cantidad_Presentacion'],
      ]);
    }

    // Usar file_picker para seleccionar la ubicación de guardado
    String? path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar CSV',
      fileName: 'productos.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (path != null) {
      // Escribir el archivo CSV
      File file = File(path);
      String csvData = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csvData);

      // Aquí puedes manejar cualquier acción después de la exportación, como mostrar un mensaje de éxito
      print('Productos exportados a $path');
    } else {
      // Manejar el caso en que el usuario cancela la selección
      print('Exportación cancelada');
    }
  }

Future<void> importProductosFromCSV() async {
  // Usar file_picker para seleccionar el archivo CSV
  String? path = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  ).then((result) => result?.paths.first);

  if (path != null) {
    // Leer el archivo CSV
    File file = File(path);
    final csvString = await file.readAsString();

    // Convertir el CSV a una lista de listas usando fast_csv
    List<List<dynamic>> rows = parse(csvString).toList();

    // Obtener la fecha actual
    String fechaCreacion = DateTime.now().toIso8601String();

    // Recorrer las filas (saltando la primera fila que son los encabezados)
    for (var i = 1; i < rows.length; i++) {
      var row = rows[i];

      // Verifica que la fila tenga suficientes columnas
      if (row.length < 6) {
        print('Fila $i tiene menos de 6 columnas. Saltando...');
        continue;
      }

      // Crear el mapa del producto
      Map<String, dynamic> producto = {
        'Nombre_Producto': row[0],
        'Tipo_Producto': row[1],
        'Cantidad_Total': row[2],
        'Precio_Caja': row[3],
        'Precio_Unidad': row[4],
        'Cantidad_Presentacion': row[5],
        'Stock_Minimo': 0,
        'Fecha_Creacion': fechaCreacion, // Añadir la fecha de creación
      };

      // Insertar el producto en la base de datos
      await createProducto(producto); // Método existente para crear productos
    }

    print('Productos importados desde $path');
  } else {
    // Manejar el caso en que el usuario cancela la selección
    print('Importación cancelada');
  }
}

Future<int> deleteAllProductos() async {
  final db = await _databaseHelper.database;
  try {
    // Eliminar todos los productos
    int count = await db.delete('PRODUCTO');
    print('$count productos eliminados de la base de datos.');
    return count; // Devuelve la cantidad de productos eliminados
  } catch (e) {
    // Manejo de errores en caso de que falle la eliminación
    print('Error al eliminar todos los productos: $e');
    return 0; // Devuelve 0 si hubo un error
  }
}

   Future<void> descontarCantidadTotal(int productoId, int cantidadVendida) async {
    final db = await _databaseHelper.database;

    // Obtener el producto por su ID
    final producto = (await db.query(
      'PRODUCTO',
      where: 'ID = ?',
      whereArgs: [productoId],
    )).first;

    // Verificar si Cantidad_Total es null y hacer un cast a int
    int cantidadTotalActual = (producto['Cantidad_Total'] as int?) ?? 0;

    // Descontar la cantidad vendida
    int nuevaCantidadTotal = cantidadTotalActual - cantidadVendida;

    // Actualizar el producto con la nueva cantidad
    await db.update(
      'PRODUCTO',
      {'Cantidad_Total': nuevaCantidadTotal},
      where: 'ID = ?',
      whereArgs: [productoId],
    );
  }

     Future<void> aumentarCantidadTotal(int productoId, int cantidadVendida) async {
    final db = await _databaseHelper.database;

    // Obtener el producto por su ID
    final producto = (await db.query(
      'PRODUCTO',
      where: 'ID = ?',
      whereArgs: [productoId],
    )).first;

    // Verificar si Cantidad_Total es null y hacer un cast a int
    int cantidadTotalActual = (producto['Cantidad_Total'] as int?) ?? 0;

    // Descontar la cantidad vendida
    int nuevaCantidadTotal = cantidadTotalActual + cantidadVendida;

    // Actualizar el producto con la nueva cantidad
    await db.update(
      'PRODUCTO',
      {'Cantidad_Total': nuevaCantidadTotal},
      where: 'ID = ?',
      whereArgs: [productoId],
    );
  }


// Función para obtener productos cuya cantidad total es igual o menor al stock mínimo y exportar sus nombres a CSV
Future<void> exportarProductosStockBajoToCSV() async {
  // Obtener la instancia de la base de datos
  final db = await _databaseHelper.database;

  // Realizar la consulta SQL para obtener solo los nombres de los productos con bajo stock
  final List<Map<String, dynamic>> productos = await db.query(
    'PRODUCTO',
    columns: ['Nombre_Producto'], // Solo obtener el campo 'Nombre_Producto'
    where: 'Cantidad_Total <= Stock_Minimo', // Condición para el stock mínimo
  );

  // Preparar el contenido del CSV
  List<List<dynamic>> rows = [];
  rows.add(['Nombre del Producto']); // Añadir encabezado

  // Añadir solo los nombres de los productos al archivo CSV
  for (var producto in productos) {
    rows.add([producto['Nombre_Producto']]);
  }

  // Usar file_picker para seleccionar la ubicación de guardado
  String? path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar CSV',
    fileName: 'productos_bajo_stock.csv',
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );

  if (path != null) {
    // Escribir el archivo CSV
    String csvData = const ListToCsvConverter().convert(rows);
    File file = File(path);
    await file.writeAsString(csvData);

    // Aquí puedes manejar cualquier acción después de la exportación, como mostrar un mensaje de éxito
    print('Archivo CSV guardado en: $path');
  } else {
    // Manejar el caso en que el usuario cancela la selección
    print('Exportación cancelada');
  }
}


}

// Función para exportar solo los nombres de los productos con bajo stock a un archivo CSV
Future<void> exportarNombresProductosBajoStockCSV(List<Map<String, dynamic>> productos) async {
  // Obtener el directorio de documentos del usuario
  Directory? directory = await getApplicationDocumentsDirectory();
  String outputPath = '${directory.path}/productos_bajo_stock.csv';

  // Crear el contenido del archivo CSV
  StringBuffer csvContent = StringBuffer();

  // Añadir encabezado
  csvContent.writeln('Nombre del Producto');

  // Añadir solo los nombres de los productos al archivo CSV
  for (var producto in productos) {
    csvContent.writeln('${producto['Nombre']}');
  }

  // Guardar el archivo CSV en el directorio de documentos
  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(csvContent.toString());

  print("Archivo CSV guardado en: $outputPath");
}


