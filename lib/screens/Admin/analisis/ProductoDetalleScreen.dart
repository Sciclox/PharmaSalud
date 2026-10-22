import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/screens/Admin/analisis/graficoVentas.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class ProductoDetalleScreen extends StatelessWidget {
  final Map<String, dynamic> producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorTendencia(String t) {
    switch (t) {
      case 'EN AUMENTO':
        return Colors.orangeAccent;
      case 'EN DESCENSO':
        return Colors.blueGrey;
      case 'INDETERMINADO':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color recomendacionColor =
        producto['recomendacion'].toString().contains("PEDIR")
            ? Colors.redAccent
            : (producto['recomendacion'] == 'NO SE VENDE'
                ? Colors.grey
                : Colors.green);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(226, 226, 226, 1),
      body: Column(
        children: [
          // 🔹 Encabezado fijo
          Container(
            margin: EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    producto['nombre'] ?? 'Detalle de producto',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Contenido scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Card con info general
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                        topLeft: Radius.zero,
                        bottomLeft: Radius.zero,
                      ),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black12,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: recomendacionColor, width: 6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.trending_up,
                                      size: 16, color: Colors.white),
                                  label: Text(
                                    producto['tendencia'] ?? '—',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: _colorTendencia(
                                      producto['tendencia'] ?? ''),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  avatar: const Icon(Icons.local_shipping,
                                      size: 16, color: Colors.white),
                                  label: Text(
                                    producto['recomendacion'] ?? '—',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: recomendacionColor,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _infoRow(
                                'Días Activos',
                                formatDias(int.tryParse(
                                        producto['diasActivos'].toString()) ??
                                    0)),
                            _infoRow('Agotamiento Estimado',
                                formatAgotamiento(producto['diasRestantes'])),
                            _infoRow('Total Vendidas',
                                '${producto['totalVendidas']}'),
                            _infoRow('Frecuencia Diaria',
                                '${producto['frecuenciaDiaria']} / día'),
                            _infoRow('Frecuencia Semanal',
                                '${producto['frecuenciaSemanal']} / sem'),
                            _infoRow('Ventas Última Semana',
                                '${producto['ventasUltimaSemana']}'),
                            const SizedBox(height: 8),
                            _infoRow('Proyección (Semana)',
                                '${producto['proyeccionSemana']}'),
                            _infoRow(
                                'Stock Total', '${producto['stockTotal']}'),
                            _infoRow('Stock Útil', '${producto['stockUtil']}'),
                            _infoRow('Vencidos', '${producto['vencidos']}'),
                            _infoRow('Margen Ganancia',
                                'S/ ${producto['margenGanancia']}'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card con gráfico de ventas
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 6,
                    shadowColor: Colors.black12,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: ventasPorMes(producto['id']),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 220,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.redAccent,
                                ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.show_chart,
                                      size: 18, color: Colors.black54),
                                  SizedBox(width: 6),
                                  Text(
                                    'Ventas últimos 12 meses',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GraficoVentas(ventasMensuales: snapshot.data!),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
