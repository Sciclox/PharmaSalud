import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class TicketEscPos {
  static Future<Uint8List> buildTicket({
    required List<Map<String, dynamic>> detalles,
    required double total,
    required double pagoCon,
    required double vuelto,
    required String ticketId,
    required String vendedor,
    String? fecha,
    String farmaciaNombre = 'PHARMA SALUD',
    String metodoPago = 'Efectivo',
  }) async {
    await CapabilityProfile.ensureProfileLoaded(
        path: 'assets/capabilities.json');
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    final Map<String, String> tipoVentaAbreviado = {
      'Venta por unidad': 'Unid',
      'Venta por caja': 'Caja',
      'Venta por blister': 'Blist',
    };

    String fechaEmision;
    if (fecha != null) {
      DateTime dt = DateTime.parse(fecha);
      fechaEmision = DateFormat('yyyy-MM-dd hh:mm a').format(dt);
    } else {
      DateTime now = DateTime.now().toLocal();
      fechaEmision = DateFormat('yyyy-MM-dd hh:mm a').format(now);
    }

    bytes += generator.text(farmaciaNombre,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    bytes += generator.text('TICKET #$ticketId',
        styles: PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.text('FECHA: $fechaEmision',
        styles: PosStyles(align: PosAlign.center));

    final vendedorOculto = vendedor.isNotEmpty
        ? '${vendedor[0]}${'*' * (vendedor.length - 1)}'
        : vendedor;
    bytes += generator.text('VENDEDOR: ${vendedorOculto.toUpperCase()}',
        styles: PosStyles(align: PosAlign.center));

    final hr =
        '------------------------------------------------';
    bytes += generator.text(hr, styles: PosStyles(align: PosAlign.center));

    bytes += generator.row([
      PosColumn(
          text: 'DESCRIPCION',
          width: 5,
          styles: PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(
          text: 'TIPO',
          width: 2,
          styles: PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'CANT',
          width: 2,
          styles: PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'IMPORTE',
          width: 3,
          styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.text(hr, styles: PosStyles(align: PosAlign.center));

    for (final item in detalles) {
      String nombre = item['NOMBRE_PRODUCTO'] ??
          item['Nombre_Producto'] ??
          'PRODUCTO';
      String tipo = item['TIPO_VENTA'] ?? '';
      String tipoAbbr = tipoVentaAbreviado[tipo] ?? tipo;
      int cant = item['CANTIDAD'] ?? 0;
      double importe = (item['PRECIO_VENTA'] ?? 0.0).toDouble();

      if (nombre.length > 20) {
        nombre = nombre.substring(0, 19);
      }

      bytes += generator.row([
        PosColumn(
            text: nombre,
            width: 5,
            styles: PosStyles(align: PosAlign.left)),
        PosColumn(
            text: tipoAbbr,
            width: 2,
            styles: PosStyles(align: PosAlign.center)),
        PosColumn(
            text: '$cant',
            width: 2,
            styles: PosStyles(align: PosAlign.center)),
        PosColumn(
            text: 'S/${formatMoney(importe)}',
            width: 3,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.text(hr, styles: PosStyles(align: PosAlign.center));

    bytes += generator.feed(1);

    bytes += generator.row([
      PosColumn(
          text: 'TOTAL:',
          width: 9,
          styles: PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(
          text: 'S/${formatMoney(total)}',
          width: 3,
          styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);

    final String metodoPagoMostrado = (metodoPago == 'Física') ? 'Efectivo' : metodoPago;
    bytes += generator.row([
      PosColumn(
          text: 'METODO PAGO:',
          width: 9,
          styles: PosStyles(align: PosAlign.left)),
      PosColumn(
          text: metodoPagoMostrado.toUpperCase(),
          width: 3,
          styles: PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(
          text: 'RECIBIDO:',
          width: 9,
          styles: PosStyles(align: PosAlign.left)),
      PosColumn(
          text: 'S/${formatMoney(pagoCon)}',
          width: 3,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(
          text: 'CAMBIO:',
          width: 9,
          styles: PosStyles(align: PosAlign.left)),
      PosColumn(
          text: 'S/${formatMoney(vuelto)}',
          width: 3,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.feed(1);

    bytes += generator.text('*** GRACIAS POR SU PREFERENCIA ***',
        styles: PosStyles(align: PosAlign.center));

    bytes += generator.text('VUELVA PRONTO',
        styles: PosStyles(align: PosAlign.center));

    bytes += generator.feed(2);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List> buildTicketInventario({
    required String sesionCodigo,
    required String vendedor,
    required String modo,
    required String fechaHora,
    required List<Map<String, dynamic>> items,
    int totalConformes = 0,
    int totalSobrantes = 0,
    int totalFaltantes = 0,
    String farmaciaNombre = 'PHARMA SALUD',
  }) async {
    await CapabilityProfile.ensureProfileLoaded(
        path: 'assets/capabilities.json');
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    bytes += generator.text(farmaciaNombre,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    bytes += generator.text('COMPROBANTE DE CONTEO FISICO',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('SESION: $sesionCodigo',
        styles: const PosStyles(align: PosAlign.center, bold: true));

    bytes += generator.text('MODO: ${modo.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('FECHA: $fechaHora',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('OPERADOR: ${vendedor.toUpperCase()}',
        styles: const PosStyles(align: PosAlign.center));

    const hr = '------------------------------------------------';
    bytes += generator.text(hr, styles: const PosStyles(align: PosAlign.center));

    // Column headers: PROD / SIST / FIS / DIF
    bytes += generator.row([
      PosColumn(
          text: 'DESCRIPCION',
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(
          text: 'SIST',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'FIS',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(
          text: 'DIF',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.text(hr, styles: const PosStyles(align: PosAlign.center));

    for (final item in items) {
      String nombre = item['NOMBRE_PRODUCTO'] ?? item['Nombre_Producto'] ?? 'PRODUCTO';
      final stockSistema = (item['STOCK_SISTEMA'] as num?)?.toInt() ?? 0;
      final conteoFisico = (item['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
      final dif = (item['DIFERENCIA'] as num?)?.toInt() ?? (conteoFisico - stockSistema);

      String difStr = dif == 0 ? '0' : (dif > 0 ? '+$dif' : '$dif');

      if (nombre.length > 22) {
        nombre = nombre.substring(0, 21);
      }

      bytes += generator.row([
        PosColumn(
            text: nombre,
            width: 6,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: '$stockSistema',
            width: 2,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: '$conteoFisico',
            width: 2,
            styles: const PosStyles(align: PosAlign.center)),
        PosColumn(
            text: difStr,
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.text(hr, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    bytes += generator.row([
      PosColumn(text: 'TOTAL PRODUCTOS:', width: 8, styles: const PosStyles(bold: true, align: PosAlign.left)),
      PosColumn(text: '${items.length}', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'CONFORMES (OK):', width: 8, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: '$totalConformes', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'SOBRANTES (+):', width: 8, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: '$totalSobrantes', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'FALTANTES (-):', width: 8, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: '$totalFaltantes', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.feed(1);
    bytes += generator.text('FIRMA RESPONSABLE: __________________', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text('*** CONSTANCIA DE AUDITORIA FISICA ***', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }
}
