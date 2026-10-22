import 'package:fl_chart/fl_chart.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';

class VentasCategoriaChart extends StatefulWidget {
  const VentasCategoriaChart({super.key});

  @override
  _VentasCategoriaChartState createState() => _VentasCategoriaChartState();
}

class _VentasCategoriaChartState extends State<VentasCategoriaChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<Map<String, dynamic>> datosCategoria = [];
  bool isLoading = true;

  final List<Color> colors = [
    const Color(0xFFFF3B30), // Rojo Pharma
    const Color(0xFF007AFF), // Azul Apple
    const Color(0xFF34C759), // Verde Apple
    const Color(0xFFFFCC00), // Amarillo Apple
    const Color(0xFF5856D6), // Indigo
    const Color(0xFFAF52DE), // Purpura
    const Color(0xFFFF9500), // Naranja
  ];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final datos = await _chartRepository.obtenerVentasPorCategoria();
      setState(() {
        datosCategoria = datos;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const SizedBox(
          height: 300, child: Center(child: CircularProgressIndicator()));
    if (datosCategoria.isEmpty) return const SizedBox();

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
                    colors: [Color(0xFF8BC34A), Color(0xFF388E3C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF388E3C).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.category_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ventas por Categoría',
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
                    'Distribución del ingreso por líneas de negocio',
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
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(
                      '${datosCategoria.length}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1C1C1E),
                        fontFamily: 'Outfit',
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 80,
                    sections: List.generate(datosCategoria.length, (index) {
                      final dato = datosCategoria[index];
                      final double total = dato['TOTAL'].toDouble();

                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: total,
                        title: '',
                        radius: 32, // Donut más delgado
                        badgeWidget: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(Icons.local_pharmacy_rounded, size: 14, color: colors[index % colors.length]),
                        ),
                        badgePositionPercentageOffset: 1.1,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              children: datosCategoria.asMap().entries.map((entry) {
                final index = entry.key;
                final dato = entry.value;
                final String categoria = dato['Tipo_Producto'];
                final double total = dato['TOTAL'].toDouble();

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: colors[index % colors.length].withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          categoria,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                            fontFamily: 'Outfit',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'S/ ${formatMoney(total)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
