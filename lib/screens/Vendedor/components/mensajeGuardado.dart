import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/raw_print_service.dart';
import 'package:pharma_salud/utils/ticket_escpos.dart';
import 'package:pharma_salud/repositories/farmacia.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class DialogoExito extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final double total;
  final double pagoCon;
  final double vuelto;
  final String ticketId;
  final String vendedor;
  final BuildContext pageContext;
  final String farmaciaNombre;
  final String metodoPago;

  const DialogoExito({
    super.key,
    required this.cartItems,
    required this.total,
    required this.pagoCon,
    required this.vuelto,
    required this.pageContext,
    this.ticketId = '',
    this.vendedor = '',
    this.farmaciaNombre = 'PHARMA SALUD',
    required this.metodoPago,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Success Estilo Pharma
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1D1D1F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Operación Exitosa",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "La venta ha sido registrada correctamente",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "TOTAL LIQUIDADO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "S/ ${formatMoney(total)}",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF3B30),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Color(0xFFE5E5EA)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "MÉTODO DE PAGO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              metodoPago,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: metodoPago == 'Yape'
                                    ? const Color(0xFF7D52F4)
                                    : metodoPago == 'Tarjeta'
                                        ? const Color(0xFF007AFF)
                                        : const Color(0xFF34C759),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Color(0xFFE5E5EA)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "PAGÓ CON",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "S/ ${formatMoney(pagoCon)}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D1D1F),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "VUELTO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              "S/ ${formatMoney(vuelto)}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de Acción
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton.icon(
                          onPressed: () => _imprimirTicket(
                              pageContext, cartItems, total, pagoCon, vuelto, ticketId, vendedor, farmaciaNombre, metodoPago),
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text("IMPRIMIR",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D1D1F),
                            side: BorderSide(
                                color:
                                    const Color(0xFF1D1D1F).withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Guardado automático y silencioso antes de cerrar
                            await _savePdfLocally(
                                context, cartItems, total, pagoCon, vuelto, metodoPago,
                                silent: true, farmaciaNombre: farmaciaNombre);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("FINALIZAR OPERACIÓN",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Función para mostrar el diálogo de éxito
Future<void> mostrarDialogoExito(
    BuildContext pageContext,
    List<Map<String, dynamic>> cartItems,
    double total,
    double pagoCon,
    double vuelto,
    {String ticketId = '', String vendedor = '', String metodoPago = 'Efectivo'}) async {
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

  if (!pageContext.mounted) return;

  showDialog(
    barrierDismissible: false,
    context: pageContext,
    builder: (BuildContext dialogContext) {
      return DialogoExito(
        cartItems: cartItems,
        total: total,
        pagoCon: pagoCon,
        vuelto: vuelto,
        ticketId: ticketId,
        vendedor: vendedor,
        pageContext: pageContext,
        farmaciaNombre: farmaciaNombre,
        metodoPago: metodoPago,
      );
    },
  );
}

Future<Uint8List> _generatePdfData(List<Map<String, dynamic>> cartItems,
    double total, double pagoCon, double vuelto, String metodoPago, {String farmaciaNombre = 'PHARMA SALUD'}) async {
  final pdf = pw.Document();

  // Mapa de abreviaciones de tipos de venta
  final Map<String, String> tipoVentaAbreviado = {
    'Venta por unidad': 'Unidad',
    'Venta por caja': 'Caja',
    'Venta por blister': 'Blister',
  };

  // Función personalizada para Divider con guiones que se ajusta al ancho
  pw.Widget dashedDivider() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List.generate(
        40, // Ajusta este valor según el ancho requerido
        (index) => pw.Text('-', style: const pw.TextStyle(fontSize: 8)),
      ),
    );
  }

  // Obtener la fecha y hora actual en formato deseado
  DateTime now = DateTime.now().toLocal();
  String formattedDate = DateFormat('yyyy-MM-dd').format(now);
  String formattedTime = DateFormat('hh:mm a').format(now);

  String fechaEmision = "$formattedDate $formattedTime";

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80, // Formato de rollo 80 mm
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Título centrado
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  farmaciaNombre,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight:
                          pw.FontWeight.bold), // Tamaño de fuente reducido
                ),
              ),
              pw.SizedBox(height: 5),
              // Fecha de emisión
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'FECHA DE EMISIÓN: $fechaEmision',
                  style: const pw.TextStyle(fontSize: 8), // Tamaño de fuente
                ),
              ),
              pw.SizedBox(height: 5),
              dashedDivider(),
              pw.SizedBox(height: 2),

              // Divider con guiones debajo de los encabezados
              pw.Table(
                border: null, // Eliminar los bordes de la tabla
                columnWidths: {
                  0: const pw.FixedColumnWidth(
                      80), // Ancho fijo para la columna "Producto"
                  1: const pw.FixedColumnWidth(
                      30), // Ancho fijo para la columna "Tipo"
                  2: const pw.FixedColumnWidth(
                      30), // Ancho fijo para la columna "Cant"
                  3: const pw.FixedColumnWidth(
                      40), // Ancho fijo para la columna "Precio"
                },
                children: [
                  // Encabezados de la tabla
                  pw.TableRow(
                    children: [
                      pw.Text('Producto',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 8),
                          textAlign: pw.TextAlign.center),
                      pw.Text('Tipo',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 8),
                          textAlign: pw.TextAlign.center),
                      pw.Text('Cant.',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 8),
                          textAlign: pw.TextAlign.center),
                      pw.Text('Importe',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 8),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),

              // Dashed Divider justo debajo de los encabezados
              pw.SizedBox(height: 2),
              dashedDivider(),
              pw.SizedBox(height: 5),

              // Filas de la tabla
              pw.Column(
                children: cartItems.map((item) {
                  String tipoVenta = tipoVentaAbreviado[item['TIPO_VENTA']] ??
                      'No especificado';
                  return pw.Column(
                    children: [
                      pw.Table(
                        border: null,
                        columnWidths: {
                          0: const pw.FixedColumnWidth(80),
                          1: const pw.FixedColumnWidth(30),
                          2: const pw.FixedColumnWidth(30),
                          3: const pw.FixedColumnWidth(40),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Text(
                                  item['Nombre_Producto'] ??
                                      'Producto Desconocido',
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.left),
                              pw.Text(tipoVenta,
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center),
                              pw.Text('${item['CANTIDAD'] ?? 0}',
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center),
                              pw.Text(
                                  'S/${formatMoney(item['PRECIO_VENTA'] ?? 0.0)}',
                                  style: const pw.TextStyle(fontSize: 8),
                                  textAlign: pw.TextAlign.center),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 5), // Espacio debajo de cada fila
                    ],
                  );
                }).toList(),
              ),
              dashedDivider(),
              pw.SizedBox(height: 5),

              // Total centrado
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total:',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('S/${formatMoney(total)}',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Metodo de Pago:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(metodoPago,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Pagó con:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('S/${formatMoney(pagoCon)}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Vuelto:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('S/${formatMoney(vuelto)}',
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 10),

              // Mensaje centrado
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '¡GRACIAS POR SU COMPRA!',
                  style: const pw.TextStyle(
                      fontSize: 10), // Tamaño de fuente reducido
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return await pdf.save();
}

Future<void> _imprimirTicket(
    BuildContext context, List<Map<String, dynamic>> cartItems, double total,
    double pagoCon, double vuelto, String ticketId, String vendedor, String farmaciaNombre, String metodoPago) async {
  try {
    // Probar impresión nativa primero
    final escPosData = await _buildEscPosData(
        cartItems, total, pagoCon, vuelto, ticketId, vendedor, farmaciaNombre, metodoPago);
    final printers = RawPrintService.listPrinters();
    debugPrint('Impresoras disponibles: $printers');

    if (printers.isEmpty) {
      if (context.mounted) {
        _mostrarError(context, 'No hay impresoras instaladas en el sistema');
      }
      return;
    }

    String printerName;
    try {
      printerName = RawPrintService.findThermalPrinter();
    } catch (e) {
      printerName = printers.first;
      debugPrint('Usando primera impresora disponible: $printerName');
    }

    debugPrint('Imprimiendo en: $printerName');
    RawPrintService.printRaw(printerName, escPosData);
    debugPrint('Ticket impreso exitosamente');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket impreso en: $printerName'),
          backgroundColor: const Color(0xFF34C759),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error al imprimir: $e');
    if (context.mounted) {
      _mostrarError(context, 'Error al imprimir: $e');
    }
    // Fallback a PDF
    try {
      final pdfData = await _generatePdfData(cartItems, total, pagoCon, vuelto, metodoPago, farmaciaNombre: farmaciaNombre);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
    } catch (pdfError) {
      debugPrint('Error al imprimir PDF: $pdfError');
    }
  }
}

void _mostrarError(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: const Color(0xFFFF3B30),
      duration: const Duration(milliseconds: 800),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    ),
  );
}

Future<Uint8List> _buildEscPosData(List<Map<String, dynamic>> cartItems,
    double total, double pagoCon, double vuelto, String ticketId, String vendedor, String farmaciaNombre, String metodoPago) async {
  final escPosData = await TicketEscPos.buildTicket(
    detalles: cartItems,
    total: total,
    pagoCon: pagoCon,
    vuelto: vuelto,
    ticketId: ticketId,
    vendedor: vendedor,
    farmaciaNombre: farmaciaNombre,
    metodoPago: metodoPago,
  );
  return escPosData;
}

Future<void> _savePdfLocally(
    BuildContext context,
    List<Map<String, dynamic>> cartItems,
    double total,
    double pagoCon,
    double vuelto,
    String metodoPago,
    {bool silent = false, String farmaciaNombre = 'PHARMA SALUD'}) async {
  try {
    final pdfData = await _generatePdfData(cartItems, total, pagoCon, vuelto, metodoPago, farmaciaNombre: farmaciaNombre);

    // Obtener el directorio de la aplicación
    final directory = await getApplicationSupportDirectory();
    final ticketsPath = p.join(directory.path, 'PharmaSalud', 'tickets');

    // Crear el directorio si no existe
    final ticketsDir = Directory(ticketsPath);
    if (!await ticketsDir.exists()) {
      await ticketsDir.create(recursive: true);
    }

    // Nombre del archivo basado en la fecha y hora
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'ticket_$timestamp.pdf';
    final filePath = p.join(ticketsPath, fileName);

    // Guardar el archivo
    final file = File(filePath);
    await file.writeAsBytes(pdfData);

    if (context.mounted && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket guardado en: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el ticket: $e'),
          backgroundColor: const Color(0xFFFF3B30),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }
}
