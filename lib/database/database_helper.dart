import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Inicializa la base de datos FFI
    sqfliteFfiInit();

    // Obtener el directorio de documentos de la aplicación para evitar problemas de permisos
    final directory = await getApplicationSupportDirectory();
    final path = join(directory.path, 'botica.db');

    // Crea la base de datos 'botica.db' en la ruta segura
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 21, // Incrementa la versión de la base de datos a 21
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            try {
              await db.execute(
                  "ALTER TABLE USUARIO ADD COLUMN GENERO TEXT NOT NULL DEFAULT 'Masculino'");
            } catch (e) {
              print("Error adding GENERO column: $e");
            }
          }
          if (oldVersion < 4) {
            // Migración de fechas a formato ISO 8601 (YYYY-MM-DD)
            try {
              // REGISTRO_DE_VENTAS: dd/MM/yyyy -> YYYY-MM-DD
              await db.execute('''
                UPDATE REGISTRO_DE_VENTAS 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____'
              ''');

              // DETALLES_VENTA: dd/MM/yyyy -> YYYY-MM-DD
              await db.execute('''
                UPDATE DETALLES_VENTA 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____'
              ''');

              // KARDEX: dd/MM/yyyy hh:mm a -> YYYY-MM-DD HH:MM:SS
              await db.execute('''
                UPDATE KARDEX 
                SET FECHA_MOVIMIENTO = SUBSTR(FECHA_MOVIMIENTO, 7, 4) || '-' || SUBSTR(FECHA_MOVIMIENTO, 4, 2) || '-' || SUBSTR(FECHA_MOVIMIENTO, 1, 2)
                WHERE FECHA_MOVIMIENTO LIKE '__/__/____ %'
              ''');

              // FECHA_VENCIMIENTO: dd/MM/yyyy -> YYYY-MM-DD
              await db.execute('''
                UPDATE FECHA_VENCIMIENTO 
                SET Fecha_Vencimiento = SUBSTR(Fecha_Vencimiento, 7, 4) || '-' || SUBSTR(Fecha_Vencimiento, 4, 2) || '-' || SUBSTR(Fecha_Vencimiento, 1, 2)
                WHERE Fecha_Vencimiento LIKE '__/__/____'
              ''');

              // CARRITO_DE_VENTAS: dd/MM/yyyy hh:mm a -> YYYY-MM-DD
              await db.execute('''
                UPDATE CARRITO_DE_VENTAS 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____ %'
              ''');
            } catch (e) {
              print("Error during date migration: $e");
            }
          }
          if (oldVersion < 5) {
            // Corregir migración parcial para tablas que podrían tener hora/espacios
            try {
              await db.execute('''
                UPDATE REGISTRO_DE_VENTAS 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____%' AND FECHA NOT LIKE '____-__-__'
              ''');
              await db.execute('''
                UPDATE DETALLES_VENTA 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____%' AND FECHA NOT LIKE '____-__-__'
              ''');
              await db.execute('''
                UPDATE KARDEX 
                SET FECHA_MOVIMIENTO = SUBSTR(FECHA_MOVIMIENTO, 7, 4) || '-' || SUBSTR(FECHA_MOVIMIENTO, 4, 2) || '-' || SUBSTR(FECHA_MOVIMIENTO, 1, 2)
                WHERE FECHA_MOVIMIENTO LIKE '__/__/____%' AND FECHA_MOVIMIENTO NOT LIKE '____-__-__'
              ''');
              await db.execute('''
                UPDATE CARRITO_DE_VENTAS 
                SET FECHA = SUBSTR(FECHA, 7, 4) || '-' || SUBSTR(FECHA, 4, 2) || '-' || SUBSTR(FECHA, 1, 2)
                WHERE FECHA LIKE '__/__/____%' AND FECHA NOT LIKE '____-__-__'
              ''');
            } catch (e) {
              print("Error during date migration fix: $e");
            }
          }
          if (oldVersion < 6) {
            // Agregar columnas NOMBRE_VENDEDOR y ESTADO a la tabla USUARIO de forma segura
            try {
              // Verificamos si la columna existe antes de intentar agregarla
              var columns = await db.rawQuery('PRAGMA table_info(USUARIO)');
              bool hasNombreVendedor =
                  columns.any((column) => column['name'] == 'NOMBRE_VENDEDOR');
              bool hasEstado =
                  columns.any((column) => column['name'] == 'ESTADO');

              if (!hasNombreVendedor) {
                await db.execute(
                    "ALTER TABLE USUARIO ADD COLUMN NOMBRE_VENDEDOR TEXT NOT NULL DEFAULT 'Vendedor Nuevo'");
              }
              if (!hasEstado) {
                await db.execute(
                    "ALTER TABLE USUARIO ADD COLUMN ESTADO TEXT NOT NULL DEFAULT 'Activo'");
              }

              // Actualizar admin por defecto
              await db.update(
                  'USUARIO',
                  {
                    'NOMBRE_VENDEDOR': 'Administrador Principal',
                    'ESTADO': 'Activo'
                  },
                  where: 'NOMBRE_USUARIO = ?',
                  whereArgs: ['admin']);
            } catch (e) {
              print("Error during migration to v6: $e");
            }
          }
          if (oldVersion < 7) {
            try {
              await db.execute(
                  "ALTER TABLE REGISTRO_DE_VENTAS ADD COLUMN PAGO_CON REAL DEFAULT 0.0");
              await db.execute(
                  "ALTER TABLE REGISTRO_DE_VENTAS ADD COLUMN VUELTO REAL DEFAULT 0.0");
            } catch (e) {
              print("Error during migration to v7: $e");
            }
          }
          if (oldVersion < 8) {
            try {
              await db.execute(
                  "ALTER TABLE CARRITO_DE_VENTAS ADD COLUMN ID_USUARIO INTEGER NOT NULL DEFAULT 1");
            } catch (e) {
              print("Error during migration to v8: $e");
            }
          }
          if (oldVersion < 9) {
            try {
              await db.execute(
                  "ALTER TABLE DETALLES_VENTA ADD COLUMN DEVOLUCION TEXT DEFAULT 'No'");
            } catch (e) {
              print("Error adding DEVOLUCION column: $e");
            }
          }
          if (oldVersion < 10) {
            try {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN ID_DETALLE_VENTA INTEGER");
            } catch (e) {
              print("Error adding ID_DETALLE_VENTA column to KARDEX: $e");
            }
          }
          if (oldVersion < 11) {
            try {
              await db.execute('''CREATE TABLE IF NOT EXISTS SOBRANTE_CAJA (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                USUARIO_ID INTEGER NOT NULL,
                FECHA TEXT NOT NULL,
                MONTO REAL NOT NULL,
                NOTA TEXT DEFAULT '',
                FOREIGN KEY (USUARIO_ID) REFERENCES USUARIO(ID_USUARIO)
              )''');
            } catch (e) {
              print("Error creating SOBRANTE_CAJA table: $e");
            }
          }
          if (oldVersion < 12) {
            try {
              await db.execute(
                  "ALTER TABLE PRODUCTO ADD COLUMN Codigo_Barra TEXT");
            } catch (e) {
              print("Error adding Codigo_Barra column: $e");
            }
          }
          if (oldVersion < 13) {
            try {
              await db.execute('''CREATE TABLE IF NOT EXISTS FARMACIA (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                NOMBRE TEXT NOT NULL,
                ACTIVA INTEGER NOT NULL DEFAULT 0
              )''');
              await db.insert('FARMACIA', {
                'NOMBRE': 'PHARMA SALUD',
                'ACTIVA': 1,
              });
            } catch (e) {
              print("Error creating FARMACIA table: $e");
            }
          }
          if (oldVersion < 14) {
            try {
              await db.execute(
                  "ALTER TABLE SOBRANTE_CAJA ADD COLUMN TIPO TEXT NOT NULL DEFAULT 'SOBRANTE'");
            } catch (e) {
              print("Error adding TIPO column to SOBRANTE_CAJA: $e");
            }
          }
          if (oldVersion < 15) {
            try {
              await db.execute('''CREATE TABLE IF NOT EXISTS CAMPANA_INVENTARIO (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                NOMBRE TEXT NOT NULL,
                FECHA_INICIO TEXT NOT NULL,
                FECHA_FIN TEXT,
                ESTADO TEXT NOT NULL DEFAULT 'ACTIVO'
              )''');
            } catch (e) {
              print("Error creating CAMPANA_INVENTARIO table: $e");
            }
          }
          if (oldVersion < 16) {
            try {
              await db.execute(
                  "ALTER TABLE REGISTRO_DE_VENTAS ADD COLUMN METODO_PAGO TEXT DEFAULT 'Física'");
            } catch (e) {
              print("Error adding METODO_PAGO column to REGISTRO_DE_VENTAS: $e");
            }
          }
          if (oldVersion < 17) {
            try {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_SISTEMA INTEGER DEFAULT 0");
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN CONTEO_FISICO INTEGER DEFAULT 0");
            } catch (e) {
              print("Error adding STOCK_SISTEMA or CONTEO_FISICO to KARDEX: $e");
            }
          }
          if (oldVersion < 18) {
            try {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_ANTERIOR INTEGER");
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_RESULTANTE INTEGER");
            } catch (e) {
              print("Error adding STOCK_ANTERIOR or STOCK_RESULTANTE to KARDEX: $e");
            }
          }
          if (oldVersion < 19) {
            try {
              var columns = await db.rawQuery('PRAGMA table_info(PRODUCTO)');
              bool hasEsOculto =
                  columns.any((column) => column['name'] == 'ES_OCULTO');
              if (!hasEsOculto) {
                await db.execute(
                    "ALTER TABLE PRODUCTO ADD COLUMN ES_OCULTO INTEGER NOT NULL DEFAULT 0");
              }
            } catch (e) {
              print("Error adding ES_OCULTO to PRODUCTO: $e");
            }
          }
          if (oldVersion < 20) {
            try {
              await db.execute('''CREATE TABLE IF NOT EXISTS CUADRE_GLOBAL_CAMPANA (
                ID INTEGER PRIMARY KEY AUTOINCREMENT,
                CAMPANA_ID INTEGER NOT NULL,
                CAMPANA_NOMBRE TEXT NOT NULL,
                FECHA_CUADRE TEXT NOT NULL,
                FECHA_INICIO_CAMPANA TEXT NOT NULL,
                FECHA_FIN_CAMPANA TEXT NOT NULL,
                TOTAL_SOBRANTE_INV REAL NOT NULL DEFAULT 0.0,
                TOTAL_FALTANTE_INV REAL NOT NULL DEFAULT 0.0,
                BALANCE_INV REAL NOT NULL DEFAULT 0.0,
                TOTAL_SOBRANTE_CAJA REAL NOT NULL DEFAULT 0.0,
                BALANCE_GLOBAL REAL NOT NULL DEFAULT 0.0,
                OBSERVACIONES TEXT,
                ADMIN_ID INTEGER,
                FOREIGN KEY (CAMPANA_ID) REFERENCES CAMPANA_INVENTARIO(ID) ON DELETE CASCADE
              )''');
            } catch (e) {
              print("Error creating CUADRE_GLOBAL_CAMPANA table: $e");
            }
          }
          if (oldVersion < 21) {
            try {
              var columns = await db.rawQuery('PRAGMA table_info(PRODUCTO)');
              bool hasRecetaMedica =
                  columns.any((column) => column['name'] == 'RECETA_MEDICA');
              if (!hasRecetaMedica) {
                await db.execute(
                    "ALTER TABLE PRODUCTO ADD COLUMN RECETA_MEDICA INTEGER NOT NULL DEFAULT 0");
              }
            } catch (e) {
              print("Error adding RECETA_MEDICA to PRODUCTO: $e");
            }
          }
        },
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
            Codigo_Barra TEXT,
            ES_OCULTO INTEGER NOT NULL DEFAULT 0,
            RECETA_MEDICA INTEGER NOT NULL DEFAULT 0
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
            METODO_PAGO TEXT DEFAULT 'Física',
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
            CONTEO_FISICO INTEGER DEFAULT 0,
            STOCK_ANTERIOR INTEGER,
            STOCK_RESULTANTE INTEGER
          )''');

          // Crear tabla SOBRANTE_CAJA
          await db.execute('''CREATE TABLE SOBRANTE_CAJA (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            USUARIO_ID INTEGER NOT NULL,
            FECHA TEXT NOT NULL,
            MONTO REAL NOT NULL,
            NOTA TEXT DEFAULT '',
            TIPO TEXT NOT NULL DEFAULT 'SOBRANTE',
            FOREIGN KEY (USUARIO_ID) REFERENCES USUARIO(ID_USUARIO)
          )''');

          // Crear tabla FARMACIA
          await db.execute('''CREATE TABLE FARMACIA (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            NOMBRE TEXT NOT NULL,
            ACTIVA INTEGER NOT NULL DEFAULT 0
          )''');
          await db.insert('FARMACIA', {
            'NOMBRE': 'PHARMA SALUD',
            'ACTIVA': 1,
          });

          // Crear tabla CAMPANA_INVENTARIO
          await db.execute('''CREATE TABLE CAMPANA_INVENTARIO (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            NOMBRE TEXT NOT NULL,
            FECHA_INICIO TEXT NOT NULL,
            FECHA_FIN TEXT,
            ESTADO TEXT NOT NULL DEFAULT 'ACTIVO'
          )''');

          // Crear tabla CUADRE_GLOBAL_CAMPANA
          await db.execute('''CREATE TABLE CUADRE_GLOBAL_CAMPANA (
            ID INTEGER PRIMARY KEY AUTOINCREMENT,
            CAMPANA_ID INTEGER NOT NULL,
            CAMPANA_NOMBRE TEXT NOT NULL,
            FECHA_CUADRE TEXT NOT NULL,
            FECHA_INICIO_CAMPANA TEXT NOT NULL,
            FECHA_FIN_CAMPANA TEXT NOT NULL,
            TOTAL_SOBRANTE_INV REAL NOT NULL DEFAULT 0.0,
            TOTAL_FALTANTE_INV REAL NOT NULL DEFAULT 0.0,
            BALANCE_INV REAL NOT NULL DEFAULT 0.0,
            TOTAL_SOBRANTE_CAJA REAL NOT NULL DEFAULT 0.0,
            BALANCE_GLOBAL REAL NOT NULL DEFAULT 0.0,
            OBSERVACIONES TEXT,
            ADMIN_ID INTEGER,
            FOREIGN KEY (CAMPANA_ID) REFERENCES CAMPANA_INVENTARIO(ID) ON DELETE CASCADE
          )''');
        },
        onOpen: (db) async {
          // Verificar columnas críticas que podrían faltar si la BD fue creada
          // por un script externo (migrador_externo) o una migración incompleta
          try {
            final columns = await db.rawQuery('PRAGMA table_info(DETALLES_VENTA)');
            final hasDevolucion = columns.any((c) => c['name'] == 'DEVOLUCION');
            if (!hasDevolucion) {
              await db.execute(
                  "ALTER TABLE DETALLES_VENTA ADD COLUMN DEVOLUCION TEXT DEFAULT 'No'");
            }
          } catch (e) {
            print("onOpen: Error verificando DEVOLUCION en DETALLES_VENTA: $e");
          }

          try {
            final columns = await db.rawQuery('PRAGMA table_info(KARDEX)');
            final hasIdDetalle = columns.any((c) => c['name'] == 'ID_DETALLE_VENTA');
            if (!hasIdDetalle) {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN ID_DETALLE_VENTA INTEGER");
            }
            final hasStockSistema = columns.any((c) => c['name'] == 'STOCK_SISTEMA');
            if (!hasStockSistema) {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_SISTEMA INTEGER DEFAULT 0");
            }
            final hasConteoFisico = columns.any((c) => c['name'] == 'CONTEO_FISICO');
            if (!hasConteoFisico) {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN CONTEO_FISICO INTEGER DEFAULT 0");
            }
            final hasStockAnterior = columns.any((c) => c['name'] == 'STOCK_ANTERIOR');
            if (!hasStockAnterior) {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_ANTERIOR INTEGER");
            }
            final hasStockResultante = columns.any((c) => c['name'] == 'STOCK_RESULTANTE');
            if (!hasStockResultante) {
              await db.execute(
                  "ALTER TABLE KARDEX ADD COLUMN STOCK_RESULTANTE INTEGER");
            }
          } catch (e) {
            print("onOpen: Error verificando columnas de KARDEX: $e");
          }

          // Asegurar que la tabla SOBRANTE_CAJA exista
          try {
            await db.execute('''CREATE TABLE IF NOT EXISTS SOBRANTE_CAJA (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              USUARIO_ID INTEGER NOT NULL,
              FECHA TEXT NOT NULL,
              MONTO REAL NOT NULL,
              NOTA TEXT DEFAULT '',
              TIPO TEXT NOT NULL DEFAULT 'SOBRANTE',
              FOREIGN KEY (USUARIO_ID) REFERENCES USUARIO(ID_USUARIO)
            )''');
          } catch (e) {
            print("onOpen: Error creando SOBRANTE_CAJA: $e");
          }

          // Asegurar que exista la columna TIPO en SOBRANTE_CAJA
          try {
            final columns = await db.rawQuery('PRAGMA table_info(SOBRANTE_CAJA)');
            final hasTipo = columns.any((c) => c['name'] == 'TIPO');
            if (!hasTipo) {
              await db.execute(
                  "ALTER TABLE SOBRANTE_CAJA ADD COLUMN TIPO TEXT NOT NULL DEFAULT 'SOBRANTE'");
            }
          } catch (e) {
            print("onOpen: Error verificando TIPO en SOBRANTE_CAJA: $e");
          }

          // Asegurar que la tabla FARMACIA exista
          try {
            await db.execute('''CREATE TABLE IF NOT EXISTS FARMACIA (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              NOMBRE TEXT NOT NULL,
              ACTIVA INTEGER NOT NULL DEFAULT 0
            )''');
          } catch (e) {
            print("onOpen: Error creando FARMACIA: $e");
          }

          // Asegurar que la tabla CAMPANA_INVENTARIO exista
          try {
            await db.execute('''CREATE TABLE IF NOT EXISTS CAMPANA_INVENTARIO (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              NOMBRE TEXT NOT NULL,
              FECHA_INICIO TEXT NOT NULL,
              FECHA_FIN TEXT,
              ESTADO TEXT NOT NULL DEFAULT 'ACTIVO'
            )''');
          } catch (e) {
            print("onOpen: Error creando CAMPANA_INVENTARIO: $e");
          }

          // Asegurar que exista la columna METODO_PAGO en REGISTRO_DE_VENTAS
          try {
            final columns = await db.rawQuery('PRAGMA table_info(REGISTRO_DE_VENTAS)');
            final hasMetodoPago = columns.any((c) => c['name'] == 'METODO_PAGO');
            if (!hasMetodoPago) {
              await db.execute(
                  "ALTER TABLE REGISTRO_DE_VENTAS ADD COLUMN METODO_PAGO TEXT DEFAULT 'Física'");
            }
          } catch (e) {
            print("onOpen: Error verificando METODO_PAGO en REGISTRO_DE_VENTAS: $e");
          }

          // Asegurar que la tabla CUADRE_GLOBAL_CAMPANA exista
          try {
            await db.execute('''CREATE TABLE IF NOT EXISTS CUADRE_GLOBAL_CAMPANA (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              CAMPANA_ID INTEGER NOT NULL,
              CAMPANA_NOMBRE TEXT NOT NULL,
              FECHA_CUADRE TEXT NOT NULL,
              FECHA_INICIO_CAMPANA TEXT NOT NULL,
              FECHA_FIN_CAMPANA TEXT NOT NULL,
              TOTAL_SOBRANTE_INV REAL NOT NULL DEFAULT 0.0,
              TOTAL_FALTANTE_INV REAL NOT NULL DEFAULT 0.0,
              BALANCE_INV REAL NOT NULL DEFAULT 0.0,
              TOTAL_SOBRANTE_CAJA REAL NOT NULL DEFAULT 0.0,
              BALANCE_GLOBAL REAL NOT NULL DEFAULT 0.0,
              OBSERVACIONES TEXT,
              ADMIN_ID INTEGER,
              FOREIGN KEY (CAMPANA_ID) REFERENCES CAMPANA_INVENTARIO(ID) ON DELETE CASCADE
            )''');
          } catch (e) {
            print("onOpen: Error creando CUADRE_GLOBAL_CAMPANA: $e");
          }

          // Asegurar que la tabla CONTEO_INVENTARIO_POS exista
          try {
            await db.execute('''CREATE TABLE IF NOT EXISTS CONTEO_INVENTARIO_POS (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              CAMPANA_ID INTEGER,
              MODO TEXT NOT NULL,
              PRODUCTO_ID INTEGER NOT NULL,
              NOMBRE_PRODUCTO TEXT NOT NULL,
              CODIGO_BARRA TEXT,
              TIPO_PRODUCTO TEXT DEFAULT '--',
              CANTIDAD_PRESENTACION INTEGER DEFAULT 1,
              STOCK_SISTEMA INTEGER NOT NULL,
              CONTEO_FISICO INTEGER NOT NULL,
              DIFERENCIA INTEGER NOT NULL,
              PRECIO_VENTA REAL DEFAULT 0.0,
              COSTO_UNIDAD REAL DEFAULT 0.0,
              FECHA_HORA TEXT NOT NULL,
              USUARIO_ID INTEGER NOT NULL,
              NOMBRE_USUARIO TEXT NOT NULL,
              ESTADO TEXT NOT NULL DEFAULT 'BORRADOR',
              FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
            )''');
          } catch (e) {
            print("onOpen: Error creando CONTEO_INVENTARIO_POS: $e");
          }
        },
      ),
    );
  }
}
