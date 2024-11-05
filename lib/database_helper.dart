import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

    // Crea la base de datos 'botica.db'
    return await databaseFactoryFfi.openDatabase(
      'botica.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Crear tabla PRODUCTO
          await db.execute('''
            CREATE TABLE PRODUCTO (
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
              Blister_SiNo INTEGER
            )
          ''');

          // Crear tabla FECHA_VENCIMIENTO
          await db.execute('''
            CREATE TABLE FECHA_VENCIMIENTO (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              Producto_ID INTEGER NOT NULL,
              Fecha_Vencimiento TEXT NOT NULL,
              Cantidad INTEGER NOT NULL,
              FOREIGN KEY (Producto_ID) REFERENCES PRODUCTO(ID) ON DELETE CASCADE
            )
          ''');

          // Crear tabla USUARIO
          await db.execute('''
            CREATE TABLE USUARIO (
              ID_USUARIO INTEGER PRIMARY KEY AUTOINCREMENT,
              NOMBRE_USUARIO TEXT NOT NULL,
              CLAVE TEXT NOT NULL,
              ROL TEXT NOT NULL
            )
          ''');

          // Inserción de usuario admin por defecto
          await db.insert('USUARIO', {
            'NOMBRE_USUARIO': 'admin',
            'CLAVE': 'kevin745',
            'ROL': 'Administrador',
          });

          // Crear tabla REGISTRO_DE_VENTAS
          await db.execute('''
            CREATE TABLE REGISTRO_DE_VENTAS (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              FECHA TEXT NOT NULL,
              TOTAL REAL NOT NULL,
              USUARIO_ID INTEGER NOT NULL,
              FOREIGN KEY (USUARIO_ID) REFERENCES USUARIO(ID_USUARIO)
            )
          ''');

          // Crear tabla DETALLES_VENTA (en lugar de CARRITO_DE_VENTAS)
          await db.execute('''
            CREATE TABLE DETALLES_VENTA (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              REGISTRO_VENTA_ID INTEGER NOT NULL,
              PRODUCTO_ID INTEGER NOT NULL,
              NOMBRE_PRODUCTO TEXT NOT NULL,
              CANTIDAD INTEGER NOT NULL,
              TIPO_VENTA TEXT NOT NULL,
              PRECIO_VENTA REAL NOT NULL,
              USUARIO_ID INTEGER NOT NULL,
              FECHA TEXT NOT NULL,
              FOREIGN KEY (REGISTRO_VENTA_ID) REFERENCES REGISTRO_DE_VENTAS(ID) ON DELETE CASCADE,
              FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
            )
          ''');

          // Crear tabla CARRITO_DE_VENTAS
          await db.execute('''
            CREATE TABLE CARRITO_DE_VENTAS (
              ID INTEGER PRIMARY KEY AUTOINCREMENT,
              REGISTRO_VENTA_ID INTEGER NOT NULL,
              PRODUCTO_ID INTEGER NOT NULL,
              CANTIDAD INTEGER NOT NULL,
              PRECIO_VENTA REAL NOT NULL,
              TIPO_VENTA TEXT NOT NULL,
              FECHA TEXT NOT NULL,
              FOREIGN KEY (REGISTRO_VENTA_ID) REFERENCES REGISTRO_DE_VENTAS(ID) ON DELETE CASCADE,
              FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
            )
          ''');
        },
      ),
    );
  }
}
