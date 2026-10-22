import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

/// Utilidad para migrar datos desde el archivo AINV0102.DBF (sistema antiguo)
/// hacia la tabla PRODUCTO de la base de datos SQLite (botica.db).
class DbfMigrator {
  /// Migra los productos desde un archivo DBF a la base de datos SQLite.
  /// 
  /// [dbfFilePath] - Ruta completa al archivo AINV0102.DBF
  /// [onProgress] - Callback opcional para reportar progreso (registroActual, total)
  /// [soloConStock] - Si es true, solo migra productos con stock > 0
  /// 
  /// Retorna el número de productos migrados exitosamente.
  static Future<int> migrarProductosDesdeDbf({
    required String dbfFilePath,
    Function(int current, int total, String productName)? onProgress,
    bool soloConStock = false,
  }) async {
    final file = File(dbfFilePath);
    if (!await file.exists()) {
      throw Exception('Archivo DBF no encontrado: $dbfFilePath');
    }

    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes);

    // Leer encabezado DBF
    final numRecords = data.getUint32(4, Endian.little);
    final headerSize = data.getUint16(8, Endian.little);
    final recordSize = data.getUint16(10, Endian.little);

    // Leer estructura de campos
    final fields = _readFieldDescriptors(bytes, headerSize);

    // Obtener la base de datos
    final db = await DatabaseHelper().database;

    int migrados = 0;
    int omitidos = 0;
    int errores = 0;
    var recordOffset = headerSize;

    // Usar batch para inserción masiva (más rápido)
    final batch = db.batch();

    for (var i = 0; i < numRecords; i++) {
      // Verificar si el registro está eliminado
      if (bytes[recordOffset] == 0x2A) {
        recordOffset += recordSize;
        omitidos++;
        continue;
      }

      // Leer todos los campos del registro
      final record = _readRecord(bytes, recordOffset, fields);
      recordOffset += recordSize;

      // Filtrar solo almacén 1
      final almacen = record['A_ALMAC']?.trim() ?? '';
      if (almacen != '1') {
        omitidos++;
        continue;
      }

      // Extraer valores relevantes
      final nombre = record['A_NOM_CO']?.trim() ?? '';
      
      // Ignorar registros sin nombre
      if (nombre.isEmpty) {
        omitidos++;
        continue;
      }

      final stockCaja = _parseInt(record['STOCKCAJA']);
      final stockUnidad = _parseInt(record['STOCKUNIDA']);
      final unidad = _parseInt(record['UNIDAD']); // unidades por caja

      // Si solo queremos productos con stock
      if (soloConStock && stockCaja <= 0 && stockUnidad <= 0) {
        omitidos++;
        continue;
      }

      // Calcular cantidad total (cajas * unidades_por_caja + unidades sueltas)
      final cantidadTotal = (unidad > 0) 
          ? (stockCaja * unidad) + stockUnidad
          : stockCaja + stockUnidad;

      // Tipo de producto basado en la cantidad de presentación
      String tipoProducto;
      if (unidad > 1) {
        tipoProducto = 'Caja';
      } else {
        tipoProducto = 'Unidad';
      }

      // Fecha de creación
      final fechaCreacion = _formatDate(record['A_FEC_CRE']?.trim() ?? '');

      double precioCaja = _parseDouble(record['A_PRE_PUB']); // Precio público por caja
      double precioUnidad = _parseDouble(record['A_PRE_UNI']); // Precio por unidad
      final double costoCaja = 0.0; // Puesto en 0 por configuración
      final double costoUnidad = 0.0; // Puesto en 0 por configuración
      final stockMinimo = _parseInt(record['STOCKMINI']);

      // Si el tipo de producto es "Unidad", el precio que venía para la caja pasa a ser el de la unidad.
      if (tipoProducto == 'Unidad') {
        precioUnidad = precioCaja;
        precioCaja = 0.0;
      }

      // Determinar Blister_SiNo (0 = No, 1 = Sí)
      // Forzado a 0 por configuración
      final int blisterSiNo = 0;

      try {
        batch.insert('PRODUCTO', {
          'Nombre_Producto': nombre,
          'Fecha_Creacion': fechaCreacion,
          'Cantidad_Presentacion': unidad > 0 ? unidad : null,
          'Cantidad_Presentacion_blister': null, // No hay equivalente directo en el DBF
          'Cantidad_Total': cantidadTotal,
          'Tipo_Producto': tipoProducto,
          'Precio_Unidad': precioUnidad,
          'Precio_Caja': precioCaja,
          'Precio_Blister': 0.0,
          'Costo_Unidad': costoUnidad,
          'Costo_Caja': costoCaja,
          'Stock_Minimo': stockMinimo,
          'Blister_SiNo': blisterSiNo,
          'Codigo_Barra': '',
        });
        migrados++;
      } catch (e) {
        errores++;
        print('Error migrando "$nombre": $e');
      }

      // Reportar progreso
      if (onProgress != null) {
        onProgress(i + 1, numRecords, nombre);
      }
    }

    // Ejecutar todas las inserciones en batch
    await batch.commit(noResult: true);

    print('=== Migración completada ===');
    print('Migrados: $migrados');
    print('Omitidos: $omitidos');
    print('Errores: $errores');
    print('Total procesados: $numRecords');

    return migrados;
  }

  /// Lee los descriptores de campos del encabezado DBF.
  static List<Map<String, dynamic>> _readFieldDescriptors(
      List<int> bytes, int headerSize) {
    final fields = <Map<String, dynamic>>[];
    var offset = 32;

    while (offset < headerSize - 1 && bytes[offset] != 0x0D) {
      final nameBytes = bytes.sublist(offset, offset + 11);
      int nameEnd = 11;
      for (int i = 0; i < 11; i++) {
        if (nameBytes[i] == 0) {
          nameEnd = i;
          break;
        }
      }
      fields.add({
        'name': String.fromCharCodes(nameBytes.sublist(0, nameEnd)),
        'type': String.fromCharCode(bytes[offset + 11]),
        'length': bytes[offset + 16],
      });
      offset += 32;
    }
    return fields;
  }

  /// Lee un registro del DBF y retorna un mapa campo -> valor.
  static Map<String, String> _readRecord(
      List<int> bytes, int recordOffset, List<Map<String, dynamic>> fields) {
    final record = <String, String>{};
    var fieldOffset = recordOffset + 1; // +1 por el flag de eliminación

    for (final field in fields) {
      final len = field['length'] as int;
      final endIndex = fieldOffset + len;
      
      // Asegurarse de no sobrepasar el archivo
      if (endIndex > bytes.length) break;

      try {
        record[field['name'] as String] =
            latin1.decode(bytes.sublist(fieldOffset, endIndex)).trim();
      } catch (e) {
        record[field['name'] as String] = '';
      }
      fieldOffset = endIndex;
    }
    return record;
  }

  /// Parsea un string a int, retornando 0 si falla.
  static int _parseInt(String? value) {
    if (value == null || value.isEmpty) return 0;
    return int.tryParse(value.trim()) ?? 0;
  }

  /// Parsea un string a double, retornando 0.0 si falla.
  static double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    return double.tryParse(value.trim()) ?? 0.0;
  }

  /// Convierte fecha DBF (YYYYMMDD) a formato ISO 8601 (YYYY-MM-DD).
  static String _formatDate(String dbfDate) {
    if (dbfDate.length == 8) {
      final year = dbfDate.substring(0, 4);
      final month = dbfDate.substring(4, 6);
      final day = dbfDate.substring(6, 8);
      return '$year-$month-$day';
    }
    // Si no tiene fecha válida, usar fecha actual
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }



  /// Cuenta cuántos registros tiene el archivo DBF (solo activos).
  static Future<Map<String, int>> contarRegistrosDbf(String dbfFilePath) async {
    final file = File(dbfFilePath);
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado: $dbfFilePath');
    }

    final bytes = await file.readAsBytes();
    final data = ByteData.sublistView(bytes);
    final numRecords = data.getUint32(4, Endian.little);
    final headerSize = data.getUint16(8, Endian.little);
    final recordSize = data.getUint16(10, Endian.little);
    final fields = _readFieldDescriptors(bytes, headerSize);

    int activos = 0;
    int eliminados = 0;
    int conStock = 0;
    int sinNombre = 0;
    int otroAlmacen = 0;
    var recordOffset = headerSize;

    for (var i = 0; i < numRecords; i++) {
      if (bytes[recordOffset] == 0x2A) {
        eliminados++;
        recordOffset += recordSize;
        continue;
      }

      final record = _readRecord(bytes, recordOffset, fields);
      final almacen = record['A_ALMAC']?.trim() ?? '';
      if (almacen != '1') {
        otroAlmacen++;
        recordOffset += recordSize;
        continue;
      }
      final nombre = record['A_NOM_CO']?.trim() ?? '';
      if (nombre.isEmpty) {
        sinNombre++;
      } else {
        activos++;
        final stockCaja = _parseInt(record['STOCKCAJA']);
        final stockUnidad = _parseInt(record['STOCKUNIDA']);
        if (stockCaja > 0 || stockUnidad > 0) conStock++;
      }
      recordOffset += recordSize;
    }

    return {
      'total': numRecords,
      'activos': activos,
      'eliminados': eliminados,
      'sinNombre': sinNombre,
      'conStock': conStock,
      'otroAlmacen': otroAlmacen,
    };
  }
}
