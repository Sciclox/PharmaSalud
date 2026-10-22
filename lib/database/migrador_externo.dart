import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  
  // RUTA DE DESTINO PARA LA BASE DE DATOS SQLITE (Puedes cambiar este nombre)
  final sqlitePath = r'E:\Script\botica_migrada.db';
  
  // RUTA DEL ARCHIVO DBF DE ORIGEN (Asegúrate de poner tu archivo AINV0102.DBF en esta carpeta)
  final dbfFilePath = r'E:\Script\AINV0102.DBF';
  
  print('\n-----------------------------------------');
  print('>>> INICIANDO MIGRACIÓN PERSONALIZADA <<<');
  print('-----------------------------------------');
  print('Origen DBF: $dbfFilePath');
  print('Destino SQLite: $sqlitePath');

  final dbfFile = File(dbfFilePath);
  if (!dbfFile.existsSync()) {
    print('\n[ERROR] No se encontró el archivo AINV0102.DBF en la ruta: $dbfFilePath');
    print('Por favor, copia el archivo DBF a esa carpeta antes de ejecutar.');
    return;
  }

  // Verificar/Crear carpeta de destino si no existe
  final targetDir = Directory(r'E:\Script');
  if (!targetDir.existsSync()) {
    print('Creando carpeta E:\\Script...');
    targetDir.createSync(recursive: true);
  }

  // Si ya existe la DB la borramos para que sea una migración limpia
  final fileDb = File(sqlitePath);
  if (fileDb.existsSync()) {
    print('Borrando base de datos anterior...');
    fileDb.deleteSync();
  }
  
  print('Creando tablas de sistema...');
  final db = await databaseFactory.openDatabase(
    sqlitePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE PRODUCTO (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Nombre_Producto TEXT NOT NULL,
          Fecha_Creacion TEXT NOT NULL,
          Cantidad_Presentacion INTEGER,
          Cantidad_Presentacion_blister INTEGER,
          Cantidad_Total INTEGER,
          Tipo_Producto TEXT NOT NULL,
          Precio_Unidad REAL,
          Precio_Caja REAL,
          Precio_Blister REAL,
          Costo_Unidad REAL,
          Costo_Caja REAL,
          Stock_Minimo INTEGER,
          Blister_SiNo INTEGER,
          Codigo_Barra TEXT
        )''');
        
        // Tabla de usuarios básica para que la app funcione
        await db.execute('''CREATE TABLE USUARIO (
          ID_USUARIO INTEGER PRIMARY KEY AUTOINCREMENT,
          NOMBRE_USUARIO TEXT NOT NULL,
          NOMBRE_VENDEDOR TEXT NOT NULL,
          CLAVE TEXT NOT NULL,
          ROL TEXT NOT NULL,
          GENERO TEXT NOT NULL,
          ESTADO TEXT NOT NULL DEFAULT 'Activo'
        )''');

        await db.insert('USUARIO', {
          'NOMBRE_USUARIO': 'admin',
          'NOMBRE_VENDEDOR': 'Administrador Principal',
          'CLAVE': 'kevin745',
          'ROL': 'Administrador',
          'GENERO': 'Masculino',
          'ESTADO': 'Activo',
        });
      },
    ),
  );
  
  print('Leyendo datos del archivo DBF...');
  final bytes = dbfFile.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  final numRecords = data.getUint32(4, Endian.little);
  final headerSize = data.getUint16(8, Endian.little);
  final recordSize = data.getUint16(10, Endian.little);

  final fields = <Map<String, dynamic>>[];
  var offset = 32;
  while (offset < headerSize - 1 && bytes[offset] != 0x0D) {
    final nameBytes = bytes.sublist(offset, offset + 11);
    int nameEnd = 11;
    for (int i = 0; i < 11; i++) {
      if (nameBytes[i] == 0) { nameEnd = i; break; }
    }
    fields.add({
      'name': String.fromCharCodes(nameBytes.sublist(0, nameEnd)),
      'length': bytes[offset + 16],
    });
    offset += 32;
  }

  final batch = db.batch();
  int migrados = 0;
  var recordOffset = headerSize;

  for (var i = 0; i < numRecords; i++) {
    if (bytes[recordOffset] == 0x2A) {
      recordOffset += recordSize;
      continue;
    }

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
    if (almacen != '1') continue;

    final nombre = record['A_NOM_CO'] ?? '';
    if (nombre.isEmpty) continue;

    final stockCaja = int.tryParse(record['STOCKCAJA'] ?? '0') ?? 0;
    final stockUnidad = int.tryParse(record['STOCKUNIDA'] ?? '0') ?? 0;
    final unidad = int.tryParse(record['UNIDAD'] ?? '0') ?? 0;
    final cantidadTotal = (unidad > 0) ? (stockCaja * unidad) + stockUnidad : stockCaja + stockUnidad;

    // REGLA 1: Solo productos con cantidad total > 0
    if (cantidadTotal <= 0) continue;

    // REGLA 2: Tipo de producto según cantidad_presentacion
    String tipoProducto = (unidad > 1) ? 'Caja' : 'Unidad';

    // REGLA 3: Si es Unidad, el precio de la caja pasa a la unidad
    double precioCaja = double.tryParse(record['A_PRE_PUB'] ?? '0.0') ?? 0.0;
    double precioUnidad = double.tryParse(record['A_PRE_UNI'] ?? '0.0') ?? 0.0;
    
    if (tipoProducto == 'Unidad') {
      precioUnidad = precioCaja;
      precioCaja = 0.0;
    }

    // REGLA 4: Costos en 0 y Blister_SiNo en 0
    final double costoCaja = 0.0;
    final double costoUnidad = 0.0;
    final int blisterSiNo = 0;
    final stockMinimo = int.tryParse(record['STOCKMINI'] ?? '0') ?? 0;

    batch.insert('PRODUCTO', {
      'Nombre_Producto': nombre,
      'Fecha_Creacion': DateTime.now().toString().split(' ')[0], 
      'Cantidad_Presentacion': unidad > 0 ? unidad : null,
      'Cantidad_Presentacion_blister': 0,
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
  }

  print('Insertando registros en SQLite...');
  await batch.commit(noResult: true);
  
  print('-----------------------------------------');
  print('¡MIGRACIÓN COMPLETADA!');
  print('Productos migrados: $migrados');
  print('Archivo generado: $sqlitePath');
  print('-----------------------------------------');
  
  await db.close();
}
