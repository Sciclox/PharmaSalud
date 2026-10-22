import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';

class TopProductosChart extends StatefulWidget {
  const TopProductosChart({super.key});

  @override
  _TopProductosChartState createState() => _TopProductosChartState();
}

class _TopProductosChartState extends State<TopProductosChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<Map<String, dynamic>> topProductos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final datos = await _chartRepository.obtenerTopProductos();
      setState(() {
        topProductos = datos;
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

    final List<Color> prodColors = [
      const Color(0xFFE91E63), // Top 1: Rosa Fuerte
      const Color(0xFF9C27B0), // Top 2: Morado
      const Color(0xFF3F51B5), // Top 3: Indigo
      const Color(0xFF03A9F4), // Top 4: Azul Claro
      const Color(0xFF00BFA5), // Top 5: Teal
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
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top 5 Productos',
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
                    'Artículos con mayor volumen de venta',
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
                maxY: topProductos.isNotEmpty ? (topProductos.map((e) => e['TOTAL_VENDIDO']).reduce((a, b) => a > b ? a : b) * 1.2) : 100,
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
                        if (index < 0 || index >= topProductos.length) return const SizedBox.shrink();
                        
                        String name = topProductos[index]['NOMBRE_PRODUCTO'];
                        if (name.length > 8) name = name.substring(0, 8);

                        return SizedBox(
                          width: 80,
                          height: 44,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _SlantedConnectorPainter(color: prodColors[index % prodColors.length], barWidth: 40),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 16,
                                width: 40,
                                height: 24,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: prodColors[index % prodColors.length],
                                    border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: prodColors[index % prodColors.length].withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Outfit',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                barGroups: List.generate(topProductos.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: topProductos[i]['TOTAL_VENDIDO'].toDouble(),
                        width: 40, // Mismo ancho que el bloque frontal
                        borderRadius: BorderRadius.zero,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            prodColors[i % prodColors.length],
                            prodColors[i % prodColors.length].withOpacity(0.85),
                          ],
                        ),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: topProductos.map((e) => e['TOTAL_VENDIDO']).reduce((a, b) => a > b ? a : b) * 1.2,
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
                      return BarTooltipItem(
                        "${topProductos[groupIndex]['NOMBRE_PRODUCTO']}\n",
                        const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: "${rod.toY.toInt()} Unidades",
                            style: TextStyle(
                              color: prodColors[groupIndex % prodColors.length],
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
  final double barWidth;
  _SlantedConnectorPainter({required this.color, required this.barWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // Si canvas width es 80 y barWidth es 40.
    // startX = (80 - 40) / 2 = 20
    final double startX = (size.width - barWidth) / 2;
    final double endX = startX + barWidth;
    final double offset = barWidth / 2; // Desplazamiento isométrico
    
    final path = Path();
    path.moveTo(startX, 0);  // Borde sup izq (toca la barra)
    path.lineTo(endX, 0);  // Borde sup der
    path.lineTo(endX - offset, 16); // Borde inf der (desplazado a la izq)
    path.lineTo(startX - offset, 16);  // Borde inf izq
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
