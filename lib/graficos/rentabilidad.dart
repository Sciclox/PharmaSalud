import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class RentabilidadChart extends StatefulWidget {
  const RentabilidadChart({super.key});

  @override
  _RentabilidadChartState createState() => _RentabilidadChartState();
}

class _RentabilidadChartState extends State<RentabilidadChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<Map<String, dynamic>> datosRentabilidad = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final datos = await _chartRepository.obtenerRentabilidad();
      setState(() {
        datosRentabilidad = datos;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
          height: 350, child: Center(child: CircularProgressIndicator()));
    }
    if (datosRentabilidad.isEmpty) return const SizedBox();

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            spacing: 16,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5856D6), Color(0xFF3F51B5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3F51B5).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.insights_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rentabilidad Operativa',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1C1C1E),
                            fontFamily: 'Outfit',
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Top 5 productos con mayor margen comercial',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          Builder(
            builder: (context) {
              final double maxIngresos = datosRentabilidad.isNotEmpty 
                  ? datosRentabilidad.map((e) => (e['INGRESOS'] as num).toDouble()).reduce((a, b) => a > b ? a : b) 
                  : 100.0;
              final double maxY = maxIngresos * 1.2;
              final double intervalY = maxY > 0 ? (maxY / 5).ceilToDouble() : 20.0;

              return SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: intervalY == 0 ? 1 : intervalY,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xFF000000).withOpacity(0.04),
                        strokeWidth: 2,
                        dashArray: [8, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          interval: intervalY == 0 ? 1 : intervalY,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value >= maxY) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toInt().toString(),
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < datosRentabilidad.length) {
                              String nombre = datosRentabilidad[value.toInt()]['Nombre_Producto'];
                              if (nombre.length > 10) nombre = '${nombre.substring(0, 8)}...';
                              return SizedBox(
                                width: 50,
                                height: 46,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _DoubleSlantedConnectorPainter(
                                          colorLeft: const Color(0xFF34C759),
                                          colorRight: const Color(0xFFFF3B30),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 20,
                                      width: 34,
                                      height: 20,
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.black.withAlpha(25), width: 1),
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          nombre,
                                          style: const TextStyle(
                                            color: Color(0xFF1D1D1F),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'Outfit',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    groupsSpace: 24, // Espacio entre grupos de barras
                    barGroups: List.generate(datosRentabilidad.length, (i) {
                      final data = datosRentabilidad[i];
                      final ingresos = (data['INGRESOS'] as num).toDouble();
                      final costos = (data['COSTOS'] as num).toDouble();

                      return BarChartGroupData(
                        x: i,
                        barsSpace: 6, // Espacio entre barra de costo y barra de ingreso
                        barRods: [
                          BarChartRodData(
                            toY: ingresos,
                            color: const Color(0xFF34C759),
                            width: 14,
                            borderRadius: BorderRadius.zero,
                          ),
                          BarChartRodData(
                            toY: costos,
                            color: const Color(0xFFFF3B30),
                            width: 14,
                            borderRadius: BorderRadius.zero,
                          ),
                        ],
                      );
                    }),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1D1D1F),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final data = datosRentabilidad[groupIndex];
                          final String nombre = data['Nombre_Producto'];
                          final double val = rod.toY;
                          final String label = rodIndex == 0 ? "Ingresos" : "Costos";
                          final Color color = rodIndex == 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
                          return BarTooltipItem(
                            "$nombre\n",
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
                            children: [
                              TextSpan(
                                text: "$label: S/ ${formatMoney(val)}",
                                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ]
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Color(0xFF34C759), label: 'Ingresos'),
                SizedBox(width: 32),
                _LegendItem(color: Color(0xFFFF3B30), label: 'Costos'),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D1D1F),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}

class _DoubleSlantedConnectorPainter extends CustomPainter {
  final Color colorLeft;
  final Color colorRight;

  _DoubleSlantedConnectorPainter({required this.colorLeft, required this.colorRight});

  @override
  void paint(Canvas canvas, Size size) {
    // Left Bar Connector
    final pathLeft = Path();
    pathLeft.moveTo(16, 0);
    pathLeft.lineTo(30, 0);
    pathLeft.lineTo(14, 20);
    pathLeft.lineTo(0, 20);
    pathLeft.close();

    final fillLeft = Paint()
      ..color = colorLeft.withAlpha(128)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pathLeft, fillLeft);

    final stroke = Paint()
      ..color = Colors.black.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(pathLeft, stroke);

    // Right Bar Connector
    final pathRight = Path();
    pathRight.moveTo(36, 0);
    pathRight.lineTo(50, 0);
    pathRight.lineTo(34, 20);
    pathRight.lineTo(20, 20);
    pathRight.close();

    final fillRight = Paint()
      ..color = colorRight.withAlpha(128)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pathRight, fillRight);
    canvas.drawPath(pathRight, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

