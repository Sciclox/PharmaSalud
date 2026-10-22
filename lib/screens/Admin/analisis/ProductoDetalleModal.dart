import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/screens/Admin/analisis/graficoVentas.dart';

class ProductoDetalleModal extends StatelessWidget {
  final Map<String, dynamic> producto;

  const ProductoDetalleModal({super.key, required this.producto});

  @override
  Widget build(BuildContext context) {
    final String rec = producto['recomendacion']?.toString().toUpperCase() ??
        'SIN RECOMENDACIÓN';
    final bool esUrgente = rec.contains("YA") ||
        rec.contains("CRÍTICO") ||
        rec.contains("URGENTE");
    final bool esPedir = rec.contains("REPOSICIÓN") || rec.contains("PEDIR");
    final bool esExceso = rec.contains("EXCESO");
    final bool sinSalida = rec.contains("SIN SALIDA");
    final bool sinVentas = (producto['totalVendidas'] as int? ?? 0) == 0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.35,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFD),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          bottomLeft: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 40, offset: Offset(-10, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      color: Color(0xFF1D1D1F),
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resumen Ejecutivo (El "Qué pasa")
                  _buildStatusSumary(
                      esUrgente, esPedir, esExceso, sinSalida, sinVentas),
                  const SizedBox(height: 24),

                  // Recomendación Directa (El "Qué hacer")
                  _buildActionAdvice(),
                  const SizedBox(height: 32),

                  // Detalles del Stock
                  _buildStockSection(),
                  const SizedBox(height: 32),

                  // Gráfico de Ventas
                  const Text('HISTORIAL DE VENTAS (Últimos 12 meses)',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _buildSalesChartSection(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1D1D1F),
          shape: const CircleBorder(),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildStatusSumary(bool esUrgente, bool esPedir, bool esExceso,
      bool sinSalida, bool sinVentas) {
    Color color = Colors.green;
    String titulo = "¡Todo va bien!";
    String sub = "El stock está en niveles óptimos.";
    IconData icon = Icons.check_circle_outline_rounded;

    if (esUrgente) {
      color = const Color(0xFFFF3B30);
      titulo = "¡Acción Requerida!";
      sub = (producto['stockUtil'] as num? ?? 0) <= 0
          ? "El producto ya se agotó."
          : "El producto está por agotarse.";
      icon = Icons.warning_amber_rounded;
    } else if (esPedir) {
      color = const Color(0xFFFF9500);
      titulo = "Atención";
      sub = "Es un buen momento para planear la compra.";
      icon = Icons.info_outline_rounded;
    } else if (esExceso) {
      color = Colors.purple;
      titulo = "Sobre Stock";
      sub = "Tienes demasiadas unidades. Evita comprar más.";
      icon = Icons.inventory_rounded;
    } else if (sinSalida || sinVentas) {
      color = Colors.blueGrey;
      titulo = "Sin Movimiento";
      sub = "Este producto no se ha vendido recientemente.";
      icon = Icons.inventory_2_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: color,
                            fontFamily: 'Outfit')),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontFamily: 'Outfit')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionAdvice() {
    final int compra = (producto['compraMensualSugerida'] as num? ?? 0).toInt();
    if (compra == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PLAN DE COMPRA',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Text(
            'Te recomendamos comprar ${producto['compraSugeridaTxt']}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Outfit',
                height: 1.1),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esto es suficiente para cubrir tus ventas de todo un mes basado en tu historial.',
            style: TextStyle(
                color: Colors.white70, fontSize: 13, fontFamily: 'Outfit'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    final dias = int.tryParse(producto['diasRestantes'].toString()) ?? 0;

    return Row(
      children: [
        Expanded(
            child: _miniMetric(
                'Stock Actual', producto['stockUtilTxt'] ?? '0 unidades')),
        const SizedBox(width: 16),
        Expanded(
            child: _miniMetric(
                'Dura aprox.', '$dias ${dias == 1 ? 'día' : 'días'}')),
      ],
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D1D1F))),
        ],
      ),
    );
  }

  Widget _buildSalesChartSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ventasPorMes(producto['ID'] ?? producto['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: GraficoVentas(ventasMensuales: snapshot.data!),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar Ventana',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
