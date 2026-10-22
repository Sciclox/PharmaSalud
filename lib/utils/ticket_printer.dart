import 'package:flutter/foundation.dart';
import 'package:pharma_salud/utils/ticket_escpos.dart';
import 'package:pharma_salud/utils/raw_print_service.dart';
import 'package:pharma_salud/repositories/farmacia.dart';

class TicketPrinter {
  static Future<void> imprimirTicket({
    required List<Map<String, dynamic>> detalles,
    required double total,
    required double pagoCon,
    required double vuelto,
    required String ticketId,
    required String vendedor,
    String? fecha,
    String metodoPago = 'Efectivo',
  }) async {
    try {
      String farmaciaNombre = 'PHARMA SALUD';
      try {
        final repo = FarmaciaRepository();
        final activa = await repo.obtenerActiva();
        if (activa != null) {
          farmaciaNombre = activa['NOMBRE'] ?? 'PHARMA SALUD';
        }
      } catch (e) {
        debugPrint('Error al cargar farmacia activa: $e');
      }

      final escPosData = await TicketEscPos.buildTicket(
        detalles: detalles,
        total: total,
        pagoCon: pagoCon,
        vuelto: vuelto,
        ticketId: ticketId,
        vendedor: vendedor,
        fecha: fecha,
        farmaciaNombre: farmaciaNombre,
        metodoPago: metodoPago,
      );

      final printerName = RawPrintService.findThermalPrinter();
      debugPrint('Imprimiendo en: $printerName');

      RawPrintService.printRaw(printerName, escPosData);
      debugPrint('Ticket impreso exitosamente en $printerName');
    } catch (e) {
      debugPrint('Error al imprimir ticket: $e');
      rethrow;
    }
  }

  static Future<void> imprimirTicketInventario({
    required String sesionCodigo,
    required String vendedor,
    required String modo,
    required String fechaHora,
    required List<Map<String, dynamic>> items,
    int totalConformes = 0,
    int totalSobrantes = 0,
    int totalFaltantes = 0,
  }) async {
    try {
      String farmaciaNombre = 'PHARMA SALUD';
      try {
        final repo = FarmaciaRepository();
        final activa = await repo.obtenerActiva();
        if (activa != null) {
          farmaciaNombre = activa['NOMBRE'] ?? 'PHARMA SALUD';
        }
      } catch (e) {
        debugPrint('Error al cargar farmacia activa: $e');
      }

      final escPosData = await TicketEscPos.buildTicketInventario(
        sesionCodigo: sesionCodigo,
        vendedor: vendedor,
        modo: modo,
        fechaHora: fechaHora,
        items: items,
        totalConformes: totalConformes,
        totalSobrantes: totalSobrantes,
        totalFaltantes: totalFaltantes,
        farmaciaNombre: farmaciaNombre,
      );

      final printerName = RawPrintService.findThermalPrinter();
      debugPrint('Imprimiendo ticket de inventario en: $printerName');

      RawPrintService.printRaw(printerName, escPosData);
      debugPrint('Ticket de inventario impreso exitosamente');
    } catch (e) {
      debugPrint('Error al imprimir ticket de inventario: $e');
      rethrow;
    }
  }
}
