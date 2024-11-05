import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DialogoExito extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems; // Agregar los items del carrito
  final double total; // Agregar el total de la venta

  const DialogoExito({
    super.key,
    required this.cartItems, // Añadir a los argumentos
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.check_circle, // Ícono de éxito
            size: 100.0,
            color: Colors.green, // Color verde para el ícono
          ),
          Padding(
            padding: EdgeInsets.only(top: 10.0), // Espacio superior
            child: Text(
              "Guardado correctamente",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center, // Centra el texto
            ),
          ),
        ],
      ),
      actions: <Widget>[
        // Usar un Row para mostrar los botones
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Centra los botones
          children: <Widget>[
            // Botón "Imprimir Ticket"
            TextButton(
              child: const Text("Imprimir Ticket"),
              onPressed: () async {
                await _generatePdf(cartItems, total); // Llama a la función para imprimir
              },
            ),
            const SizedBox(width: 20), // Espacio entre los botones

            // Botón "Cerrar"
            TextButton(
              child: const Text("Cerrar"),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Función para mostrar el diálogo de éxito
void mostrarDialogoExito(BuildContext context, List<Map<String, dynamic>> cartItems, double total) {
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return DialogoExito(cartItems: cartItems, total: total); // Pasar los datos de la venta
    },
  );
}

Future<void> _generatePdf(List<Map<String, dynamic>> cartItems, double total) async {
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
        (index) => pw.Text('-', style: pw.TextStyle(fontSize: 8)),
      ),
    );
  }

  // Obtener la fecha y hora actual en formato deseado
  DateTime now = DateTime.now().toLocal();
  String formattedDate = "${now.toLocal().toString().split(' ')[0]}"; // Solo la fecha
  String formattedTime = "${now.hour > 12 ? now.hour - 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}"; // Formato de hora

  String fechaEmision = "$formattedDate $formattedTime"; // Fecha y hora combinadas

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
                  'BOTICA PHARMA SALUD',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), // Tamaño de fuente reducido
                ),
              ),
              pw.SizedBox(height: 5),
              // Fecha de emisión
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'FECHA DE EMISIÓN: $fechaEmision',
                  style: pw.TextStyle(fontSize: 8), // Tamaño de fuente
                ),
              ),
              pw.SizedBox(height: 5),
              dashedDivider(),
              pw.SizedBox(height: 2),

              // Divider con guiones debajo de los encabezados
              pw.Table(
                border: null, // Eliminar los bordes de la tabla
                columnWidths: {
                  0: pw.FixedColumnWidth(80), // Ancho fijo para la columna "Producto"
                  1: pw.FixedColumnWidth(30), // Ancho fijo para la columna "Tipo"
                  2: pw.FixedColumnWidth(30), // Ancho fijo para la columna "Cant"
                  3: pw.FixedColumnWidth(40), // Ancho fijo para la columna "Precio"
                },
                children: [
                  // Encabezados de la tabla
                  pw.TableRow(
                    children: [
                      pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                      pw.Text('Tipo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                      pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                      pw.Text('Importe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
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
                  String tipoVenta = tipoVentaAbreviado[item['TIPO_VENTA']] ?? 'No especificado';
                  return pw.Column(
                    children: [
                      pw.Table(
                        border: null,
                        columnWidths: {
                          0: pw.FixedColumnWidth(80),
                          1: pw.FixedColumnWidth(30),
                          2: pw.FixedColumnWidth(30),
                          3: pw.FixedColumnWidth(40),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Text(item['Nombre_Producto'] ?? 'Producto Desconocido', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.left),
                              pw.Text(tipoVenta, style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                              pw.Text('${item['CANTIDAD'] ?? 0}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                              pw.Text('S/${(item['PRECIO_VENTA'] ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
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
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Total:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), // Tamaño de fuente reducido
                  ),
                  pw.Text(
                    'S/${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), // Tamaño de fuente reducido
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // Mensaje centrado
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  '¡GRACIAS POR SU COMPRA!',
                  style: const pw.TextStyle(fontSize: 10), // Tamaño de fuente reducido
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  // Imprimir el PDF
  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}
