import 'package:pharma_salud/database/database_helper.dart';

class ChartRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> obtenerVentasSemanales() async {
    final db = await _databaseHelper.database;
    DateTime hoy = DateTime.now();
    // Ajuste para obtener el lunes de la semana actual
    DateTime inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
    DateTime finSemana = inicioSemana.add(const Duration(days: 6));

    String inicioIso =
        "${inicioSemana.year}-${inicioSemana.month.toString().padLeft(2, '0')}-${inicioSemana.day.toString().padLeft(2, '0')} 00:00:00";
    String finIso =
        "${finSemana.year}-${finSemana.month.toString().padLeft(2, '0')}-${finSemana.day.toString().padLeft(2, '0')} 23:59:59";

    return await db.rawQuery('''
    SELECT 
      CAST(strftime('%w', FECHA) AS INTEGER) AS DIA_SQL,
      SUM(TOTAL) AS TOTAL_DIA
    FROM REGISTRO_DE_VENTAS
    WHERE FECHA BETWEEN ? AND ?
    GROUP BY DIA_SQL
  ''', [inicioIso, finIso]);
  }

  Future<List<Map<String, dynamic>>> obtenerVentasMensuales() async {
    final db = await _databaseHelper.database;
    int anioActual = DateTime.now().year;

    return await db.rawQuery('''
      SELECT strftime('%m', FECHA) AS MES,
            ROUND(SUM(TOTAL), 2) AS TOTAL_MES
      FROM REGISTRO_DE_VENTAS
      WHERE FECHA IS NOT NULL
      AND strftime('%Y', FECHA) = ?
      GROUP BY MES
      ORDER BY MES
    ''', [anioActual.toString()]);
  }

  Future<List<Map<String, dynamic>>> obtenerTopProductos() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT NOMBRE_PRODUCTO, SUM(CANTIDAD) AS TOTAL_VENDIDO
      FROM DETALLES_VENTA
      GROUP BY NOMBRE_PRODUCTO
      ORDER BY TOTAL_VENDIDO DESC
      LIMIT 5
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerEstadoStock() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        CASE 
          WHEN Cantidad_Total = 0 THEN 'Agotado'
          WHEN Cantidad_Total <= Stock_Minimo THEN 'Stock Bajo'
          ELSE 'Stock Óptimo'
        END AS ESTADO,
        COUNT(*) AS CANTIDAD
      FROM PRODUCTO
      GROUP BY ESTADO
      ORDER BY 
        CASE ESTADO
          WHEN 'Stock Óptimo' THEN 1
          WHEN 'Stock Bajo' THEN 2
          WHEN 'Agotado' THEN 3
          ELSE 4
        END
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorCategoria() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT p.Tipo_Producto, SUM(dv.CANTIDAD * dv.PRECIO_VENTA) AS TOTAL
      FROM DETALLES_VENTA dv
      JOIN PRODUCTO p ON dv.PRODUCTO_ID = p.ID
      GROUP BY p.Tipo_Producto
      ORDER BY TOTAL DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerVentasPorVendedor(
      {String periodo = 'mes'}) async {
    final db = await _databaseHelper.database;
    final hoy = DateTime.now();

    String fechaInicio;
    String fechaFin;

    if (periodo == 'dia') {
      // Filtro para HOY
      final fechaHoy =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
      fechaInicio = fechaHoy;
      fechaFin = fechaHoy;

      // Consulta exacta para un solo día usando LIKE para ignorar la hora
      return await db.rawQuery('''
        SELECT u.NOMBRE_VENDEDOR, SUM(rv.TOTAL) AS TOTAL_VENTAS
        FROM REGISTRO_DE_VENTAS rv
        JOIN USUARIO u ON rv.USUARIO_ID = u.ID_USUARIO
        WHERE rv.FECHA LIKE ?
        GROUP BY u.NOMBRE_VENDEDOR
        ORDER BY TOTAL_VENTAS DESC
      ''', ['$fechaInicio%']);
    } else {
      // Filtro para el MES ACTUAL (desde el día 1 hasta fin de mes)
      final primerDiaMes = DateTime(hoy.year, hoy.month, 1);
      final ultimoDiaMes = DateTime(hoy.year, hoy.month + 1, 0);

      fechaInicio =
          "${primerDiaMes.year}-${primerDiaMes.month.toString().padLeft(2, '0')}-${primerDiaMes.day.toString().padLeft(2, '0')} 00:00:00";
      fechaFin =
          "${ultimoDiaMes.year}-${ultimoDiaMes.month.toString().padLeft(2, '0')}-${ultimoDiaMes.day.toString().padLeft(2, '0')} 23:59:59";

      return await db.rawQuery('''
        SELECT u.NOMBRE_VENDEDOR, SUM(rv.TOTAL) AS TOTAL_VENTAS
        FROM REGISTRO_DE_VENTAS rv
        JOIN USUARIO u ON rv.USUARIO_ID = u.ID_USUARIO
        WHERE rv.FECHA BETWEEN ? AND ?
        GROUP BY u.NOMBRE_VENDEDOR
        ORDER BY TOTAL_VENTAS DESC
      ''', [fechaInicio, fechaFin]);
    }
  }

  Future<Map<String, dynamic>?> obtenerVendedorDelMes() async {
    // Reutilizamos la lógica mensual y tomamos el primero
    final rankingMensual = await obtenerVentasPorVendedor(periodo: 'mes');
    if (rankingMensual.isNotEmpty) {
      return rankingMensual.first;
    }
    return null;
  }

  Future<double> obtenerVentasDia() async {
    final db = await _databaseHelper.database;
    DateTime hoy = DateTime.now();
    String fechaIso =
        "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

    final result = await db.rawQuery('''
      SELECT SUM(TOTAL) AS TOTAL_HOY 
      FROM REGISTRO_DE_VENTAS 
      WHERE FECHA LIKE ?
    ''', ['$fechaIso%']);

    final val = result.first['TOTAL_HOY'];
    return (val is num) ? val.toDouble() : 0.0;
  }

  Future<int> obtenerConteoBajoStock() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS CANTIDAD 
      FROM PRODUCTO 
      WHERE Cantidad_Total <= Stock_Minimo AND Cantidad_Total > 0
    ''');
    final val = result.first['CANTIDAD'];
    return (val is num) ? val.toInt() : 0;
  }

  Future<int> obtenerConteoVencimientos() async {
    try {
      final db = await _databaseHelper.database;
      final hoy = DateTime.now();
      final limite = hoy.add(const Duration(days: 30));

      final fechaLimiteIso =
          "${limite.year}-${limite.month.toString().padLeft(2, '0')}-${limite.day.toString().padLeft(2, '0')}";

      // Consultamos la tabla FECHA_VENCIMIENTO
      // Contamos lotes que ya vencieron ( < hoy) o que vencen pronto ( <= limite)
      final result = await db.rawQuery('''
        SELECT COUNT(*) as CANTIDAD
        FROM FECHA_VENCIMIENTO
        WHERE fecha_vencimiento <= ?
      ''', [fechaLimiteIso]);

      final val = result.first['CANTIDAD'];
      return (val is num) ? val.toInt() : 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> obtenerVentasSemanaTotal() async {
    final db = await _databaseHelper.database;
    DateTime hoy = DateTime.now();
    DateTime inicioSemana =
        hoy.subtract(Duration(days: hoy.weekday - 1)); // Lunes
    DateTime finSemana = inicioSemana.add(const Duration(days: 6)); // Domingo

    String inicioIso =
        "${inicioSemana.year}-${inicioSemana.month.toString().padLeft(2, '0')}-${inicioSemana.day.toString().padLeft(2, '0')} 00:00:00";
    String finIso =
        "${finSemana.year}-${finSemana.month.toString().padLeft(2, '0')}-${finSemana.day.toString().padLeft(2, '0')} 23:59:59";

    final result = await db.rawQuery('''
      SELECT SUM(TOTAL) AS TOTAL_SEMANA
      FROM REGISTRO_DE_VENTAS
      WHERE FECHA BETWEEN ? AND ?
    ''', [inicioIso, finIso]);

    final val = result.first['TOTAL_SEMANA'];
    return (val is num) ? val.toDouble() : 0.0;
  }

  Future<List<Map<String, dynamic>>> obtenerRentabilidad() async {
    final db = await _databaseHelper.database;
    // Estimación de rentabilidad basada en precios y costos actuales
    // Nota: Esto es una aproximación ya que los costos podrían haber cambiado
    return await db.rawQuery('''
      SELECT 
        p.Nombre_Producto,
        SUM(dv.CANTIDAD * dv.PRECIO_VENTA) AS INGRESOS,
        SUM(dv.CANTIDAD * 
          CASE 
            WHEN dv.TIPO_VENTA = 'Venta por unidad' THEN p.Costo_Unidad
            WHEN dv.TIPO_VENTA = 'Venta por caja' THEN p.Costo_Caja
            ELSE p.Costo_Unidad -- Fallback
          END
        ) AS COSTOS
      FROM DETALLES_VENTA dv
      JOIN PRODUCTO p ON dv.PRODUCTO_ID = p.ID
      GROUP BY p.Nombre_Producto
      ORDER BY (INGRESOS - COSTOS) DESC
      LIMIT 5
    ''');
  }

  Future<List<Map<String, dynamic>>> obtenerValorInventario() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('''
      SELECT 
        SUM(Cantidad_Total * Costo_Unidad) AS VALOR_COSTO,
        SUM(Cantidad_Total * Precio_Unidad) AS VALOR_VENTA
      FROM PRODUCTO
      WHERE Cantidad_Total > 0
    ''');
  }
}
