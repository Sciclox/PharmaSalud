import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class AnalysisReportService {
  static Future<void> generatePurchaseOrderPdf(
      List<Map<String, dynamic>> productos) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final fileName =
        'Plan_de_Compras_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';

    // Cargar la fuente Outfit para el PDF
    final fontDataReg =
        await rootBundle.load("assets/fonts/Outfit-Regular.ttf");
    final fontDataBold = await rootBundle.load("assets/fonts/Outfit-Bold.ttf");
    final myFont = pw.Font.ttf(fontDataReg);
    final myFontBold = pw.Font.ttf(fontDataBold);

    // Cargar Logo
    final logoData = await rootBundle.load("assets/icon/icono.png");
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    // Estilo base
    final baseStyle = pw.TextStyle(font: myFont);
    final boldStyle =
        pw.TextStyle(font: myFontBold, fontWeight: pw.FontWeight.bold);

    // Filtrar solo productos que necesitan compra (> 0) y que tienen movimiento
    final aPedir = productos.where((p) {
      final tieneSugerencia = (p['compraMensualSugerida'] as int? ?? 0) > 0;
      final noEstaInactivo = p['recomendacion'] != "SIN MOVIMIENTO";
      return tieneSugerencia && noEstaInactivo;
    }).toList();

    // Ordenar por urgencia
    aPedir.sort((a, b) {
      int getPrioridad(String r) {
        if (r == 'URGENTE') return 0;
        if (r == 'SIN STOCK') return 1;
        if (r == 'POR AGOTARSE') return 2;
        if (r == 'REPOSICIÓN PREVENTIVA') return 3;
        return 4;
      }

      return getPrioridad(a['recomendacion'])
          .compareTo(getPrioridad(b['recomendacion']));
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 1000, // Aumentar el límite para inventarios grandes
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: myFont,
          bold: myFontBold,
        ),
        build: (pw.Context context) {
          return [
            _buildHeader(dateStr, boldStyle, baseStyle, logoImage),
            pw.SizedBox(height: 30),
            _buildTable(aPedir, boldStyle, baseStyle),
            pw.SizedBox(height: 30),
            _buildFooter(baseStyle),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Plan de Compras',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(bytes);
    }
  }

  static pw.Widget _buildHeader(
      String date, pw.TextStyle bold, pw.TextStyle base, pw.MemoryImage logo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Image(logo, width: 40, height: 40),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PHARMA SALUD',
                    style:
                        bold.copyWith(fontSize: 24, color: PdfColors.red900)),
                pw.Text('Reporte Inteligente de Compras',
                    style:
                        base.copyWith(fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Fecha: $date', style: base.copyWith(fontSize: 10)),
            pw.Text('Documento generado automáticamente',
                style: base.copyWith(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTable(
      List<Map<String, dynamic>> data, pw.TextStyle bold, pw.TextStyle base) {
    final headers = ['Producto', 'Stock Actual', 'Sugerido', 'Prioridad'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data
          .map((p) => [
                p['nombre'],
                p['stockUtilTxt'],
                p['compraSugeridaTxt'],
                p['recomendacion'].toString().split(':').first,
              ])
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: bold.copyWith(color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
      cellStyle: base.copyWith(fontSize: 10),
    );
  }

  static pw.Widget _buildFooter(pw.TextStyle base) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Text(
            'Nota: Las cantidades sugeridas incluyen un margen de seguridad basado en la volatilidad de ventas.',
            style: base.copyWith(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600)),
      ],
    );
  }
}
