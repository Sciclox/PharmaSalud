import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/chart_repository.dart';

class VentasChart extends StatefulWidget {
  const VentasChart({super.key});

  @override
  _VentasChartState createState() => _VentasChartState();
}

class _VentasChartState extends State<VentasChart> {
  final ChartRepository chartRepository = ChartRepository();
  List<BarChartGroupData> barGroups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVentasData();
  }

  // Función para cargar los datos de ventas
  Future<void> _loadVentasData() async {
    List<Map<String, dynamic>> ventasMensuales = await chartRepository.obtenerVentasMensuales();

    // Inicializar la lista de ventas con 12 meses
    List<double> ventasPorMes = List.filled(12, 0.0);

    // Rellenar la lista con los datos de ventas
    for (var venta in ventasMensuales) {
      if (venta['MES'] != null && venta['MES'].toString().isNotEmpty) {
        int mes = int.tryParse(venta['MES'].toString()) ?? 1;
        double total = double.tryParse(venta['TOTAL_MES'].toString()) ?? 0.0;

        // Almacenar el total en el índice correspondiente (mes - 1)
        ventasPorMes[mes - 1] = total;
      }
    }

    // Crear los grupos de barras a partir de la lista de ventas
    for (int i = 0; i < ventasPorMes.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: ventasPorMes[i],
              color: Color.fromRGBO(135, 206, 235, 0.8), // Color de las barras (azul suave)
              width: 45, // Ancho de las barras
              borderRadius: BorderRadius.circular(12), // Esquinas redondeadas
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100, // Ajustar según el rango de datos
                color: Color.fromRGBO(255, 182, 193, 0.5), // Color de fondo de la barra (rosado suave)
              ),
            ),
          ],
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator()) // Muestra un indicador de carga mientras se cargan los datos
        : Container(
            width: 1000,
            height: 400,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color.fromRGBO(255, 255, 255, 1), // Color de fondo blanco
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2), // Sombra suave
                  offset: Offset(2, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false), // Mostrar líneas de cuadrícula
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          List<String> months = [
                            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                            'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
                          ];
                          return Text(
                            months[value.toInt()],
                            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500), // Texto más claro
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // No mostrar títulos del eje Y
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // No mostrar títulos en la parte superior
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // No mostrar títulos en el lado derecho
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 1), // Color de los bordes más suaves
                  ),
                  barGroups: barGroups, // Aquí usamos los datos dinámicos cargados
                ),
              ),
            ),
          );
  }
}
