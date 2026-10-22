import 'package:fl_chart/fl_chart.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';
import 'dart:math' as math;

class VentasChart extends StatefulWidget {
  const VentasChart({super.key});

  @override
  _VentasChartState createState() => _VentasChartState();
}

class _VentasChartState extends State<VentasChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<double> ventasPorMes = List.filled(12, 0.0);
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatosVentas();
  }

  Future<void> cargarDatosVentas() async {
    try {
      final List<Map<String, dynamic>> datos =
          await _chartRepository.obtenerVentasMensuales();
      List<double> ventas = List.filled(12, 0.0);
      for (var fila in datos) {
        final int mesIndex = int.parse(fila['MES']) - 1;
        ventas[mesIndex] = (fila['TOTAL_MES'] is int)
            ? fila['TOTAL_MES'].toDouble()
            : fila['TOTAL_MES'];
      }
      setState(() {
        ventasPorMes = ventas;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 450,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
        ),
      );
    }

    double maxVenta = ventasPorMes.reduce(math.max);
    if (maxVenta == 0) maxVenta = 1000;
    double trackMax = maxVenta * 1.15; // 15% padding at the top

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance Anual',
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
                    'Volumen de ventas mensuales acumuladas',
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
            height: 380,
            child: BarChart(
              BarChartData(
                maxY: trackMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFE5E5EA), // Light Gray
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55, // Más espacio para el conector 3D
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index > 11) return const SizedBox.shrink();

                        const months = [
                          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                          'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
                        ];

                        final List<Color> monthColors = [
                          const Color(0xFF8BC34A), const Color(0xFF00BFA5), const Color(0xFF03A9F4),
                          const Color(0xFF3F51B5), const Color(0xFF0097A7), const Color(0xFF4CAF50),
                          const Color(0xFF00BCD4), const Color(0xFF2196F3), const Color(0xFF673AB7),
                          const Color(0xFF00897B), const Color(0xFFFF7043), const Color(0xFF607D8B),
                        ];

                        // Contenedor de 64px de ancho centrado bajo la barra de 32px
                        return SizedBox(
                          width: 64,
                          height: 44,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 2. Intersección de camino (Profundidad 3D)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _SlantedConnectorPainter(color: monthColors[index]),
                                ),
                              ),
                              // 3. Bloque del Mes (Cara Frontal)
                              Positioned(
                                left: 0, // Desplazado a la izquierda por el efecto isométrico
                                top: 20, // Empieza donde termina la rampa
                                width: 32, // Mismo ancho que la barra
                                height: 24,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: monthColors[index], // Color sólido frontal
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.1),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: monthColors[index].withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    months[index],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 65,
                      interval: (trackMax / 5) > 0 ? (trackMax / 5) : 100, // Forzar separación de intervalos
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text(
                            'S/ ${formatMoney(value)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final List<Color> monthColors = [
                    const Color(0xFF8BC34A), const Color(0xFF00BFA5), const Color(0xFF03A9F4),
                    const Color(0xFF3F51B5), const Color(0xFF0097A7), const Color(0xFF4CAF50),
                    const Color(0xFF00BCD4), const Color(0xFF2196F3), const Color(0xFF673AB7),
                    const Color(0xFF00897B), const Color(0xFFFF7043), const Color(0xFF607D8B),
                  ];

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: ventasPorMes[i],
                        width: 32, // 1. La Barra (Mismo ancho que el bloque frontal)
                        borderRadius: BorderRadius.zero, // Punta plana para bloque 3D
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            monthColors[i], // Color base idéntico a la cara frontal
                            monthColors[i].withOpacity(0.85), // Ligeramente iluminado arriba
                          ],
                        ),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: trackMax,
                          color: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    tooltipMargin: 16,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const meses = [
                        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
                      ];

                      final List<Color> monthColors = [
                        const Color(0xFF8BC34A), const Color(0xFF00BFA5), const Color(0xFF03A9F4),
                        const Color(0xFF3F51B5), const Color(0xFF0097A7), const Color(0xFF4CAF50),
                        const Color(0xFF00BCD4), const Color(0xFF2196F3), const Color(0xFF673AB7),
                        const Color(0xFF00897B), const Color(0xFFFF7043), const Color(0xFF607D8B),
                      ];

                      return BarTooltipItem(
                        "${meses[group.x.toInt()]}\n",
                        const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: "S/ ${formatMoney(rod.toY)}",
                            style: TextStyle(
                              color: monthColors[group.x.toInt()], // El número es del mismo color del mes
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Outfit',
                              fontSize: 18,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlantedConnectorPainter extends CustomPainter {
  final Color color;
  _SlantedConnectorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // El lienzo tiene 64 de ancho. La barra está centrada (16 a 48).
    final path = Path();
    path.moveTo(16, 0);  // Borde superior izquierdo (toca base izq de la barra)
    path.lineTo(48, 0);  // Borde superior derecho (toca base der de la barra)
    path.lineTo(32, 20); // Borde inferior derecho (toca tope der del bloque frontal)
    path.lineTo(0, 20);  // Borde inferior izquierdo (toca tope izq del bloque frontal)
    path.close();

    // Relleno más claro simulando luz desde arriba (techo isométrico)
    final fillPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);

    // Contorno sutil para darle forma geométrica
    final strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
