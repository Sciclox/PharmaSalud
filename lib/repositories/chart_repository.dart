import 'package:pharma_salud/database_helper.dart';

class ChartRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> obtenerVentasSemanales() async {
    // Obtener una referencia a la base de datos
    final db = await _databaseHelper.database;

    // Fecha actual
    DateTime hoy = DateTime.now();

    // Fecha de inicio de la semana (lunes)
    DateTime inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));

    // Fecha de fin de la semana (domingo)
    DateTime finSemana = inicioSemana.add(Duration(days: 6));

    // Formato de las fechas para la consulta (dd/MM/yyyy)
    String inicio = "${inicioSemana.day.toString().padLeft(2, '0')}/${inicioSemana.month.toString().padLeft(2, '0')}/${inicioSemana.year}";
    String fin = "${finSemana.day.toString().padLeft(2, '0')}/${finSemana.month.toString().padLeft(2, '0')}/${finSemana.year}";

    // Consulta para obtener ventas entre el lunes y domingo de la semana actual
    return await db.rawQuery('''
      SELECT FECHA, SUM(TOTAL) AS TOTAL_DIA
      FROM REGISTRO_DE_VENTAS
      WHERE FECHA BETWEEN ? AND ?
      GROUP BY FECHA
    ''', [inicio, fin]);
  }

Future<List<Map<String, dynamic>>> obtenerVentasMensuales() async {
  final db = await _databaseHelper.database;

  // Obtener el año actual
  int anioActual = DateTime.now().year; // Cambié 'añoActual' a 'anioActual'

  return await db.rawQuery('''
    SELECT strftime('%m', substr(FECHA, 7, 4) || '-' || substr(FECHA, 4, 2) || '-' || substr(FECHA, 1, 2)) AS MES,
           SUM(TOTAL) AS TOTAL_MES
    FROM REGISTRO_DE_VENTAS
    WHERE FECHA IS NOT NULL
    AND strftime('%Y', substr(FECHA, 7, 4) || '-' || substr(FECHA, 4, 2) || '-' || substr(FECHA, 1, 2)) = ?
    GROUP BY MES
    ORDER BY MES
  ''', [anioActual.toString()]);
}
  
}
