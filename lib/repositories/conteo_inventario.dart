import 'package:pharma_salud/database/database_helper.dart';

class ConteoInventarioRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Asegurar que la tabla exista en SQLite
  Future<void> ensureTableExists() async {
    final db = await _databaseHelper.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CONTEO_INVENTARIO_POS (
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
        SESION_CODIGO TEXT,
        FOREIGN KEY (PRODUCTO_ID) REFERENCES PRODUCTO(ID)
      )
    ''');
    try {
      await db.execute("ALTER TABLE CONTEO_INVENTARIO_POS ADD COLUMN SESION_CODIGO TEXT;");
    } catch (_) {}
  }

  /// Registrar o actualizar conteo físico en tiempo real
  Future<int> registrarOActualizarConteo({
    required String modo, // 'GLOBAL' o 'INDIVIDUAL'
    required int productoId,
    required String nombreProducto,
    required String codigoBarra,
    required String tipoProducto,
    required int cantidadPresentacion,
    required int stockSistema,
    required int conteoFisico,
    required double precioVenta,
    required double costoUnidad,
    required int usuarioId,
    required String nombreUsuario,
    int? campanaId,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final fechaHoraStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final diferencia = conteoFisico - stockSistema;

    // Buscar si ya existe en el borrador activo según el modo
    String whereClause;
    List<dynamic> whereArgs;

    if (modo == 'GLOBAL') {
      whereClause = "MODO = 'GLOBAL' AND PRODUCTO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [productoId];
    } else {
      whereClause =
          "MODO = 'INDIVIDUAL' AND USUARIO_ID = ? AND PRODUCTO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [usuarioId, productoId];
    }

    final existentes = await db.query(
      'CONTEO_INVENTARIO_POS',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    final data = {
      'CAMPANA_ID': campanaId,
      'MODO': modo,
      'PRODUCTO_ID': productoId,
      'NOMBRE_PRODUCTO': nombreProducto,
      'CODIGO_BARRA': codigoBarra,
      'TIPO_PRODUCTO': tipoProducto,
      'CANTIDAD_PRESENTACION': cantidadPresentacion > 0 ? cantidadPresentacion : 1,
      'STOCK_SISTEMA': stockSistema,
      'CONTEO_FISICO': conteoFisico,
      'DIFERENCIA': diferencia,
      'PRECIO_VENTA': precioVenta,
      'COSTO_UNIDAD': costoUnidad,
      'FECHA_HORA': fechaHoraStr,
      'USUARIO_ID': usuarioId,
      'NOMBRE_USUARIO': nombreUsuario,
      'ESTADO': 'BORRADOR',
    };

    if (existentes.isNotEmpty) {
      final id = existentes.first['ID'] as int;
      await db.update(
        'CONTEO_INVENTARIO_POS',
        data,
        where: 'ID = ?',
        whereArgs: [id],
      );
      return id;
    } else {
      return await db.insert('CONTEO_INVENTARIO_POS', data);
    }
  }

  /// Obtener un conteo existente de un producto en el borrador actual
  Future<Map<String, dynamic>?> obtenerConteoDeProducto({
    required String modo,
    required int productoId,
    required int usuarioId,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    String whereClause;
    List<dynamic> whereArgs;

    if (modo == 'GLOBAL') {
      whereClause = "MODO = 'GLOBAL' AND PRODUCTO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [productoId];
    } else {
      whereClause =
          "MODO = 'INDIVIDUAL' AND USUARIO_ID = ? AND PRODUCTO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [usuarioId, productoId];
    }

    final results = await db.query(
      'CONTEO_INVENTARIO_POS',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Obtener la lista completa de conteos vivos (borrador activo)
  Future<List<Map<String, dynamic>>> obtenerReporteVivo({
    required String modo,
    required int usuarioId,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    String whereClause;
    List<dynamic> whereArgs;

    if (modo == 'GLOBAL') {
      whereClause = "MODO = 'GLOBAL' AND ESTADO = 'BORRADOR'";
      whereArgs = [];
    } else {
      whereClause = "MODO = 'INDIVIDUAL' AND USUARIO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [usuarioId];
    }

    return await db.query(
      'CONTEO_INVENTARIO_POS',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'ID DESC',
    );
  }

  /// Eliminar un producto del reporte de conteo
  Future<int> eliminarItemConteo(int id) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;
    return await db.delete(
      'CONTEO_INVENTARIO_POS',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Limpiar todo el borrador activo (para iniciar un nuevo conteo limpio)
  Future<int> limpiarBorrador({
    required String modo,
    required int usuarioId,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    String whereClause;
    List<dynamic> whereArgs;

    if (modo == 'GLOBAL') {
      whereClause = "MODO = 'GLOBAL' AND ESTADO = 'BORRADOR'";
      whereArgs = [];
    } else {
      whereClause = "MODO = 'INDIVIDUAL' AND USUARIO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [usuarioId];
    }

    return await db.delete(
      'CONTEO_INVENTARIO_POS',
      where: whereClause,
      whereArgs: whereArgs,
    );
  }

  /// Marcar el reporte como ENVIADO al Administrador
  Future<String?> enviarReporte({
    required String modo,
    required int usuarioId,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final sesionCodigo =
        "INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";

    String whereClause;
    List<dynamic> whereArgs;

    if (modo == 'GLOBAL') {
      whereClause = "MODO = 'GLOBAL' AND ESTADO = 'BORRADOR'";
      whereArgs = [];
    } else {
      whereClause = "MODO = 'INDIVIDUAL' AND USUARIO_ID = ? AND ESTADO = 'BORRADOR'";
      whereArgs = [usuarioId];
    }

    final updated = await db.update(
      'CONTEO_INVENTARIO_POS',
      {
        'ESTADO': 'ENVIADO',
        'SESION_CODIGO': sesionCodigo,
      },
      where: whereClause,
      whereArgs: whereArgs,
    );

    return updated > 0 ? sesionCodigo : null;
  }

  /// Consultar ventas realizadas después de la fecha/hora en que se contó el producto
  Future<int> obtenerVentasPosteriores(int productoId, String fechaConteoStr) async {
    final db = await _databaseHelper.database;
    try {
      final res = await db.rawQuery('''
        SELECT SUM(CANTIDAD) as total_vendido
        FROM DETALLES_VENTA
        WHERE PRODUCTO_ID = ? AND FECHA > ? AND DEVOLUCION != 'Si'
      ''', [productoId, fechaConteoStr]);

      if (res.isNotEmpty && res.first['total_vendido'] != null) {
        return (res.first['total_vendido'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }

  /// Obtener todos los reportes enviados o borradores pendientes para el Administrador
  Future<List<Map<String, dynamic>>> obtenerConteosParaAdmin({String? modoFiltro}) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    String whereClause = "ESTADO IN ('ENVIADO', 'BORRADOR')";
    List<dynamic> whereArgs = [];

    if (modoFiltro != null && modoFiltro.isNotEmpty) {
      whereClause += " AND MODO = ?";
      whereArgs.add(modoFiltro);
    }

    return await db.query(
      'CONTEO_INVENTARIO_POS',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'ID DESC',
    );
  }

  /// Aplicar ajuste de inventario definitivo en Kardex y Producto (Acción exclusiva del Admin)
  Future<void> aplicarAjustesAdmin({
    required List<Map<String, dynamic>> itemsParaAjustar,
    required String nombreAdmin,
  }) async {
    final db = await _databaseHelper.database;
    final now = DateTime.now();
    final fechaHoyStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    await db.transaction((txn) async {
      for (final item in itemsParaAjustar) {
        final idConteo = item['ID'] as int;
        final productoId = item['PRODUCTO_ID'] as int;
        final nombreProducto = item['NOMBRE_PRODUCTO'] as String;
        final conteoFisico = item['CONTEO_FISICO'] as int;
        final fechaConteo = item['FECHA_HORA'] as String;

        // Obtener stock actual de la BD
        final prods = await txn.query(
          'PRODUCTO',
          columns: ['Cantidad_Total'],
          where: 'ID = ?',
          whereArgs: [productoId],
          limit: 1,
        );

        if (prods.isEmpty) continue;
        final stockActual = (prods.first['Cantidad_Total'] as int?) ?? 0;

        // Consultar ventas posteriores
        final resVentas = await txn.rawQuery('''
          SELECT SUM(CANTIDAD) as total_vendido
          FROM DETALLES_VENTA
          WHERE PRODUCTO_ID = ? AND FECHA > ? AND DEVOLUCION != 'Si'
        ''', [productoId, fechaConteo]);

        int ventasPost = 0;
        if (resVentas.isNotEmpty && resVentas.first['total_vendido'] != null) {
          ventasPost = (resVentas.first['total_vendido'] as num).toInt();
        }

        // El nuevo stock resultante debe respetar las ventas ocurridas después del conteo
        final stockResultante = (conteoFisico - ventasPost).clamp(0, 9999999);
        final diferenciaAjuste = stockResultante - stockActual;

        if (diferenciaAjuste != 0) {
          // Actualizar producto
          await txn.update(
            'PRODUCTO',
            {'Cantidad_Total': stockResultante},
            where: 'ID = ?',
            whereArgs: [productoId],
          );

          // Registrar en Kardex
          await txn.insert('KARDEX', {
            'NOMBRE_PRODUCTO': nombreProducto,
            'FECHA_MOVIMIENTO': fechaHoyStr,
            'TIPO_MOVIMIENTO': diferenciaAjuste > 0
                ? 'Ajuste Inventario (+)'
                : 'Ajuste Inventario (-)',
            'CANTIDAD': diferenciaAjuste.abs(),
            'USUARIO': nombreAdmin,
            'STOCK_SISTEMA': stockActual,
            'CONTEO_FISICO': stockResultante,
            'STOCK_ANTERIOR': stockActual,
            'STOCK_RESULTANTE': stockResultante,
          });
        } else {
          // Registrar en Kardex como Conforme para auditoría
          await txn.insert('KARDEX', {
            'NOMBRE_PRODUCTO': nombreProducto,
            'FECHA_MOVIMIENTO': fechaHoyStr,
            'TIPO_MOVIMIENTO': 'Ajuste Inventario (Conforme)',
            'CANTIDAD': 0,
            'USUARIO': nombreAdmin,
            'STOCK_SISTEMA': stockActual,
            'CONTEO_FISICO': stockResultante,
            'STOCK_ANTERIOR': stockActual,
            'STOCK_RESULTANTE': stockResultante,
          });
        }

        // Marcar conteo como APLICADO
        await txn.update(
          'CONTEO_INVENTARIO_POS',
          {'ESTADO': 'APLICADO'},
          where: 'ID = ?',
          whereArgs: [idConteo],
        );
      }
    });
  }

  /// Obtener lista de inventarios históricos agrupados por sesión para el POS
  Future<List<Map<String, dynamic>>> obtenerHistorialInventariosPOS({
    int? usuarioId,
    String? modo,
  }) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    String whereClause = "ESTADO IN ('ENVIADO', 'APLICADO')";
    List<dynamic> whereArgs = [];

    if (modo != null && modo.isNotEmpty && modo != 'TODOS') {
      whereClause += " AND MODO = ?";
      whereArgs.add(modo);
    }

    if (usuarioId != null && modo == 'INDIVIDUAL') {
      whereClause += " AND USUARIO_ID = ?";
      whereArgs.add(usuarioId);
    }

    final query = '''
      SELECT 
        COALESCE(SESION_CODIGO, 'INV-' || REPLACE(SUBSTR(FECHA_HORA, 1, 10), '-', '')) as CODIGO,
        MODO,
        NOMBRE_USUARIO,
        USUARIO_ID,
        MIN(FECHA_HORA) as FECHA_INICIO,
        MAX(FECHA_HORA) as FECHA_FIN,
        COUNT(*) as TOTAL_PRODUCTOS,
        SUM(CASE WHEN DIFERENCIA = 0 THEN 1 ELSE 0 END) as TOTAL_CONFORMES,
        SUM(CASE WHEN DIFERENCIA > 0 THEN 1 ELSE 0 END) as TOTAL_SOBRANTES,
        SUM(CASE WHEN DIFERENCIA < 0 THEN 1 ELSE 0 END) as TOTAL_FALTANTES,
        CASE 
          WHEN SUM(CASE WHEN ESTADO = 'ENVIADO' THEN 1 ELSE 0 END) > 0 THEN 'ENVIADO'
          ELSE 'APLICADO'
        END as ESTADO_SESION
      FROM CONTEO_INVENTARIO_POS
      WHERE $whereClause
      GROUP BY COALESCE(SESION_CODIGO, 'INV-' || REPLACE(SUBSTR(FECHA_HORA, 1, 10), '-', ''))
      ORDER BY MAX(FECHA_HORA) DESC
    ''';

    return await db.rawQuery(query, whereArgs);
  }

  /// Obtener todos los productos contados en una sesión de inventario específica
  Future<List<Map<String, dynamic>>> obtenerDetalleSesionInventario(String codigoSesion) async {
    await ensureTableExists();
    final db = await _databaseHelper.database;

    const query = '''
      SELECT *
      FROM CONTEO_INVENTARIO_POS
      WHERE (SESION_CODIGO = ? OR ('INV-' || REPLACE(SUBSTR(FECHA_HORA, 1, 10), '-', '')) = ?)
      ORDER BY ID ASC
    ''';

    return await db.rawQuery(query, [codigoSesion, codigoSesion]);
  }

  /// Compara dos sesiones de inventario (Conteo Cruzado / Doble Verificación)
  Future<Map<String, dynamic>> compararSesionesInventario(
    String codigoSesionA,
    String codigoSesionB,
  ) async {
    final itemsA = await obtenerDetalleSesionInventario(codigoSesionA);
    final itemsB = await obtenerDetalleSesionInventario(codigoSesionB);

    final Map<int, Map<String, dynamic>> mapA = {
      for (var it in itemsA) (it['PRODUCTO_ID'] as int): it,
    };
    final Map<int, Map<String, dynamic>> mapB = {
      for (var it in itemsB) (it['PRODUCTO_ID'] as int): it,
    };

    final Set<int> todosProdIds = {...mapA.keys, ...mapB.keys};

    final List<Map<String, dynamic>> comparativa = [];
    int totalCoincidentes = 0;
    int totalDiscrepancias = 0;
    int totalSoloA = 0;
    int totalSoloB = 0;

    for (final prodId in todosProdIds) {
      final a = mapA[prodId];
      final b = mapB[prodId];

      if (a != null && b != null) {
        final fisA = (a['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
        final fisB = (b['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
        final difEntreEllas = fisA - fisB;
        final esCoincidente = difEntreEllas == 0;

        if (esCoincidente) {
          totalCoincidentes++;
        } else {
          totalDiscrepancias++;
        }

        comparativa.add({
          'PRODUCTO_ID': prodId,
          'NOMBRE_PRODUCTO': a['NOMBRE_PRODUCTO'] ?? b['NOMBRE_PRODUCTO'],
          'CODIGO_BARRA': a['CODIGO_BARRA'] ?? b['CODIGO_BARRA'],
          'PRESENTACION': a['CANTIDAD_PRESENTACION'] ?? b['CANTIDAD_PRESENTACION'],
          'STOCK_SISTEMA': a['STOCK_SISTEMA'] ?? b['STOCK_SISTEMA'],
          'CONTEO_A': fisA,
          'CONTEO_B': fisB,
          'DIFERENCIA_ENTRE_ELLAS': difEntreEllas,
          'ESTADO_COMPARACION': esCoincidente ? 'COINCIDENTE' : 'DISCREPANCIA',
          'NOTA_A': a['NOTA'],
          'NOTA_B': b['NOTA'],
          'ID_CONTEO_A': a['ID'],
          'ID_CONTEO_B': b['ID'],
          'MODO_A': a['MODO'],
          'MODO_B': b['MODO'],
          'USUARIO_A': a['NOMBRE_USUARIO'],
          'USUARIO_B': b['NOMBRE_USUARIO'],
          'FECHA_A': a['FECHA_HORA'],
          'FECHA_B': b['FECHA_HORA'],
        });
      } else if (a != null) {
        totalSoloA++;
        final fisA = (a['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
        comparativa.add({
          'PRODUCTO_ID': prodId,
          'NOMBRE_PRODUCTO': a['NOMBRE_PRODUCTO'],
          'CODIGO_BARRA': a['CODIGO_BARRA'],
          'PRESENTACION': a['CANTIDAD_PRESENTACION'],
          'STOCK_SISTEMA': a['STOCK_SISTEMA'],
          'CONTEO_A': fisA,
          'CONTEO_B': null,
          'DIFERENCIA_ENTRE_ELLAS': null,
          'ESTADO_COMPARACION': 'SOLO_A',
          'NOTA_A': a['NOTA'],
          'NOTA_B': null,
          'ID_CONTEO_A': a['ID'],
          'ID_CONTEO_B': null,
          'MODO_A': a['MODO'],
          'MODO_B': null,
          'USUARIO_A': a['NOMBRE_USUARIO'],
          'USUARIO_B': null,
          'FECHA_A': a['FECHA_HORA'],
          'FECHA_B': null,
        });
      } else if (b != null) {
        totalSoloB++;
        final fisB = (b['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
        comparativa.add({
          'PRODUCTO_ID': prodId,
          'NOMBRE_PRODUCTO': b['NOMBRE_PRODUCTO'],
          'CODIGO_BARRA': b['CODIGO_BARRA'],
          'PRESENTACION': b['CANTIDAD_PRESENTACION'],
          'STOCK_SISTEMA': b['STOCK_SISTEMA'],
          'CONTEO_A': null,
          'CONTEO_B': fisB,
          'DIFERENCIA_ENTRE_ELLAS': null,
          'ESTADO_COMPARACION': 'SOLO_B',
          'NOTA_A': null,
          'NOTA_B': b['NOTA'],
          'ID_CONTEO_A': null,
          'ID_CONTEO_B': b['ID'],
          'MODO_A': null,
          'MODO_B': b['MODO'],
          'USUARIO_A': null,
          'USUARIO_B': b['NOMBRE_USUARIO'],
          'FECHA_A': null,
          'FECHA_B': b['FECHA_HORA'],
        });
      }
    }

    final totalAmbas = totalCoincidentes + totalDiscrepancias;
    final tasaCoincidencia = totalAmbas > 0 ? (totalCoincidentes / totalAmbas) * 100 : 0.0;

    return {
      'codigoSesionA': codigoSesionA,
      'codigoSesionB': codigoSesionB,
      'usuarioA': itemsA.isNotEmpty ? itemsA.first['NOMBRE_USUARIO'] : 'Operador A',
      'usuarioB': itemsB.isNotEmpty ? itemsB.first['NOMBRE_USUARIO'] : 'Operador B',
      'fechaA': itemsA.isNotEmpty ? itemsA.first['FECHA_HORA'] : null,
      'fechaB': itemsB.isNotEmpty ? itemsB.first['FECHA_HORA'] : null,
      'modoA': itemsA.isNotEmpty ? itemsA.first['MODO'] : null,
      'modoB': itemsB.isNotEmpty ? itemsB.first['MODO'] : null,
      'comparativa': comparativa,
      'totalProductos': todosProdIds.length,
      'totalAmbas': totalAmbas,
      'totalCoincidentes': totalCoincidentes,
      'totalDiscrepancias': totalDiscrepancias,
      'totalSoloA': totalSoloA,
      'totalSoloB': totalSoloB,
      'tasaCoincidencia': tasaCoincidencia,
    };
  }
}
