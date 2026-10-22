import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  
  final sqlitePath = r'c:\Users\Lenovo\OneDrive\Documentos\RQCSOFT\FARMACIA\CDX\database\botica_sin_costos.db';
  print('\n>>> Creando nueva base de datos en: $sqlitePath');
  
  // Si existe el archivo, lo borramos para crear uno fresco y limpio
  final fileDb = File(sqlitePath);
  if (fileDb.existsSync()) {
    fileDb.deleteSync();
  }
  
  // Creamos la DB con todas las tablas originales de tu app
  final db = await databaseFactory.openDatabase(
    sqlitePath,
    options: OpenDatabaseOptions(
      version: 10,
      onCreate: (db, version) async {
        // Crear tabla PRODUCTO
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

        // Crear tabla FECHA_VENCIMIENTO
        await db.execute('''CREATE TABLE FECHA_VENCIMIENTO (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Producto_ID INTEGER NOT NULL,
          Fecha_Vencimiento TEXT NOT NULL,
          Cantidad INTEGER NOT NULL,
          FOREIGN KEY (Producto_ID) REFERENCES PRODUCTO(ID) ON DELETE CASCADE
        )''');

        // Crear tabla USUARIO
        await db.execute('''CREATE TABLE USUARIO (
          ID_USUARIO INTEGER PRIMARY KEY AUTOINCREMENT,
          NOMBRE_USUARIO TEXT NOT NULL,
          NOMBRE_VENDEDOR TEXT NOT NULL,
          CLAVE TEXT NOT NULL,
          ROL TEXT NOT NULL,
          GENERO TEXT NOT NULL,
          ESTADO TEXT NOT NULL DEFAULT 'Activo'
        )''');

        // Inserción de usuario admin por defecto
        await db.insert('USUARIO', {
          'NOMBRE_USUARIO': 'admin',
          'NOMBRE_VENDEDOR': 'Administrador Principal',
          'CLAVE': 'kevin745',
          'ROL': 'Administrador',
          'GENERO': 'Masculino',
          'ESTADO': 'Activo',
        });

        // Crear tabla REGISTRO_DE_VENTAS
        await db.execute('''CREATE TABLE REGISTRO_DE_VENTAS (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          FECHA TEXT NOT NULL,
          TOTAL REAL NOT NULL,
          PAGO_CON REAL DEFAULT 0.0,
          VUELTO REAL DEFAULT 0.0,
          USUARIO_ID INTEGER NOT NULL,
          FOREIGN KEY (USUARIO_ID) REFERENCES USUARIO(ID_USUARIO)
        )''');

        // Crear tabla DETALLES_VENTA
        await db.execute('''CREATE TABLE DETALLES_VENTA (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          REGISTRO_VENTA_ID INTEGER NOT NULL,
          PRODUCTO_ID INTEGER NOT NULL,
          NOMBRE_PRODUCTO TEXT NOT NULL,
          CANTIDAD INTEGER NOT NULL,
          TIPO_VENTA TEXT NOT NULL,
          PRECIO_VENTA REAL NOT NULL,
          USUARIO_ID INTEGER NOT NULL,
          FECHA TEXT NOT NULL,
          DEVOLUCION TEXT DEFAULT 'No',
          FOREIGN KEY (REGISTRO_VENTA_ID) REFERENCES REGISTRO_DE_VENTAS(ID) ON DELETE CASCADE,
          FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
        )''');

        // Crear tabla CARRITO_DE_VENTAS
        await db.execute('''CREATE TABLE CARRITO_DE_VENTAS (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          REGISTRO_VENTA_ID INTEGER NOT NULL,
          PRODUCTO_ID INTEGER NOT NULL,
          CANTIDAD INTEGER NOT NULL,
          PRECIO_VENTA REAL NOT NULL,
          TIPO_VENTA TEXT NOT NULL,
          FECHA TEXT NOT NULL,
          ID_KARDEX INTEGER NOT NULL,
          ID_USUARIO INTEGER NOT NULL,
          FOREIGN KEY (REGISTRO_VENTA_ID) REFERENCES REGISTRO_DE_VENTAS(ID) ON DELETE CASCADE,
          FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
        )''');

        // Crear tabla KARDEX
        await db.execute('''CREATE TABLE KARDEX (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          NOMBRE_PRODUCTO TEXT NOT NULL,
          FECHA_MOVIMIENTO TEXT NOT NULL,
          TIPO_MOVIMIENTO TEXT NOT NULL,
          CANTIDAD INTEGER NOT NULL,
          USUARIO TEXT NOT NULL,
          ID_DETALLE_VENTA INTEGER,
          STOCK_SISTEMA INTEGER DEFAULT 0,
          CONTEO_FISICO INTEGER DEFAULT 0
        )''');
      },
    ),
  );
  
  // ======= INICIO DE LA MIGRACIÓN ======= 
  final dbfFilePath = r'c:\Users\Lenovo\OneDrive\Documentos\RQCSOFT\FARMACIA\CDX\AINV0102.DBF';
  print('>>> Leyendo archivo DBF de: $dbfFilePath');
  
  final file = File(dbfFilePath);
  final bytes = file.readAsBytesSync();
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

  print('Estructura DBF procesada. Extrayendo los $numRecords registros...');
  
  final batch = db.batch();
  int migrados = 0;
  int omitidos = 0;
  var recordOffset = headerSize;

  for (var i = 0; i < numRecords; i++) {
    if (bytes[recordOffset] == 0x2A) { // Registro eliminado/marcado con '*' en clipper
      recordOffset += recordSize;
      omitidos++;
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
    if (almacen != '1') {
      omitidos++;
      continue;
    }

    final nombre = record['A_NOM_CO'] ?? '';
    // Solo omitiremos los registros cuyo nombre esté vacío. Así que pasaremos TANTO LOS DE STOCK 0 como mayores a 0 
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

    String tipoProducto;
    if (unidad > 1) {
      tipoProducto = 'Caja';
    } else {
      // Si es 1 o si no especificaron unidad (0), será Unidad.
      tipoProducto = 'Unidad';
    }

    final dbfDate = record['A_FEC_CRE'] ?? '';
    String fechaCreacion;
    if (dbfDate.length == 8) {
      fechaCreacion = '${dbfDate.substring(0,4)}-${dbfDate.substring(4,6)}-${dbfDate.substring(6,8)}';
    } else {
      final now = DateTime.now();
      fechaCreacion = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    }

    double precioCaja = double.tryParse(record['A_PRE_PUB'] ?? '0.0') ?? 0.0;
    double precioUnidad = double.tryParse(record['A_PRE_UNI'] ?? '0.0') ?? 0.0;
    final double costoCaja = 0.0;
    final double costoUnidad = 0.0;
    final stockMinimo = int.tryParse(record['STOCKMINI'] ?? '0') ?? 0;
    
    // Si la presentación es unidad, el precio caja pasa a precio unidad
    if (tipoProducto == 'Unidad') {
      precioUnidad = precioCaja;
      precioCaja = 0.0;
    }
    final int blisterSiNo = 0;

    batch.insert('PRODUCTO', {
      'Nombre_Producto': nombre,
      'Fecha_Creacion': fechaCreacion,
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

  print('>>> Ejecutando inserción en tu nueva base de datos para los $migrados productos...');
  await batch.commit(noResult: true);
  
  // Agregar también datos iniciales opcionales
  print('===========================');
  print('! BASE DE DATOS LISTA !');
  print('Ruta final: $sqlitePath');
  print('Total productos agregados a SQLite: $migrados');
  print('Registros DBF descartados por falta de datos/nombres vacíos: $omitidos');
  
  await db.close();
}
