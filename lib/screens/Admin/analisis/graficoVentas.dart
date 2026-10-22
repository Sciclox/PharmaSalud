import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GraficoVentas extends StatelessWidget {
  final List<Map<String, dynamic>> ventasMensuales;

  const GraficoVentas({required this.ventasMensuales, super.key});

  @override
  Widget build(BuildContext context) {
    if (ventasMensuales.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Sin historial de ventas',
            style: TextStyle(
                fontFamily: 'Outfit', color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    final List<FlSpot> spots = [
      for (int i = 0; i < ventasMensuales.length; i++)
        FlSpot(i.toDouble(), (ventasMensuales[i]["total"] as num).toDouble())
    ];

    double maxVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (maxVal < 5) maxVal = 5;

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 20, right: 10, left: 10),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= ventasMensuales.length)
                    return const SizedBox.shrink();

                  // Mostrar solo meses pares o el último para no saturar
                  if (index % 2 != 0 && index != ventasMensuales.length - 1)
                    return const SizedBox.shrink();

                  final mes = ventasMensuales[index]["mes"] as DateTime;
                  const nombresMes = [
                    'Ene',
                    'Feb',
                    'Mar',
                    'Abr',
                    'May',
                    'Jun',
                    'Jul',
                    'Ago',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dic'
                  ];

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      nombresMes[mes.month - 1],
                      style: TextStyle(
                        color: const Color(0xFF1D1D1F).withOpacity(0.3),
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (ventasMensuales.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal * 1.3,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1D1D1F),
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final index = barSpot.x.toInt();
                  final total = ventasMensuales[index]["total"];
                  return LineTooltipItem(
                    '$total unidades',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: const Color(0xFF007AFF),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF007AFF).withOpacity(0.2),
                    const Color(0xFF007AFF).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
