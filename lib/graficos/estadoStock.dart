import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';

class EstadoStockChart extends StatefulWidget {
  const EstadoStockChart({super.key});

  @override
  _EstadoStockChartState createState() => _EstadoStockChartState();
}

class _EstadoStockChartState extends State<EstadoStockChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<Map<String, dynamic>> datosStock = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final datos = await _chartRepository.obtenerEstadoStock();
      setState(() {
        datosStock = datos;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const SizedBox(
          height: 300, child: Center(child: CircularProgressIndicator()));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF2F2F7), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.01),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF57C00).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado del Inventario',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1C1C1E),
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Disponibilidad y alertas de agotamiento',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total Items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(
                      '${datosStock.fold<int>(0, (p, e) => p + (e['CANTIDAD'] as int))}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1C1E),
                        fontFamily: 'Outfit',
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                PieChart(
                  PieChartData(
                    startDegreeOffset: 180,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 90,
                    sections: List.generate(datosStock.length, (index) {
                      final dato = datosStock[index];
                      final String estado = dato['ESTADO'];
                      final int cantidad = dato['CANTIDAD'];

                      Color color;
                      switch (estado) {
                        case 'Agotado':
                          color = const Color(0xFFFF3B30);
                          break;
                        case 'Stock Bajo':
                          color = const Color(0xFFFFCC00);
                          break;
                        default:
                          color = const Color(0xFF34C759);
                      }

                      return PieChartSectionData(
                        color: color,
                        value: cantidad.toDouble(),
                        title: '',
                        radius: 24, // Arco delgado para look más limpio
                        badgeWidget: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Text(
                            '$cantidad',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        badgePositionPercentageOffset: 1.1,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: datosStock.map((dato) {
              final String estado = dato['ESTADO'];
              Color color;
              switch (estado) {
                case 'Agotado':
                  color = const Color(0xFFFF3B30);
                  break;
                case 'Stock Bajo':
                  color = const Color(0xFFFFCC00);
                  break;
                default:
                  color = const Color(0xFF34C759);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      estado,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }
}
