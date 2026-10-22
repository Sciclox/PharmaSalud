import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  // Inicializamos FFI para poder acceder a SQLite desde consola
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  
  // Archivo de SQLite
  final sqlitePath = r'c:\Users\Lenovo\OneDrive\Documentos\botica.db';
  print('Abriendo base de datos SQLite en: $sqlitePath');
  final db = await databaseFactory.openDatabase(sqlitePath);
  
  // Archivo DBF
  final dbfFilePath = r'c:\Users\Lenovo\OneDrive\Documentos\RQCSOFT\FARMACIA\CDX\AINV0102.DBF';
  print('Leyendo archivo DBF de: $dbfFilePath');
  
  final file = File(dbfFilePath);
  if (!file.existsSync()) {
    print('! Error: El archivo DBF no existe.');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  // Leer encabezado DBF
  final numRecords = data.getUint32(4, Endian.little);
  final headerSize = data.getUint16(8, Endian.little);
  final recordSize = data.getUint16(10, Endian.little);

  // Leer estructura de campos
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
      'length': bytes[offset + 16],
    });
    offset += 32;
  }

  print('Estructura leída. Procesando $numRecords registros...');

  // Limpiar la tabla antes de la inserción opcionalmente
  // await db.delete('PRODUCTO');
  
  final batch = db.batch();
  int migrados = 0;
  int omitidos = 0;
  int errores = 0;
  var recordOffset = headerSize;

  for (var i = 0; i < numRecords; i++) {
    // Verificar si el registro está eliminado
    if (bytes[recordOffset] == 0x2A) {
      recordOffset += recordSize;
      omitidos++;
      continue;
    }

    // Leer el registro
    final record = <String, String>{};
    var fo = recordOffset + 1;
    for (final field in fields) {
      final len = field['length'] as int;
      final endIndex = fo + len;
      if (endIndex > bytes.length) break;
      try {
        record[field['name'] as String] = latin1.decode(bytes.sublist(fo, endIndex)).trim();
      } catch (e) {
        record[field['name'] as String] = '';
      }
      fo = endIndex;
    }
    recordOffset += recordSize;

    // Filtrar solo almacén 1
    final almacen = record['A_ALMAC']?.trim() ?? '';
    if (almacen != '1') {
      omitidos++;
      continue;
    }

    final nombre = record['A_NOM_CO'] ?? '';
    if (nombre.isEmpty) {
      omitidos++;
      continue;
    }

    final stockCaja = int.tryParse(record['STOCKCAJA'] ?? '0') ?? 0;
    final stockUnidad = int.tryParse(record['STOCKUNIDA'] ?? '0') ?? 0;
    final unidad = int.tryParse(record['UNIDAD'] ?? '0') ?? 0;

    final cantidadTotal = (unidad > 0) ? (stockCaja * unidad) + stockUnidad : stockCaja + stockUnidad;
    if (cantidadTotal <= 0) {
      omitidos++;
      continue;
    }

    final uniDes = record['A_UNI_DES'] ?? '';
    final tipoStr = record['TIPO'] ?? '';
    String tipoProducto = 'Otros';
    
    switch (tipoStr.toUpperCase()) {
      case 'MED': tipoProducto = 'Medicamento'; break;
      case 'PER': tipoProducto = 'Perfumería'; break;
      case 'MIS': tipoProducto = 'Miscelánea'; break;
      case 'GAL': tipoProducto = 'Galénico'; break;
      default:
        switch (uniDes.toUpperCase()) {
          case 'TAB': case 'CAP': case 'GRA': case 'TUB': case 'CRE': case 'JBE':
          case 'JRB': case 'SOL': case 'GTS': case 'AMP': case 'INY': case 'SUP':
          case 'OVU': tipoProducto = 'Medicamento'; break;
          default: tipoProducto = tipoStr.isNotEmpty ? tipoStr : 'Otros';
        }
    }

    // Fecha
    final dbfDate = record['A_FEC_CRE'] ?? '';
    String fechaCreacion;
    if (dbfDate.length == 8) {
      fechaCreacion = '${dbfDate.substring(0,4)}-${dbfDate.substring(4,6)}-${dbfDate.substring(6,8)}';
    } else {
      final now = DateTime.now();
      fechaCreacion = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    }

    final precioCaja = double.tryParse(record['A_PRE_PUB'] ?? '0.0') ?? 0.0;
    final precioUnidad = double.tryParse(record['A_PRE_UNI'] ?? '0.0') ?? 0.0;
    final costoCaja = double.tryParse(record['A_COS_REP'] ?? '0.0') ?? 0.0;
    final costoUnidad = double.tryParse(record['A_COST_PRO'] ?? '0.0') ?? 0.0;
    final stockMinimo = int.tryParse(record['STOCKMINI'] ?? '0') ?? 0;
    final blisterSiNo = (precioUnidad > 0) ? 1 : 0;

    try {
      batch.insert('PRODUCTO', {
        'Nombre_Producto': nombre,
        'Fecha_Creacion': fechaCreacion,
        'Cantidad_Presentacion': unidad > 0 ? unidad : null,
        'Cantidad_Presentacion_blister': 0, // Ajustar según DB actual
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
      if (migrados % 1000 == 0) {
        print('... $migrados productos procesados');
      }
    } catch (e) {
      errores++;
      print('Error en $nombre: $e');
    }
  }

  print('Ejecutando inserción en SQLite para $migrados productos...');
  await batch.commit(noResult: true);
  
  print('=== MIGRACIÓN FINALIZADA ===');
  print('Migrados (Con Stock): $migrados');
  print('Omitidos (Sin Nombre/Stock): $omitidos');
  print('Errores: $errores');
  print('Total procesados: $numRecords');
  
  await db.close();
}
