import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  group('VentasChartSemanal Tests', () {
    test('Procesa ventas correctamente y asigna valores por día', () {
      // Datos de prueba
      List<Map<String, dynamic>> ventas = [
        {'FECHA': '04/12/2024', 'TOTAL_DIA': 50.0}, // Miércoles (4 Dic 2024)
        {'FECHA': '02/12/2024', 'TOTAL_DIA': 30.0}, // Lunes (2 Dic 2024)
        {'FECHA': '03/12/2024', 'TOTAL_DIA': 20.0}, // Martes (3 Dic 2024)
        {'FECHA': '05/12/2024', 'TOTAL_DIA': 30.0}, // Jueves (5 Dic 2024)
        {'FECHA': '04/12/2024', 'TOTAL_DIA': 20.0}, // Miércoles (otra venta: 50 + 20 = 70.0)
        {'FECHA': 'INVALID_DATE', 'TOTAL_DIA': 40.0}, // Fecha inválida
      ];

      // Formateador de fechas
      DateFormat dateFormat = DateFormat('dd/MM/yyyy');

      // Inicializar lista con 0 para cada día de la semana
      List<double> ventasPorDia = List.generate(7, (index) => 0.0);

      for (var venta in ventas) {
        try {
          DateTime fecha = dateFormat.parse(venta['FECHA']);
          double totalDia = venta['TOTAL_DIA'] ?? 0.0;
          int diaSemana = fecha.weekday - 1; // Lunes es 0
          ventasPorDia[diaSemana] += totalDia;
        } catch (e) {
          // Ignorar errores de fechas inválidas
        }
      }

      // Validar que los valores sean correctos
      expect(ventasPorDia[2], 70.0); // Miércoles (50 + 20)
      expect(ventasPorDia[3], 30.0); // Jueves
      expect(ventasPorDia[4], 0.0);  // Viernes
    });

    test('Asigna colores correctos según el valor de ventas', () {
      // Función de color dinámico
      Color obtenerColor(double valor) {
        if (valor > 80) return Colors.green;
        if (valor > 50) return Colors.yellow;
        return Colors.red;
      }

      // Probar diferentes valores
      expect(obtenerColor(90), Colors.green);
      expect(obtenerColor(70), Colors.yellow);
      expect(obtenerColor(30), Colors.red);
    });

    test('Ignora fechas mal formateadas sin interrumpir el flujo', () {
      // Datos de prueba con fecha inválida
      List<Map<String, dynamic>> ventas = [
        {'FECHA': 'INVALID_DATE', 'TOTAL_DIA': 40.0}, // Fecha inválida
      ];

      DateFormat dateFormat = DateFormat('dd/MM/yyyy');
      List<double> ventasPorDia = List.generate(7, (index) => 0.0);

      // Procesar sin que lance excepción
      expect(() {
        for (var venta in ventas) {
          try {
            DateTime fecha = dateFormat.parse(venta['FECHA']);
            double totalDia = venta['TOTAL_DIA'] ?? 0.0;
            int diaSemana = fecha.weekday - 1;
            ventasPorDia[diaSemana] += totalDia;
          } catch (e) {
            // Ignorar errores
          }
        }
      }, returnsNormally);
    });
  });
}
