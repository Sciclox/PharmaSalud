import 'package:fl_chart/fl_chart.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';

class VentasChartSemanal extends StatefulWidget {
  const VentasChartSemanal({super.key});

  @override
  _VentasChartSemanalState createState() => _VentasChartSemanalState();
}

class _VentasChartSemanalState extends State<VentasChartSemanal> {
  final ChartRepository _chartRepository = ChartRepository();
  List<double> ventasPorDia = List.filled(7, 0.0);
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatosVentas();
  }

  Future<void> cargarDatosVentas() async {
    try {
      final List<Map<String, dynamic>> datos =
          await _chartRepository.obtenerVentasSemanales();
      List<double> ventas = List.filled(7, 0.0);
      for (var fila in datos) {
        // En SQLite strftime('%w') retorna: 0=Domingo, 1=Lunes, ..., 6=Sábado
        final int diaSql = fila['DIA_SQL'];
        // Mapeamos para que el Lunes (1) sea index 0, ..., Domingo (0) sea index 6
        int index = 0;
        if (diaSql == 0) {
          index = 6; // Domingo
        } else {
          index = diaSql - 1; // Lunes(1)->0, ..., Sábado(6)->5
        }

        final val = fila['TOTAL_DIA'];
        ventas[index] = (val is num) ? val.toDouble() : 0.0;
      }
      setState(() {
        ventasPorDia = ventas;
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
          height: 300, child: Center(child: CircularProgressIndicator()));
    }

    final List<Color> dayColors = [
      const Color(0xFF03A9F4), // L: Azul claro
      const Color(0xFF00BFA5), // M: Teal
      const Color(0xFF8BC34A), // M: Verde Limon
      const Color(0xFFFFB300), // J: Amarillo
      const Color(0xFFFF7043), // V: Naranja
      const Color(0xFFE91E63), // S: Rosa
      const Color(0xFF9C27B0), // D: Morado
    ];

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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ventas Semanales',
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
                    'Acumulado de los últimos 7 días',
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
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: (ventasPorDia.reduce((a, b) => a > b ? a : b) * 1.2) > 0 ? (ventasPorDia.reduce((a, b) => a > b ? a : b) * 1.2) : 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFE5E5EA),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index > 6) return const SizedBox.shrink();
                        const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

                        return SizedBox(
                          width: 48,
                          height: 44,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _SlantedConnectorPainter(color: dayColors[index]),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 16,
                                width: 24,
                                height: 24,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: dayColors[index],
                                    border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dayColors[index].withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    days[index],
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
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: ventasPorDia[i],
                        width: 24, // Mismo ancho que el bloque frontal
                        borderRadius: BorderRadius.zero,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            dayColors[i],
                            dayColors[i].withOpacity(0.85),
                          ],
                        ),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: ventasPorDia.reduce((a, b) => a > b ? a : b) * 1.2,
                          color: const Color(0xFFF3F4F6),
                        ),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    tooltipMargin: 12,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
                      return BarTooltipItem(
                        "${dias[group.x]}\n",
                        const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: "S/ ${formatMoney(rod.toY)}",
                            style: TextStyle(
                              color: dayColors[group.x],
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Outfit',
                              fontSize: 16,
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
    // Lienzo de ancho 48. Barra de 24px centrada (de 12 a 36).
    final path = Path();
    path.moveTo(12, 0);  // Borde sup izq
    path.lineTo(36, 0);  // Borde sup der
    path.lineTo(24, 16); // Borde inf der (desplazado izq)
    path.lineTo(0, 16);  // Borde inf izq
    path.close();

    final fillPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
