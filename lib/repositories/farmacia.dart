import 'package:pharma_salud/database/database_helper.dart';

class FarmaciaRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  Future<List<Map<String, dynamic>>> obtenerTodas() async {
    final db = await _databaseHelper.database;
    return await db.rawQuery('SELECT * FROM FARMACIA ORDER BY NOMBRE');
  }

  Future<Map<String, dynamic>?> obtenerActiva() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery('SELECT * FROM FARMACIA WHERE ACTIVA = 1 LIMIT 1');
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<int> crear({required String nombre}) async {
    final db = await _databaseHelper.database;
    return await db.insert('FARMACIA', {
      'NOMBRE': nombre,
      'ACTIVA': 0,
    });
  }

  Future<void> actualizar({required int id, required String nombre}) async {
    final db = await _databaseHelper.database;
    await db.update('FARMACIA', {'NOMBRE': nombre}, where: 'ID = ?', whereArgs: [id]);
  }

  Future<void> establecerActiva(int id) async {
    final db = await _databaseHelper.database;
    await db.rawUpdate('UPDATE FARMACIA SET ACTIVA = 0');
    await db.rawUpdate('UPDATE FARMACIA SET ACTIVA = 1 WHERE ID = ?', [id]);
  }

  Future<void> eliminar(int id) async {
    final db = await _databaseHelper.database;
    await db.delete('FARMACIA', where: 'ID = ?', whereArgs: [id]);
  }
}
