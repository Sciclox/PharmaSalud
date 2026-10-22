import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/database/database_helper.dart';

class VencimientosDetalleDialog extends StatefulWidget {
  const VencimientosDetalleDialog({super.key});

  @override
  _VencimientosDetalleDialogState createState() =>
      _VencimientosDetalleDialogState();
}

class _VencimientosDetalleDialogState extends State<VencimientosDetalleDialog> {
  List<Map<String, dynamic>> _lotesVencidos = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _cargarDetalleVencimientos();
  }

  Future<void> _cargarDetalleVencimientos() async {
    final db = await _dbHelper.database;
    final hoy = DateTime.now();
    final limite = hoy.add(const Duration(days: 30));

    final fechaLimiteIso =
        "${limite.year}-${limite.month.toString().padLeft(2, '0')}-${limite.day.toString().padLeft(2, '0')}";

    try {
      // Consulta con JOIN para traer nombre del producto + fecha vencimiento
      final result = await db.rawQuery('''
        SELECT 
          p.Nombre_Producto,
          v.Fecha_Vencimiento,
          v.Cantidad
        FROM FECHA_VENCIMIENTO v
        JOIN PRODUCTO p ON v.Producto_ID = p.ID
        WHERE v.Fecha_Vencimiento <= ?
        ORDER BY v.Fecha_Vencimiento ASC
      ''', [fechaLimiteIso]);

      if (mounted) {
        setState(() {
          _lotesVencidos = List<Map<String, dynamic>>.from(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lotesVencidos = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header estilo "Success" Pharma
            _buildHeaderStyle(),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : _lotesVencidos.isEmpty
                      ? _buildEmptyStateStyle()
                      : _buildLotesListStyle(),
            ),

            _buildFooterStyle(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStyle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1D1D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Alertas de Vencimiento",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Outfit',
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Seguimiento de lotes próximos a expirar",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotesListStyle() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true,
      itemCount: _lotesVencidos.length,
      itemBuilder: (context, index) {
        final lote = _lotesVencidos[index];
        final fechaRaw = lote['Fecha_Vencimiento'] as String;
        final cantidad = lote['Cantidad'];
        final nombre = lote['Nombre_Producto'] ?? 'Desconocido';

        DateTime fechaDt = DateTime.parse(fechaRaw);
        final fechaFmt = DateFormat('dd/MM/yyyy').format(fechaDt);

        // Obtenemos solo la fecha de hoy sin la hora para una comparación exacta
        final hoy = DateTime.now();
        final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
        final fechaDtSinHora =
            DateTime(fechaDt.year, fechaDt.month, fechaDt.day);

        // Es vencido si la fecha es hoy o anterior
        final esVencido = fechaDtSinHora.isBefore(hoySinHora) ||
            fechaDtSinHora.isAtSameMomentAs(hoySinHora);

        final colorAcento =
            esVencido ? const Color(0xFFFF3B30) : const Color(0xFFFF9500);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorAcento,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        esVencido
                            ? 'venció el $fechaFmt'.toUpperCase()
                            : 'vence el $fechaFmt'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorAcento,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$cantidad',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: colorAcento,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      Text(
                        'UNDS',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateStyle() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 64, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            'Lotes en Orden',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D1D1F),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStyle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3B30),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: const Text(
            "ENTENDIDO",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}
