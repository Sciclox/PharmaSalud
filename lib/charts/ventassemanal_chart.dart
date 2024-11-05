import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/chart_repository.dart';
import 'package:intl/intl.dart';

class VentasChartSemanal extends StatefulWidget {
  @override
  _VentasChartSemanalState createState() => _VentasChartSemanalState();
}

class _VentasChartSemanalState extends State<VentasChartSemanal> {
  final ChartRepository _chartRepository = ChartRepository();
  List<BarChartGroupData> ventasData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVentasData();
  }

  Future<void> _loadVentasData() async {
    List<Map<String, dynamic>> ventas = await _chartRepository.obtenerVentasSemanales();

    // Inicializar lista con 0 para cada día de la semana
    List<double> ventasPorDia = List.generate(7, (index) => 0.0);

    // Formateador para el formato dd/MM/yyyy
    DateFormat dateFormat = DateFormat('dd/MM/yyyy');

    // Procesar las ventas y asignar los totales a cada día
    for (var venta in ventas) {
      try {
        // Parsear la fecha usando el formateador
        DateTime fecha = dateFormat.parse(venta['FECHA']);
        double totalDia = venta['TOTAL_DIA'] ?? 0.0;
        int diaSemana = fecha.weekday - 1; // Lunes es 1, por lo que restamos 1 para hacer coincidir con el índice

        ventasPorDia[diaSemana] = totalDia;
      } catch (e) {
        print('Error al analizar la fecha: ${venta['FECHA']}');
      }
    }

    // Crear los datos del gráfico usando los datos procesados
    ventasData = ventasPorDia.asMap().entries.map((entry) {
      int index = entry.key;
      double value = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
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
      );
    }).toList();

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
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: false, // Ocultar los títulos del eje izquierdo
      ),
    ),
    rightTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: false, // Ocultar los títulos del eje derecho
      ),
    ),
    topTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: false, // Ocultar los títulos del eje superior
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true, // Mantener visibles los títulos del eje inferior
        reservedSize: 40,
        getTitlesWidget: (value, meta) {
          List<String> days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
          return Text(
            days[value.toInt()],
            style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500), // Texto más claro
          );
        },
      ),
    ),
  ),
  borderData: FlBorderData(
    show: true,
    border: Border.all(color: Colors.grey[300]!, width: 1), // Mantener los bordes
  ),
  barGroups: ventasData, // Aquí usamos los datos dinámicos cargados
)

              ),
            ),
          );
  }
}
