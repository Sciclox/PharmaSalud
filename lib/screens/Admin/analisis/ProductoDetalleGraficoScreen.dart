import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProductoDetalleGraficoScreen extends StatelessWidget {
  final Map<String, dynamic> producto;

  const ProductoDetalleGraficoScreen({super.key, required this.producto});

  List<FlSpot> convertirAFlSpots(List<dynamic> valores) {
    return valores.asMap().entries.map((e) {
      final x = e.key.toDouble();
      final y = double.tryParse(e.value.toString()) ?? 0.0;
      return FlSpot(x, y);
    }).toList();
  }

  Widget construirGraficoLinea(
      String titulo, List<dynamic> valores, Color color) {
    final spots = convertirAFlSpots(valores);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                      if (value >= 0 && value < dias.length) {
                        return Text(dias[value.toInt()]);
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: spots,
                  color: color,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
              gridData: FlGridData(show: true),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ventas = producto['ventasUltimaSemana'] ?? [];
    final frecuencia = producto['frecuenciaSemanal'] ?? [];
    final proyeccion = producto['proyeccionSemana'] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(producto['nombre'] ?? 'Producto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            construirGraficoLinea('Ventas Última Semana', ventas, Colors.blue),
            construirGraficoLinea(
                'Frecuencia Semanal', frecuencia, Colors.green),
            construirGraficoLinea('Proyección', proyeccion, Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Recomendación: ${producto['recomendacion']}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: producto['recomendacion'].toString().contains("PEDIR")
                    ? Colors.red
                    : (producto['recomendacion'] == 'NO SE VENDE'
                        ? Colors.orange
                        : Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
