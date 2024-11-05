import 'package:flutter/material.dart';
import 'package:pharma_salud/charts/ventas_chart.dart';
import 'package:pharma_salud/charts/ventassemanal_chart.dart';

class DashboardInicialScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDashboardTitle(),
            SizedBox(height: 20), // Espacio entre el título y el contenido
            _buildChartWithTitle('Ventas Mensuales', VentasChart(), Colors.blue), // Cambiar color del título de Ventas Mensuales
            SizedBox(height: 40), // Espacio entre los gráficos
            _buildChartWithTitle('Ventas Semanales', VentasChartSemanal(), Colors.green), // Cambiar color del título de Ventas Semanales
          ],
        ),
      ),
    );
  }

  // Función para crear un título encima del gráfico con color personalizado
  Widget _buildChartWithTitle(String title, Widget chart, Color titleColor) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: titleColor, // Aplicar el color personalizado al título
          ),
        ),
        SizedBox(height: 10), // Espacio entre el título y el gráfico
        chart,
      ],
    );
  }

  Widget _buildDashboardTitle() {
    return Container(
      padding: EdgeInsets.all(16.0),
      color: const Color.fromARGB(255, 255, 0, 0),
      width: double.infinity,
      child: Text(
        'Dashboard Farmacia',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildIconColumn(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 40,
          color: const Color.fromARGB(255, 255, 0, 0),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
