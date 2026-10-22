import 'package:flutter/material.dart';
import 'package:pharma_salud/database/database_helper.dart';

class BajoStockDetalleDialog extends StatefulWidget {
  const BajoStockDetalleDialog({super.key});

  @override
  _BajoStockDetalleDialogState createState() => _BajoStockDetalleDialogState();
}

class _BajoStockDetalleDialogState extends State<BajoStockDetalleDialog> {
  List<Map<String, dynamic>> _productosBajoStock = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _cargarProductosBajoStock();
  }

  Future<void> _cargarProductosBajoStock() async {
    try {
      final db = await _dbHelper.database;

      // Consultar productos cuyo stock total es menor o igual al stock mínimo
      final result = await db.rawQuery('''
        SELECT 
          Nombre_Producto,
          Cantidad_Total,
          Stock_Minimo,
          Tipo_Producto
        FROM PRODUCTO
        WHERE Cantidad_Total <= Stock_Minimo
        ORDER BY Cantidad_Total ASC
      ''');

      if (mounted) {
        setState(() {
          _productosBajoStock = List<Map<String, dynamic>>.from(result);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _productosBajoStock = [];
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
                      child: CircularProgressIndicator(color: Colors.orange))
                  : _productosBajoStock.isEmpty
                      ? _buildEmptyStateStyle()
                      : _buildBajoStockListStyle(),
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
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Alertas de Bajo Stock",
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
            "Reponer inventario crítico de inmediato",
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

  Widget _buildBajoStockListStyle() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true,
      itemCount: _productosBajoStock.length,
      itemBuilder: (context, index) {
        final producto = _productosBajoStock[index];
        final nombre = producto['Nombre_Producto'] ?? 'Desconocido';
        final stockActual = producto['Cantidad_Total'];
        final esCritico = stockActual == 0;
        final colorAcento =
            esCritico ? const Color(0xFFFF3B30) : const Color(0xFFFF9500);

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
                        esCritico
                            ? 'AGOTADO COMPLETAMENTE'
                            : 'STOCK POR DEBAJO DEL MÍNIMO',
                        style: TextStyle(
                          fontSize: 10,
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
                        '$stockActual',
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
            child: const Icon(Icons.inventory_rounded,
                size: 64, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            'Inventario Óptimo',
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
