import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/repositories/campana_inventario.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';
import 'package:pharma_salud/repositories/cuadre_global.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/screens/Admin/ajusteInventario/dialog_importar_conteos_pos.dart';
import 'package:pharma_salud/screens/Admin/ajusteInventario/dialog_conteo_cruzado.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_historial_inventarios.dart';

class AjusteInventarioScreen extends StatefulWidget {
  const AjusteInventarioScreen({super.key});

  @override
  State<AjusteInventarioScreen> createState() => _AjusteInventarioScreenState();
}

class _AjusteInventarioScreenState extends State<AjusteInventarioScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final KardexRepository _kardexRepository = KardexRepository();
  final CampanaInventarioRepository _campanaRepo = CampanaInventarioRepository();
  final SobranteCajaRepository _sobranteCajaRepo = SobranteCajaRepository();
  final CuadreGlobalRepository _cuadreGlobalRepo = CuadreGlobalRepository();

  int _activeTab = 0; // 0: Ajustar Stock, 1: Campañas / Consolidados
  Map<String, dynamic>? _campanaActiva;
  List<Map<String, dynamic>> _campanasPasadas = [];
  Map<String, dynamic>? _campanaSeleccionadaReporte;
  List<Map<String, dynamic>> _ajustesConsolidados = [];

  static final Map<int, int> _cacheConteosReales = {};
  static final Map<int, bool> _cacheAjustados = {};
  static final Map<int, bool> _cacheConformes = {};

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Map<int, int> _conteosReales = _cacheConteosReales;
  final Map<int, bool> _ajustados = _cacheAjustados;
  final Map<int, bool> _conformes = _cacheConformes;

  // Status del filtro: 'Todos', 'Pendientes', 'Ajustados'
  String _filtroStatus = 'Todos';

  // Controladores para evitar que el texto se filtre entre inputs al buscar
  final Map<int, TextEditingController> _inputControllers = {};

  TextEditingController _getInputController(int id) {
    if (!_inputControllers.containsKey(id)) {
      final ctrl = TextEditingController();
      if (_conteosReales.containsKey(id)) {
        ctrl.text = '${_conteosReales[id]}';
      }
      _inputControllers[id] = ctrl;
    }
    return _inputControllers[id]!;
  }

  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _loadCampanas();
  }

  Future<void> _loadCampanas() async {
    final activa = await _campanaRepo.obtenerActiva();
    final todas = await _campanaRepo.obtenerTodas();
    setState(() {
      _campanaActiva = activa;
      _campanasPasadas = todas.where((c) => c['ESTADO'] == 'COMPLETADO').toList();
    });
  }

  Future<void> _loadProductos() async {
    setState(() => _isLoading = true);
    final rawList = await _productoRepository.getAllProductos();
    _productos = rawList.map((p) => Map<String, dynamic>.from(p)).toList();
    _productosFiltrados = List.from(_productos);
    setState(() => _isLoading = false);
  }

  void _filterProductos(String query) {
    setState(() {
      _productosFiltrados = _productos.where((p) {
        final id = p['ID'] as int;
        final nameMatch = p['Nombre_Producto']
                ?.toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ??
            false;

        bool statusMatch = true;
        if (_filtroStatus == 'Pendientes') {
          // Pendientes son todos los que NO han sido ajustados ni conformados aún
          statusMatch = !(_ajustados[id] ?? false) && !(_conformes[id] ?? false);
        } else if (_filtroStatus == 'Ajustados') {
          statusMatch = (_ajustados[id] ?? false) || (_conformes[id] ?? false);
        }

        return nameMatch && statusMatch;
      }).toList();
    });
  }

  /// Calcula la diferencia entre conteo real y stock del sistema
  int _getDiferencia(Map<String, dynamic> producto) {
    final id = producto['ID'] as int;
    if (!_conteosReales.containsKey(id)) return 0;
    final stockSistema = (producto['Cantidad_Total'] as int?) ?? 0;
    return _conteosReales[id]! - stockSistema;
  }

  /// Calcula el valor monetario total descomponiendo en Cajas, Blísters y Unidades sueltas
  double _calcularValorMonto(Map<String, dynamic> producto, int totalUnidades) {
    if (totalUnidades == 0) return 0.0;
    int unidadesRestantes = totalUnidades.abs();
    double totalMonto = 0.0;

    final costoUnidad = (producto['Costo_Unidad'] as num?)?.toDouble() ?? 0.0;
    // Si hay un costo de compra directo por unidad definido, se aplica sobre el total
    if (costoUnidad > 0) {
      return totalUnidades.abs() * costoUnidad;
    }

    final tipo = producto['Tipo_Producto'] ?? 'Unidad';
    final precioCaja = (producto['Precio_Caja'] as num?)?.toDouble() ?? 0.0;
    final cantCaja = (producto['Cantidad_Presentacion'] as num?)?.toInt() ?? 0;

    // 1. Descomponer Cajas completas
    if (tipo == 'Caja' && precioCaja > 0 && cantCaja > 0) {
      int cajas = unidadesRestantes ~/ cantCaja;
      totalMonto += cajas * precioCaja;
      unidadesRestantes %= cantCaja;
    }

    final bool tieneBlisterActivo = producto['Blister_SiNo'] == 1;
    final precioBlister = (producto['Precio_Blister'] as num?)?.toDouble() ?? 0.0;
    final cantBlister =
        (producto['Cantidad_Presentacion_blister'] as num?)?.toInt() ?? 0;

    // 2. Descomponer Blísters completos ÚNICAMENTE si tiene activado el blíster (Blister_SiNo == 1)
    if (tieneBlisterActivo && precioBlister > 0 && cantBlister > 0) {
      int blisters = unidadesRestantes ~/ cantBlister;
      totalMonto += blisters * precioBlister;
      unidadesRestantes %= cantBlister;
    }

    // 3. Unidades sueltas restantes (o cálculo normal por precio unidad si no hay blíster)
    if (unidadesRestantes > 0) {
      final precioUnidad = (producto['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
      double precioUnitarioEfectivo = precioUnidad;

      if (precioUnitarioEfectivo <= 0) {
        if (tieneBlisterActivo && precioBlister > 0 && cantBlister > 0) {
          precioUnitarioEfectivo = precioBlister / cantBlister;
        } else if (tipo == 'Caja' && precioCaja > 0 && cantCaja > 0) {
          precioUnitarioEfectivo = precioCaja / cantCaja;
        }
      }

      totalMonto += unidadesRestantes * precioUnitarioEfectivo;
    }

    return totalMonto;
  }

  /// Calcula el valor monetario de la diferencia considerando la descomposición por presentaciones
  double _getValorDiferencia(Map<String, dynamic> producto) {
    final diferencia = _getDiferencia(producto);
    if (diferencia == 0) return 0.0;
    final monto = _calcularValorMonto(producto, diferencia.abs());
    return diferencia > 0 ? monto : -monto;
  }

  /// Refrescar el stock del sistema de un producto individual desde la base de datos
  Future<void> _refrescarStockProducto(int id) async {
    final dbProducto = await _productoRepository.getProductoById(id);
    if (dbProducto != null) {
      final int stockActual = (dbProducto['Cantidad_Total'] as int?) ?? 0;
      
      setState(() {
        for (int i = 0; i < _productos.length; i++) {
          if (_productos[i]['ID'] == id) {
            _productos[i] = Map<String, dynamic>.from(_productos[i])
              ..['Cantidad_Total'] = stockActual;
            break;
          }
        }
        for (int i = 0; i < _productosFiltrados.length; i++) {
          if (_productosFiltrados[i]['ID'] == id) {
            _productosFiltrados[i] = Map<String, dynamic>.from(_productosFiltrados[i])
              ..['Cantidad_Total'] = stockActual;
            break;
          }
        }
      });

    }
  }

  /// Marcar producto como conforme usando el stock más reciente en base de datos
  Future<void> _marcarConforme(int id) async {
    final dbProducto = await _productoRepository.getProductoById(id);
    if (dbProducto != null) {
      final int stockActual = (dbProducto['Cantidad_Total'] as int?) ?? 0;
      
      setState(() {
        for (int i = 0; i < _productos.length; i++) {
          if (_productos[i]['ID'] == id) {
            _productos[i] = Map<String, dynamic>.from(_productos[i])
              ..['Cantidad_Total'] = stockActual;
            break;
          }
        }
        for (int i = 0; i < _productosFiltrados.length; i++) {
          if (_productosFiltrados[i]['ID'] == id) {
            _productosFiltrados[i] = Map<String, dynamic>.from(_productosFiltrados[i])
              ..['Cantidad_Total'] = stockActual;
            break;
          }
        }
        _conformes[id] = true;
        _conteosReales.remove(id);
        _getInputController(id).clear();
      });

    }
  }

  /// Total sobrante (diferencias positivas)
  double get _totalSobrante {
    double total = 0;
    for (var p in _productos) {
      final val = _getValorDiferencia(p);
      if (val > 0) total += val;
    }
    return total;
  }

  /// Total faltante (diferencias negativas)
  double get _totalFaltante {
    double total = 0;
    for (var p in _productos) {
      final val = _getValorDiferencia(p);
      if (val < 0) total += val.abs();
    }
    return total;
  }

  /// Cantidad de productos con diferencia
  /// Cantidad de productos con diferencia
  int get _productosConDiferencia {
    int count = 0;
    for (var p in _productos) {
      if (_getDiferencia(p) != 0) count++;
    }
    return count;
  }

  /// Cantidad de productos contados o verificados pendientes de aplicar
  int get _productosPendientesAjuste {
    int count = 0;
    for (var p in _productos) {
      final id = p['ID'] as int;
      final esConforme = _conformes[id] == true;
      final tieneConteo = _conteosReales.containsKey(id);
      if (esConforme || tieneConteo) count++;
    }
    return count;
  }

  /// Aplicar todos los ajustes y verificaciones pendientes
  Future<void> _aplicarTodosLosAjustes() async {

    final productosProcesados = _productos.where((p) {
      final id = p['ID'] as int;
      final esConforme = _conformes[id] == true;
      final tieneConteo = _conteosReales.containsKey(id);
      return esConforme || tieneConteo;
    }).toList();

    if (productosProcesados.isEmpty) {
      _showSnackBar('No hay productos contados o verificados pendientes.', isError: true);
      return;
    }

    final confirmed =
        await _showConfirmAllAjustesDialog(productosProcesados.length);
    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final adminName = prefs.getString('adminName') ?? 'Administrador';
      final fechaDB = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      double sobranteBatch = 0;
      double faltanteBatch = 0;
      List<Map<String, dynamic>> resumenParaReporte = [];

      for (var producto in productosProcesados) {
        final id = producto['ID'] as int;
        final stockActual = (producto['Cantidad_Total'] as int?) ?? 0;
        final esConforme = _conformes[id] == true;
        final conteoFisicoVal = esConforme ? stockActual : (_conteosReales[id] ?? stockActual);
        final diferencia = conteoFisicoVal - stockActual;
        final valorDif = _getValorDiferencia(producto);

        if (valorDif > 0) sobranteBatch += valorDif;
        if (valorDif < 0) faltanteBatch += valorDif.abs();

        resumenParaReporte.add({
          'id': id,
          'nombre': producto['Nombre_Producto'],
          'tipo': producto['Tipo_Producto'],
          'stock_sistema': stockActual,
          'conteo': conteoFisicoVal,
          'diferencia': diferencia,
          'valor': valorDif,
        });

        if (diferencia > 0) {
          await _productoRepository.incrementarStock(id, diferencia);
          await _kardexRepository.insertKardexEntry({
            'NOMBRE_PRODUCTO': producto['Nombre_Producto'],
            'FECHA_MOVIMIENTO': fechaDB,
            'TIPO_MOVIMIENTO': 'Ajuste Inventario (+)',
            'CANTIDAD': diferencia,
            'USUARIO': adminName,
            'STOCK_SISTEMA': stockActual,
            'CONTEO_FISICO': conteoFisicoVal,
            'STOCK_ANTERIOR': stockActual,
            'STOCK_RESULTANTE': conteoFisicoVal,
          });
        } else if (diferencia < 0) {
          await _productoRepository.descontarStock(id, diferencia.abs());
          await _kardexRepository.insertKardexEntry({
            'NOMBRE_PRODUCTO': producto['Nombre_Producto'],
            'FECHA_MOVIMIENTO': fechaDB,
            'TIPO_MOVIMIENTO': 'Ajuste Inventario (-)',
            'CANTIDAD': diferencia.abs(),
            'USUARIO': adminName,
            'STOCK_SISTEMA': stockActual,
            'CONTEO_FISICO': conteoFisicoVal,
            'STOCK_ANTERIOR': stockActual,
            'STOCK_RESULTANTE': conteoFisicoVal,
          });
        } else {
          await _kardexRepository.insertKardexEntry({
            'NOMBRE_PRODUCTO': producto['Nombre_Producto'],
            'FECHA_MOVIMIENTO': fechaDB,
            'TIPO_MOVIMIENTO': 'Ajuste Inventario (Conforme)',
            'CANTIDAD': 0,
            'USUARIO': adminName,
            'STOCK_SISTEMA': stockActual,
            'CONTEO_FISICO': conteoFisicoVal,
            'STOCK_ANTERIOR': stockActual,
            'STOCK_RESULTANTE': conteoFisicoVal,
          });
        }
        _ajustados[id] = true;
        _conformes.remove(id);
        _conteosReales.remove(id);
        _inputControllers[id]?.dispose();
        _inputControllers.remove(id);
      }

      await _generarReporteAjuste(resumenParaReporte, adminName, sobranteBatch, faltanteBatch);

      _showSnackBar(
          'Ajuste aplicado con éxito. Stock y Kárdex actualizados.');
      _loadProductos();
    } catch (e) {
      _showSnackBar('Error al aplicar ajustes: $e', isError: true);
    }
  }

  void _mostrarModalImportarPos() {
    showDialog(
      context: context,
      builder: (ctx) => DialogImportarConteosPos(
        onAjustesAplicados: () async {
          await _loadProductos();
        },
      ),
    );
  }

  Future<void> _mostrarHistorialPos() async {
    final prefs = await SharedPreferences.getInstance();
    final adminName = prefs.getString('adminName') ?? 'Administrador';
    if (!mounted) return;
    ModalHistorialInventariosPOS.show(
      context,
      userName: adminName,
      esAdmin: true,
    );
  }

  void _mostrarConteoCruzado() {
    DialogConteoCruzado.show(
      context,
      onAjustesAplicados: () async {
        await _loadProductos();
      },
    );
  }

  /// Genera un PDF del lote de ajustes y lo guarda en una carpeta
  Future<void> _generarReporteAjuste(List<Map<String, dynamic>> resumen,
      String admin, double totalSob, double totalFal) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
      final idSession = DateFormat('yyyyMMdd_HHmmss').format(now);

      // Cargar la fuente Outfit para el PDF
      final fontDataReg =
          await rootBundle.load("assets/fonts/Outfit-Regular.ttf");
      final fontDataBold =
          await rootBundle.load("assets/fonts/Outfit-Bold.ttf");
      final myFont = pw.Font.ttf(fontDataReg);
      final myFontBold = pw.Font.ttf(fontDataBold);

      // Cargar Logo
      final logoData = await rootBundle.load("assets/icon/icono.png");
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Estilos base
      final boldStyle =
          pw.TextStyle(font: myFontBold, fontWeight: pw.FontWeight.bold);
      final baseStyle = pw.TextStyle(font: myFont);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: myFont,
            bold: myFontBold,
          ),
          header: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Image(logoImage, width: 40, height: 40),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PHARMA SALUD',
                          style: boldStyle.copyWith(
                              fontSize: 24, color: PdfColors.red900)),
                      pw.Text('Comprobante de Ajuste de Inventario',
                          style: baseStyle.copyWith(
                              fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('ID: #AJ-$idSession',
                      style: boldStyle.copyWith(fontSize: 10)),
                  pw.Text('Fecha: $fechaStr',
                      style: baseStyle.copyWith(fontSize: 10)),
                  pw.Text('Responsable: $admin',
                      style: baseStyle.copyWith(fontSize: 9)),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.SizedBox(height: 30),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.red900),
                  children: [
                    _pdfCell(
                        'PRODUCTO',
                        boldStyle.copyWith(
                            color: PdfColors.white, fontSize: 8)),
                    _pdfCell('SISTEMA',
                        boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                        alignment: pw.Alignment.center),
                    _pdfCell('CONTEO',
                        boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                        alignment: pw.Alignment.center),
                    _pdfCell('AJUSTE',
                        boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                        alignment: pw.Alignment.center),
                    _pdfCell('VALOR',
                        boldStyle.copyWith(color: PdfColors.white, fontSize: 8),
                        alignment: pw.Alignment.center),
                  ],
                ),
                ...resumen.map((item) {
                  final diff = item['diferencia'] as int;
                  final valor = item['valor'] as double;
                  return pw.TableRow(
                    children: [
                      _pdfCell(item['nombre'], baseStyle.copyWith(fontSize: 8)),
                      _pdfCell('${item['stock_sistema']}',
                          baseStyle.copyWith(fontSize: 8),
                          alignment: pw.Alignment.center),
                      _pdfCell(
                          '${item['conteo']}', baseStyle.copyWith(fontSize: 8),
                          alignment: pw.Alignment.center),
                      _pdfCell(
                          diff > 0 ? '+$diff' : (diff < 0 ? '$diff' : '0 (Conforme)'),
                          boldStyle.copyWith(
                              fontSize: 8,
                              color: diff > 0
                                  ? PdfColors.green
                                  : (diff < 0 ? PdfColors.orange : PdfColors.blueGrey700)),
                          alignment: pw.Alignment.center),
                      _pdfCell('S/ ${formatMoney(valor.abs())}',
                          boldStyle.copyWith(fontSize: 8),
                          alignment: pw.Alignment.center),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 200,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _summaryRow('Total Sobrante:', totalSob, baseStyle,
                          PdfColors.green),
                      pw.SizedBox(height: 4),
                      _summaryRow('Total Faltante:', totalFal, baseStyle,
                          PdfColors.orange),
                      pw.SizedBox(height: 6),
                      pw.Divider(thickness: 0.5),
                      pw.SizedBox(height: 6),
                      _summaryRow(
                          'BALANCE NETO:',
                          totalSob - totalFal,
                          boldStyle,
                          (totalSob - totalFal) >= 0
                              ? PdfColors.green
                              : PdfColors.red900,
                          isNet: true),
                      pw.SizedBox(height: 12),
                      pw.Text('Productos ajustados: ${resumen.length}',
                          style: baseStyle.copyWith(fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text('Ajuste generado satisfactoriamente ✓',
                          style: boldStyle.copyWith(
                              fontSize: 9, color: PdfColors.green700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          footer: (context) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Text(
                  'Este documento registra los cambios físicos aplicados al stock del sistema. Pharma Salud — Gestión de Inventario.',
                  style: baseStyle.copyWith(
                      fontSize: 8,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600)),
            ],
          ),
        ),
      );

      final directory = await getApplicationSupportDirectory();
      final folderPath = '${directory.path}/PharmaSalud/Reportes/Ajustes';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final file = File('$folderPath/Ajuste_ID_$idSession.pdf');
      await file.writeAsBytes(await pdf.save());

      print('Reporte guardado en: ${file.path}');
    } catch (e) {
      print('Error al generar PDF de ajuste: $e');
      rethrow;
    }
  }

  /// Exportar inventario completo a PDF
  Future<void> _exportarPDF() async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
      final totalProductos = _productos.length;
      final productosStockBajo = _productos
          .where((p) => (p['Cantidad_Total'] ?? 0) <= (p['Stock_Minimo'] ?? 0))
          .length;
      final valorTotal = _calcularValorTotalInventario();

      // Cargar la fuente Outfit para el PDF
      final fontDataReg =
          await rootBundle.load("assets/fonts/Outfit-Regular.ttf");
      final fontDataBold =
          await rootBundle.load("assets/fonts/Outfit-Bold.ttf");
      final myFont = pw.Font.ttf(fontDataReg);
      final myFontBold = pw.Font.ttf(fontDataBold);

      // Cargar Logo
      final logoData = await rootBundle.load("assets/icon/icono.png");
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      // Estilos
      final headerStyle = pw.TextStyle(
        fontSize: 9,
        font: myFontBold,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final cellStyle = pw.TextStyle(fontSize: 8, font: myFont);
      final cellBoldStyle = pw.TextStyle(
        fontSize: 8,
        font: myFontBold,
        fontWeight: pw.FontWeight.bold,
      );

      // Construir todas las filas de la tabla de una vez
      final List<pw.TableRow> allRows = [];

      // Fila de encabezado
      allRows.add(
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.red900),
          children: [
            _pdfCell('#', headerStyle, alignment: pw.Alignment.center),
            _pdfCell('PRODUCTO', headerStyle),
            _pdfCell('TIPO', headerStyle, alignment: pw.Alignment.center),
            _pdfCell('STOCK (UND)', headerStyle,
                alignment: pw.Alignment.center),
            _pdfCell('P. UNIT.', headerStyle, alignment: pw.Alignment.center),
            _pdfCell('VALOR STOCK', headerStyle,
                alignment: pw.Alignment.center),
          ],
        ),
      );

      // Filas de datos
      for (int i = 0; i < _productos.length; i++) {
        final p = _productos[i];
        final stock = (p['Cantidad_Total'] as int?) ?? 0;
        final precio = (p['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
        final valorStock = stock * precio;
        final tipo = p['Tipo_Producto'] ?? '--';
        final esCritico = stock <= ((p['Stock_Minimo'] as int?) ?? 0);
        final rowColor = esCritico
            ? PdfColors.red50
            : (i % 2 == 0 ? PdfColors.white : PdfColors.grey50);

        allRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: [
              _pdfCell('${i + 1}', cellStyle, alignment: pw.Alignment.center),
              _pdfCell(p['Nombre_Producto'] ?? 'N/A',
                  esCritico ? cellBoldStyle : cellStyle),
              _pdfCell(tipo, cellStyle, alignment: pw.Alignment.center),
              _pdfCell('$stock', cellBoldStyle, alignment: pw.Alignment.center),
              _pdfCell('S/ ${formatMoney(precio)}', cellStyle,
                  alignment: pw.Alignment.center),
              _pdfCell('S/ ${formatMoney(valorStock)}', cellBoldStyle,
                  alignment: pw.Alignment.center),
            ],
          ),
        );
      }

      // Usar MultiPage para paginación automática
      pdf.addPage(
        pw.MultiPage(
          maxPages: 200,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: myFont,
            bold: myFontBold,
          ),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Image(logoImage, width: 40, height: 40),
                        pw.SizedBox(width: 12),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PHARMA SALUD',
                                style: pw.TextStyle(
                                    fontSize: 22,
                                    font: myFontBold,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.red900)),
                            pw.Text('Reporte de Inventario Actual',
                                style: pw.TextStyle(
                                    fontSize: 12,
                                    font: myFont,
                                    color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Fecha: $fechaStr',
                            style: pw.TextStyle(fontSize: 8, font: myFont)),
                        pw.Text(
                            'Página ${context.pageNumber} de ${context.pagesCount}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                font: myFont,
                                color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _resumenBox('Total Productos', '$totalProductos',
                        PdfColors.grey700, myFont, myFontBold),
                    _resumenBox('Stock Crítico', '$productosStockBajo',
                        PdfColors.red900, myFont, myFontBold),
                    _resumenBox(
                        'Valorización Total',
                        'S/ ${formatMoney(valorTotal)}',
                        PdfColors.blueGrey800,
                        myFont,
                        myFontBold),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'Pharma Salud — Sistema de Gestión de Inventario — Generado el $fechaStr',
                style: pw.TextStyle(
                    fontSize: 7, font: myFont, color: PdfColors.grey500),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1.2),
                },
                children: allRows,
              ),
            ];
          },
        ),
      );

      // Guardar PDF
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Reporte de Inventario',
        fileName: 'inventario_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsBytes(await pdf.save());
        _showSnackBar('Reporte PDF guardado exitosamente');
      }
    } catch (e) {
      _showSnackBar('Error al exportar PDF: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  pw.Widget _resumenBox(String label, String value, PdfColor color,
      pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: font, fontSize: 8, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(
      String label, double value, pw.TextStyle style, PdfColor color,
      {bool isNet = false}) {
    final sign = isNet ? (value >= 0 ? '+' : '-') : '';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style.copyWith(fontSize: 9)),
        pw.Text('$sign S/ ${formatMoney(value.abs())}',
            style: style.copyWith(fontSize: 9, color: color)),
      ],
    );
  }

  pw.Widget _pdfCell(String text, pw.TextStyle style,
      {pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(text, style: style),
    );
  }

  double _calcularValorTotalInventario() {
    double total = 0;
    for (var p in _productos) {
      final stock = (p['Cantidad_Total'] as int?) ?? 0;
      final precio = (p['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
      total += stock * precio;
    }
    return total;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(message,
                  style: const TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<bool?> _showConfirmAllAjustesDialog(int cantidad) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
                        color: const Color(0xFF007AFF).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.playlist_add_check_rounded,
                        size: 48,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Aplicar Ajuste de Inventario",
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
                      "$cantidad productos serán procesados (ajustes y conformes)",
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _summaryBoxDialog(
                              'Sobrante',
                              'S/ ${formatMoney(_totalSobrante)}',
                              const Color(0xFF34C759)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryBoxDialog(
                              'Faltante',
                              'S/ ${formatMoney(_totalFaltante)}',
                              const Color(0xFFFF9500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Se ajustarán todos los productos con diferencias. Esta acción se registrará en el Kardex.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: const Color(0xFF1D1D1F).withOpacity(0.5),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('CANCELAR',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                    color: Color(0xFF1D1D1F))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('APLICAR AJUSTE',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 1)),
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
      ),
    );
  }

  Widget _summaryBoxDialog(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFamily: 'Outfit',
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  /// Limpiar todos los conteos
  void _limpiarConteos() {
    setState(() {
      _conteosReales.clear();
      _ajustados.clear();
      _conformes.clear();
      for (var ctrl in _inputControllers.values) {
        ctrl.dispose();
      }
      _inputControllers.clear();
    });
  }

  /// Abre el modal con la lista de reportes guardados
  Future<void> _mostrarHistorialReportes() async {
    final directory = await getApplicationSupportDirectory();
    final folderPath = '${directory.path}/PharmaSalud/Reportes/Ajustes';
    final folder = Directory(folderPath);

    List<File> reportes = [];
    if (await folder.exists()) {
      reportes = folder
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.pdf'))
          .toList();
      // Ordenar por fecha de modificación (más reciente primero)
      reportes
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                // Header del Modal
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1D1F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_copy_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historial de Ajustes',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            Text(
                              'Reportes PDF guardados automáticamente',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // Lista de Reportes
                Expanded(
                  child: reportes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf_outlined,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No hay reportes guardados aún',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.5),
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: reportes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final file = reportes[index];
                            final fileName =
                                file.path.split(Platform.pathSeparator).last;
                            final stats = file.statSync();
                            final dateStr = DateFormat('dd/MM/yyyy HH:mm')
                                .format(stats.modified);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _abrirPDF(file.path),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.picture_as_pdf_rounded,
                                          color: Color(0xFFFF3B30), size: 32),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                fontFamily: 'Outfit',
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Generado el $dateStr',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey
                                                    .withOpacity(0.7),
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.open_in_new_rounded,
                                          color: Colors.blue, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Carpeta: Documents/PharmaSalud/Reportes/Ajustes',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.withOpacity(0.5),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirPDF(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path.replaceAll('/', '\\')]);
      }
    } catch (e) {
      _showSnackBar('No se pudo abrir el archivo: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Ajuste de Inventario',
                          style: TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Compara stock del sistema vs. conteo físico y ajusta diferencias',
                        style: TextStyle(
                          color: const Color(0xFF1D1D1F).withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _toolButton(
                      Icons.folder_copy_rounded,
                      'Historial Ajustes',
                      _mostrarHistorialReportes,
                      color: const Color(0xFF007AFF),
                    ),
                    const SizedBox(width: 8),
                    _toolButton(
                      Icons.picture_as_pdf_outlined,
                      'Descargar Stock Actual',
                      _isExporting ? null : _exportarPDF,
                      color: const Color(0xFFFF3B30),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tab Navigation Bar
            _buildTabBar(),

            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _activeTab == 0
                    ? _buildAjustarStockTab()
                    : _buildCampanasTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAjustarStockTab() {
    return Column(
      key: const ValueKey('tab_ajustes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // ─── KPI cards ───
            Row(
              children: [
                _kpiCard(
                  'SOBRANTE',
                  'S/ ${formatMoney(_totalSobrante)}',
                  Icons.trending_up_rounded,
                  const Color(0xFF34C759),
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  'FALTANTE',
                  'S/ ${formatMoney(_totalFaltante)}',
                  Icons.trending_down_rounded,
                  const Color(0xFFFF9500),
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  'CON DIFERENCIA',
                  '$_productosConDiferencia productos',
                  Icons.compare_arrows_rounded,
                  const Color(0xFF007AFF),
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  'BALANCE INVENTARIO',
                  '${(_totalSobrante - _totalFaltante) >= 0 ? '+' : '-'} S/ ${formatMoney((_totalSobrante - _totalFaltante).abs())}',
                  (_totalSobrante - _totalFaltante) >= 0
                      ? Icons.arrow_circle_up_rounded
                      : Icons.arrow_circle_down_rounded,
                  (_totalSobrante - _totalFaltante) >= 0
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                  subtitle: 'Diferencia Neta',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ─── Search bar + actions ───
            Row(
              children: [
                Expanded(
                  child: KeyFocusWrapper(
                    bindings: {LogicalKeyboardKey.f1: _searchFocusNode},
                    actions: {
                      LogicalKeyboardKey.escape: () {
                        _searchController.clear();
                        _filterProductos('');
                      }
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: const Color(0xFF1D1D1F).withOpacity(0.3),
                              size: 18),
                          const SizedBox(width: 8),
                          const F1Badge(label: 'F1'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Buscar producto por nombre...',
                                hintStyle: TextStyle(
                                  color: const Color(0xFF1D1D1F).withOpacity(0.3),
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(
                                  fontSize: 14, fontFamily: 'Outfit'),
                              onChanged: _filterProductos,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_productosFiltrados.length} productos',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D1D1F).withOpacity(0.4),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
                _toolButton(
                  Icons.playlist_add_check_rounded,
                  'Aplicar Ajuste',
                  _productosPendientesAjuste > 0 ? _aplicarTodosLosAjustes : null,
                  color: const Color(0xFF007AFF),
                ),
                const SizedBox(width: 8),
                _toolButton(
                  Icons.refresh_rounded,
                  'Limpiar',
                  _conteosReales.isNotEmpty ? _limpiarConteos : null,
                ),
                const SizedBox(width: 8),
                _toolButton(
                  Icons.fact_check_rounded,
                  'Conteos del POS',
                  _mostrarModalImportarPos,
                  color: const Color(0xFF34C759),
                ),
                const SizedBox(width: 8),
                _toolButton(
                  Icons.history_rounded,
                  'Historial POS',
                  _mostrarHistorialPos,
                  color: const Color(0xFF007AFF),
                ),
                const SizedBox(width: 8),
                _toolButton(
                  Icons.compare_arrows_rounded,
                  'Conteo Cruzado',
                  _mostrarConteoCruzado,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Status Filter ───
            Row(
              children: [
                _statusFilterChip('Todos', Icons.list_rounded),
                const SizedBox(width: 8),
                _statusFilterChip('Pendientes', Icons.pending_actions_rounded),
                const SizedBox(width: 8),
                _statusFilterChip(
                    'Ajustados', Icons.check_circle_outline_rounded),
              ],
            ),

            const SizedBox(height: 16),

            // ─── Table header ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 4, child: Align(alignment: Alignment.centerLeft, child: _tableHeader('PRODUCTO'))),
                  Expanded(flex: 1, child: Center(child: _tableHeader('TIPO'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('STOCK SISTEMA'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('CONTEO FÍSICO'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('DIFERENCIA'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('VALOR DIFERENCIA'))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ─── Table body ───
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF9500)),
                      ),
                    )
                  : _productosFiltrados.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _productosFiltrados.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          itemBuilder: (context, index) {
                            return _buildDataRow(
                                _productosFiltrados[index], index);
                          },
                        ),
            ),
          ],
        );
      }
  Widget _kpiCard(String label, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D1D1F).withOpacity(0.4),
                      fontFamily: 'Outfit',
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1D1D1F),
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: color.withOpacity(0.7),
                        fontFamily: 'Outfit',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'Sin productos para ajustar',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F)),
          ),
          const SizedBox(height: 8),
          Text(
            'Registra productos primero o ajusta los filtros de búsqueda',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: const Color(0xFF1D1D1F).withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> producto, int index) {
    final id = producto['ID'] as int;
    final tipo = producto['Tipo_Producto'] ?? '--';
    final stockSistema = (producto['Cantidad_Total'] as int?) ?? 0;
    final qtyPres = (producto['Cantidad_Presentacion'] as int?) ?? 1;
    final diferencia = _getDiferencia(producto);
    final valorDif = _getValorDiferencia(producto);
    final tieneConteo = _conteosReales.containsKey(id);
    final fueAjustado = _ajustados[id] == true;

    // Stock display
    String stockDisplay;
    if (tipo == 'Caja' && qtyPres > 0) {
      int cajas = stockSistema ~/ qtyPres;
      int unidades = stockSistema % qtyPres;
      stockDisplay = '$cajas cajas / $unidades unidades';
    } else {
      stockDisplay = '$stockSistema unidades';
    }

    final esConforme = _conformes[id] == true;
    Color? diffColor;
    String diffText = '--';
    if (tieneConteo) {
      if (diferencia > 0) {
        diffColor = const Color(0xFF34C759);
        diffText = '+$diferencia';
      } else if (diferencia < 0) {
        diffColor = const Color(0xFFFF9500);
        diffText = '$diferencia';
      } else {
        diffColor = const Color(0xFF1D1D1F).withOpacity(0.3);
        diffText = '0 ✓';
      }
    } else if (esConforme) {
      diffColor = const Color(0xFF1D1D1F).withOpacity(0.3);
      diffText = '0 ✓';
    }

    return Material(
      color: fueAjustado
          ? const Color(0xFF34C759).withOpacity(0.04)
          : Colors.white,
      borderRadius: (index == 0 && _productosFiltrados.length == 1)
          ? BorderRadius.circular(12)
          : index == 0
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : index == _productosFiltrados.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Nombre del producto
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fueAjustado)
                        const Padding(
                          padding: EdgeInsets.only(right: 6.0, top: 2.0),
                          child: Icon(Icons.check_circle_rounded,
                              color: Color(0xFF34C759), size: 14),
                        ),
                      Expanded(
                        child: Text(
                          producto['Nombre_Producto'] ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1D1D1F),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'SKU: PRD-${id.toString().padLeft(4, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF1D1D1F).withOpacity(0.3),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),

            // Tipo
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tipo.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D1D1F).withOpacity(0.6),
                      letterSpacing: 0.5,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ),

            // Stock sistema
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      stockDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF1D1D1F),
                        fontFamily: 'Outfit',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!fueAjustado) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.sync_rounded, size: 14, color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _refrescarStockProducto(id),
                      tooltip: 'Refrescar stock actual',
                    ),
                  ],
                ],
              ),
            ),

            // Conteo físico (input)
            Expanded(
              flex: 2,
              child: Center(
                child: fueAjustado
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AJUSTADO ✓',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34C759),
                            fontFamily: 'Outfit',
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    : esConforme
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF007AFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'CONFORME ✓',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF007AFF),
                                    fontFamily: 'Outfit',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _conformes.remove(id);
                                  });
                                },
                                tooltip: 'Editar/Modificar',
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 65,
                                height: 36,
                                child: TextField(
                                  key: ValueKey('conteo_$id'),
                                  controller: _getInputController(id),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Outfit',
                                    color: Color(0xFF1D1D1F),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '$stockSistema',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF1D1D1F).withOpacity(0.2),
                                      fontSize: 13,
                                      fontFamily: 'Outfit',
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFFF9500), width: 1.5),
                                    ),
                                  ),
                                  onTap: () => _refrescarStockProducto(id),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value.isEmpty) {
                                        _conteosReales.remove(id);
                                      } else {
                                        _conteosReales[id] = int.tryParse(value) ?? 0;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline_rounded,
                                    color: Color(0xFF34C759), size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _marcarConforme(id),
                                tooltip: 'Conforme (Marca igual a stock real actual)',
                              ),
                            ],
                          ),
              ),
            ),

            // Diferencia
            Expanded(
              flex: 2,
              child: Center(
                child: (tieneConteo || esConforme)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (diffColor ?? Colors.grey).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          diffText,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: diffColor,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      )
                    : Text(
                        '--',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF1D1D1F).withOpacity(0.2),
                          fontFamily: 'Outfit',
                        ),
                      ),
              ),
            ),

            // Valor diferencia
            Expanded(
              flex: 2,
              child: Center(
                child: tieneConteo && diferencia != 0
                    ? Text(
                        '${valorDif >= 0 ? '+' : '-'} S/ ${formatMoney(valorDif.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: valorDif >= 0
                              ? const Color(0xFF34C759)
                              : const Color(0xFFFF9500),
                          fontFamily: 'Outfit',
                        ),
                      )
                    : Text(
                        '--',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF1D1D1F).withOpacity(0.2),
                          fontFamily: 'Outfit',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D1D1F).withOpacity(0.3),
        letterSpacing: 1.2,
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback? onTap,
      {Color? color}) {
    final effectiveColor = color ?? const Color(0xFF1D1D1F);
    final isDisabled = onTap == null;
    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
                color: effectiveColor.withOpacity(isDisabled ? 0.05 : 0.15)),
            borderRadius: BorderRadius.circular(8),
            color: isDisabled
                ? Colors.grey.withOpacity(0.04)
                : effectiveColor.withOpacity(0.04),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: effectiveColor.withOpacity(isDisabled ? 0.2 : 0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: effectiveColor.withOpacity(isDisabled ? 0.2 : 0.7),
                  letterSpacing: 0.5,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusFilterChip(String status, IconData icon) {
    final isSelected = _filtroStatus == status;
    final color =
        isSelected ? const Color(0xFF007AFF) : const Color(0xFF1D1D1F);

    return InkWell(
      onTap: () {
        setState(() => _filtroStatus = status);
        _filterProductos(_searchController.text);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: color.withOpacity(isSelected ? 1 : 0.5)),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Outfit',
                color: color.withOpacity(isSelected ? 1 : 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabItem(0, 'Ajustar Stock', Icons.tune_rounded),
          _buildTabItem(1, 'Campañas / Consolidados', Icons.layers_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F).withOpacity(0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F).withOpacity(0.5),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampanasTab() {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        key: const ValueKey('tab_campanas'),
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_campanaActiva != null) ...[
              _buildActiveCampaignCard(),
              const SizedBox(height: 24),
            ] else ...[
              _buildNoActiveCampaignCard(),
              const SizedBox(height: 24),
            ],
            
            const Text(
              'Historial de Campañas Completadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 12),
            _campanasPasadas.isEmpty
                ? _buildEmptyCampanasState()
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _campanasPasadas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildPastCampaignCard(_campanasPasadas[index]);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCampaignCard() {
    final nombre = _campanaActiva!['NOMBRE'] ?? 'Campaña sin nombre';
    final fechaInicioStr = _campanaActiva!['FECHA_INICIO'] as String;
    final id = _campanaActiva!['ID'] as int;
    
    DateTime? fechaInicio;
    try {
      fechaInicio = DateTime.parse(fechaInicioStr.replaceAll(' ', 'T'));
    } catch (_) {}
    
    final formattedFecha = fechaInicio != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(fechaInicio)
        : fechaInicioStr;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5856D6), Color(0xFF007AFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_filled_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'CAMPAÑA DE INVENTARIO ACTIVA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EN CURSO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            nombre,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Iniciado el: $formattedFecha',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.insert_chart_outlined_rounded, size: 16, color: Color(0xFF007AFF)),
                label: const Text('Ver Consolidado', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF007AFF))),
                onPressed: () => _mostrarConsolidadoModal(_campanaActiva!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF007AFF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Colors.white),
                label: const Text('Cuadre Global con Caja', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13, color: Colors.white)),
                onPressed: () => _iniciarConciliacionDesdeCampana(_campanaActiva!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.white),
                label: const Text('Editar Hito Inicial', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13, color: Colors.white)),
                onPressed: () => _editarHitoInicial(id, fechaInicio ?? DateTime.now(), nombre),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white38, width: 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.stop_circle_rounded, size: 16, color: Colors.white),
                label: const Text('Finalizar Inventario', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13, color: Colors.white)),
                onPressed: () => _finalizarInventarioDialog(id, nombre),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNoActiveCampaignCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.layers_clear_rounded,
                color: Color(0xFFFF9500), size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No hay ninguna campaña de inventario activa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1D1F),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicia un hito para agrupar todos los ajustes que realices en tu botica durante los próximos días.',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1D1D1F).withOpacity(0.5),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('Iniciar Inventario', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Colors.white)),
            onPressed: _iniciarInventarioDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D1D1F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastCampaignCard(Map<String, dynamic> campana) {
    final nombre = campana['NOMBRE'] ?? 'Campaña';
    final inicioStr = campana['FECHA_INICIO'] as String;
    final finStr = campana['FECHA_FIN'] as String? ?? 'N/A';
    final id = campana['ID'] as int;

    DateTime? dateInicio;
    DateTime? dateFin;
    try {
      dateInicio = DateTime.parse(inicioStr.replaceAll(' ', 'T'));
      dateFin = DateTime.parse(finStr.replaceAll(' ', 'T'));
    } catch (_) {}

    final formattedInicio = dateInicio != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(dateInicio)
        : inicioStr;
    final formattedFin = dateFin != null
        ? DateFormat('dd/MM/yyyy hh:mm a').format(dateFin)
        : finStr;

    String duracionStr = '';
    if (dateInicio != null && dateFin != null) {
      final diff = dateFin.difference(dateInicio);
      if (diff.inDays > 0) {
        duracionStr = 'Duración: ${diff.inDays}d ${diff.inHours % 24}h';
      } else if (diff.inHours > 0) {
        duracionStr = 'Duración: ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        duracionStr = 'Duración: ${diff.inMinutes}m';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1D1F),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 12, color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Text(
                      '$formattedInicio  ➜  $formattedFin',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF1D1D1F).withOpacity(0.5),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    if (duracionStr.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          duracionStr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D1D1F).withOpacity(0.5),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF34C759), size: 20),
                onPressed: () => _iniciarConciliacionDesdeCampana(campana),
                tooltip: 'Conciliación Global con Caja',
              ),
              IconButton(
                icon: const Icon(Icons.article_outlined, color: Color(0xFF007AFF), size: 20),
                onPressed: () => _mostrarConsolidadoModal(campana),
                tooltip: 'Ver Reporte Consolidado',
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, color: Colors.grey, size: 20),
                onPressed: () => _editarHitoPasado(id, dateInicio ?? DateTime.now(), dateFin ?? DateTime.now(), nombre),
                tooltip: 'Editar Rango de Fechas',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 20),
                onPressed: () => _eliminarCampanaConfirm(id, nombre),
                tooltip: 'Eliminar Historial',
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyCampanasState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        'No hay campañas finalizadas registradas.',
        style: TextStyle(
          fontSize: 13,
          color: const Color(0xFF1D1D1F).withOpacity(0.4),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Future<DateTime?> _seleccionarFechaHora(DateTime initial) async {
    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D1D1F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1D1D1F),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _iniciarInventarioDialog() async {
    final ctrl = TextEditingController(text: 'Inventario General - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    DateTime selectedStart = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D1D1F),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Iniciar Nueva Campaña',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOMBRE DEL INVENTARIO',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5F5F7),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF1D1D1F)),
                            hintText: 'Ej. Inventario Anual',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Outfit'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'HITO DE INICIO (FECHA Y HORA)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final dt = await _seleccionarFechaHora(selectedStart);
                            if (dt != null) {
                              setDialogState(() {
                                selectedStart = dt;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF007AFF)),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd/MM/yyyy hh:mm a').format(selectedStart),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Iniciar Campaña',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () async {
                                final nombre = ctrl.text.trim();
                                if (nombre.isNotEmpty) {
                                  await _campanaRepo.iniciarCampana(nombre, selectedStart);
                                  await _loadCampanas();
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D1D1F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ),
        ),
      ),
    );
  }

  Future<void> _finalizarInventarioDialog(int id, String nombre) async {
    DateTime selectedEnd = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Destructive Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30), // Destructive Red Header
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Finalizar Campaña',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Estás seguro de finalizar la campaña de inventario "$nombre"?',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'HITO DE CIERRE (FECHA Y HORA)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final dt = await _seleccionarFechaHora(selectedEnd);
                            if (dt != null) {
                              setDialogState(() {
                                selectedEnd = dt;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFFF3B30)),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd/MM/yyyy hh:mm a').format(selectedEnd),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Finalizar Inventario',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () async {
                                await _campanaRepo.finalizarCampana(id, selectedEnd);
                                await _loadCampanas();
                                if (mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ),
        ),
      ),
    );
  }

  Future<void> _editarHitoInicial(int id, DateTime inicioActual, String nombre) async {
    final dt = await _seleccionarFechaHora(inicioActual);
    if (dt != null) {
      await _campanaRepo.editarFechas(id, dt, null);
      await _loadCampanas();
      _showSnackBar('Hito inicial actualizado con éxito.');
    }
  }

  Future<void> _editarHitoPasado(int id, DateTime inicioActual, DateTime finActual, String nombre) async {
    DateTime? selectedStart = inicioActual;
    DateTime? selectedEnd = finActual;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D1D1F),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Editar Fechas - $nombre',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Outfit',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HITO DE INICIO',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final dt = await _seleccionarFechaHora(selectedStart!);
                            if (dt != null) {
                              setDialogState(() {
                                selectedStart = dt;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF007AFF)),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd/MM/yyyy hh:mm a').format(selectedStart!),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'HITO DE FIN',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final dt = await _seleccionarFechaHora(selectedEnd!);
                            if (dt != null) {
                              setDialogState(() {
                                selectedEnd = dt;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFFF9500)),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('dd/MM/yyyy hh:mm a').format(selectedEnd!),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Guardar Cambios',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () async {
                                await _campanaRepo.editarFechas(id, selectedStart!, selectedEnd);
                                await _loadCampanas();
                                if (mounted) Navigator.pop(context);
                                _showSnackBar('Fechas de campaña actualizadas.');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D1D1F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarCampanaConfirm(int id, String nombre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Destructive Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Eliminar Registro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Estás seguro de eliminar el registro de la campaña "$nombre"?',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esta acción no revierte los ajustes del stock físico en los productos, solo borrará la campaña del historial.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: const Color(0xFF1D1D1F).withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B30),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        ),
      ),
    );
    if (confirmed == true) {
      await _campanaRepo.eliminarCampana(id);
      await _loadCampanas();
      _showSnackBar('Registro de campaña eliminado.');
    }
  }

  Future<void> _mostrarConsolidadoModal(Map<String, dynamic> campana) async {
    final startStr = campana['FECHA_INICIO'] as String;
    final endStr = campana['FECHA_FIN'] as String? ?? 
        DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);
        
    final rawAjustes = await _campanaRepo.obtenerAjustesEnRango(startStr, endStr);
    
    // Agrupar los ajustes por NOMBRE_PRODUCTO
    final Map<String, Map<String, dynamic>> agrupados = {};
    double totalSobranteConsol = 0;
    double totalFaltanteConsol = 0;

    for (var a in rawAjustes) {
      final name = a['NOMBRE_PRODUCTO'] as String;
      final cant = a['CANTIDAD'] as int;
      final tipoMov = a['TIPO_MOVIMIENTO'] as String;
      
      // La cantidad a sumar/restar es neta
      final diff = tipoMov.contains('+') ? cant : -cant;
      
      final costoUnidad = (a['Costo_Unidad'] as num?)?.toDouble() ?? 0.0;
      final precioUnidad = (a['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
      final valorRef = costoUnidad > 0 ? costoUnidad : precioUnidad;
      
      final stockSis = (a['STOCK_SISTEMA'] as num?)?.toInt() ?? 0;
      final conteoFis = (a['CONTEO_FISICO'] as num?)?.toInt() ?? 0;

      if (agrupados.containsKey(name)) {
        final prevDiff = agrupados[name]!['diferencia'] as int;
        final newDiff = prevDiff + diff;
        agrupados[name]!['diferencia'] = newDiff;
        agrupados[name]!['valor'] = newDiff * valorRef;
        if (stockSis > 0) agrupados[name]!['stock_sistema'] = stockSis;
        if (conteoFis > 0) agrupados[name]!['conteo_fisico'] = conteoFis;
      } else {
        agrupados[name] = {
          'nombre': name,
          'tipo': a['Tipo_Producto'] ?? 'Varios',
          'diferencia': diff,
          'costo_unidad': costoUnidad,
          'precio_unidad': precioUnidad,
          'valor': diff * valorRef,
          'stock_sistema': stockSis,
          'conteo_fisico': conteoFis,
        };
      }
    }

    final listaAjustes = agrupados.values.toList();
    
    for (var a in listaAjustes) {
      final val = a['valor'] as double;
      if (val > 0) totalSobranteConsol += val;
      if (val < 0) totalFaltanteConsol += val.abs();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1D1F),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campana['NOMBRE'] ?? 'Campaña de Inventario',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Consolidado: ${campana['FECHA_INICIO']}  ➜  ${campana['FECHA_FIN'] ?? 'En Curso'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // KPIs Consolidado
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                  child: Row(
                    children: [
                      _kpiCardConsol('SOBRANTE CONSOL.', 'S/ ${formatMoney(totalSobranteConsol)}', const Color(0xFF34C759)),
                      const SizedBox(width: 12),
                      _kpiCardConsol('FALTANTE CONSOL.', 'S/ ${formatMoney(totalFaltanteConsol)}', const Color(0xFFFF9500)),
                      const SizedBox(width: 12),
                      _kpiCardConsol(
                        'BALANCE NETO', 
                        '${(totalSobranteConsol - totalFaltanteConsol) >= 0 ? '+' : '-'} S/ ${formatMoney((totalSobranteConsol - totalFaltanteConsol).abs())}', 
                        (totalSobranteConsol - totalFaltanteConsol) >= 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                        isBalance: true,
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Body Table
                Expanded(
                  child: listaAjustes.isEmpty
                      ? Center(
                          child: Text(
                            'No se registraron ajustes de diferencia en este periodo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF1D1D1F).withOpacity(0.4),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            // Table Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              child: Row(
                                children: [
                                  const Expanded(flex: 6, child: Text('PRODUCTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Outfit'))),
                                  const Expanded(flex: 2, child: Center(child: Text('SISTEMA (HABÍA)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Outfit')))),
                                  const Expanded(flex: 2, child: Center(child: Text('CONTEO FÍSICO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Outfit')))),
                                  const Expanded(flex: 2, child: Center(child: Text('DIFERENCIA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Outfit')))),
                                  const Expanded(flex: 2, child: Center(child: Text('VALOR (S/)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: 'Outfit')))),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                itemCount: listaAjustes.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final a = listaAjustes[index];
                                  final diff = a['diferencia'] as int;
                                  final val = a['valor'] as double;
                                  final stockSis = a['stock_sistema'] as int;
                                  final conteoFis = a['conteo_fisico'] as int;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a['nombre'] ?? '',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit', color: Color(0xFF1D1D1F)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                (a['tipo'] as String).toUpperCase(),
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey.shade500, fontFamily: 'Outfit'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              stockSis > 0 ? '$stockSis und' : (conteoFis > 0 ? '${conteoFis - diff} und' : '-'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              conteoFis > 0 ? '$conteoFis und' : (stockSis > 0 ? '${stockSis + diff} und' : '-'),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF007AFF),
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (diff > 0 
                                                    ? const Color(0xFF34C759) 
                                                    : (diff < 0 ? const Color(0xFFFF3B30) : Colors.grey)).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                diff > 0 ? '+$diff und' : '$diff und',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: diff > 0 
                                                      ? const Color(0xFF34C759) 
                                                      : (diff < 0 ? const Color(0xFFFF3B30) : Colors.grey),
                                                  fontFamily: 'Outfit',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Text(
                                              'S/ ${formatMoney(val.abs())}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: val > 0 
                                                    ? const Color(0xFF34C759) 
                                                    : (val < 0 ? const Color(0xFFFF3B30) : Colors.grey),
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                
                // Footer buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                        label: const Text('Conciliar con Caja', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        onPressed: () {
                          _mostrarDialogoConciliacion(
                            campana: campana,
                            totalSobranteInv: totalSobranteConsol,
                            totalFaltanteInv: totalFaltanteConsol,
                            balanceInv: totalSobranteConsol - totalFaltanteConsol,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF3B30)),
                        label: const Text('Exportar PDF Consolidado', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF3B30), fontFamily: 'Outfit')),
                        onPressed: () => _generarPDFConsolidado(campana, listaAjustes, totalSobranteConsol, totalFaltanteConsol),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF3B30)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D1D1F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpiCardConsol(String label, String value, Color color, {bool isBalance = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isBalance ? color : const Color(0xFF1D1D1F),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarPDFConsolidado(
      Map<String, dynamic> campana,
      List<Map<String, dynamic>> listaAjustes,
      double totalSobrante,
      double totalFaltante) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
      
      final startStr = campana['FECHA_INICIO'] as String;
      final endStr = campana['FECHA_FIN'] as String? ?? 
          DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      final myFont = pw.Font.helvetica();
      final myFontBold = pw.Font.helveticaBold();
      
      final baseStyle = pw.TextStyle(font: myFont, fontSize: 10, color: PdfColors.black);
      final boldStyle = pw.TextStyle(font: myFontBold, fontSize: 10, color: PdfColors.black);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PHARMA SALUD',
                      style: boldStyle.copyWith(
                          fontSize: 22, color: PdfColors.red900)),
                  pw.Text('Reporte Consolidado de Inventario',
                      style: baseStyle.copyWith(
                          fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Campaña: ${campana['NOMBRE']}',
                      style: boldStyle.copyWith(fontSize: 10)),
                  pw.Text('Inicio: $startStr',
                      style: baseStyle.copyWith(fontSize: 9)),
                  pw.Text('Fin: $endStr',
                      style: baseStyle.copyWith(fontSize: 9)),
                ],
              ),
            ],
          ),
          build: (context) => [
            pw.SizedBox(height: 20),
            
            // KPIs Row
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL SOBRANTE', style: boldStyle.copyWith(fontSize: 8, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('S/ ${formatMoney(totalSobrante)}', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.green800)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL FALTANTE', style: boldStyle.copyWith(fontSize: 8, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('S/ ${formatMoney(totalFaltante)}', style: boldStyle.copyWith(fontSize: 14, color: PdfColors.orange800)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BALANCE NETO', style: boldStyle.copyWith(fontSize: 8, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${(totalSobrante - totalFaltante) >= 0 ? '+' : '-'} S/ ${formatMoney((totalSobrante - totalFaltante).abs())}', 
                          style: boldStyle.copyWith(fontSize: 14, color: (totalSobrante - totalFaltante) >= 0 ? PdfColors.green800 : PdfColors.red800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 24),
            pw.Text('Detalle de Ajustes Consolidados:', style: boldStyle.copyWith(fontSize: 12)),
            pw.SizedBox(height: 8),
            
            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Producto', style: boldStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tipo', style: boldStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Dif. Neta', style: boldStyle, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Valor Costo', style: boldStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
                for (var a in listaAjustes) ...[
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(a['nombre'] ?? '', style: baseStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text((a['tipo'] as String).toUpperCase(), style: baseStyle)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Text(
                          a['diferencia'] > 0 ? '+${a['diferencia']}' : '${a['diferencia']}', 
                          style: boldStyle.copyWith(color: a['diferencia'] > 0 ? PdfColors.green800 : PdfColors.orange800), 
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6), 
                        child: pw.Text(
                          'S/ ${formatMoney(a['valor'])}', 
                          style: boldStyle.copyWith(color: a['valor'] >= 0 ? PdfColors.black : PdfColors.red800), 
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            
            pw.SizedBox(height: 40),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma del Administrador', style: baseStyle.copyWith(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        ),
      );

      final directory = await getApplicationSupportDirectory();
      final folderPath = '${directory.path}/PharmaSalud/Reportes/Consolidados';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final cleanName = (campana['NOMBRE'] as String).replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File('$folderPath/Consolidado_${cleanName}_ID_${campana['ID']}.pdf');
      await file.writeAsBytes(await pdf.save());

      _showSnackBar('Reporte consolidado guardado en PDF.');
      await _abrirPDF(file.path);
    } catch (e) {
      _showSnackBar('Error al generar PDF consolidado: $e', isError: true);
    }
  }

  /// Iniciar conciliación directa calculando ajustes de la campaña y abriendo el diálogo
  Future<void> _iniciarConciliacionDesdeCampana(Map<String, dynamic> campana) async {
    final startStr = campana['FECHA_INICIO'] as String;
    final endStr = campana['FECHA_FIN'] as String? ??
        DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    final rawAjustes = await _campanaRepo.obtenerAjustesEnRango(startStr, endStr);
    final Map<String, Map<String, dynamic>> agrupados = {};
    double totalSobranteConsol = 0;
    double totalFaltanteConsol = 0;

    for (var a in rawAjustes) {
      final name = a['NOMBRE_PRODUCTO'] as String;
      final cant = a['CANTIDAD'] as int;
      final tipoMov = a['TIPO_MOVIMIENTO'] as String;
      final diff = tipoMov.contains('+') ? cant : -cant;

      final costoUnidad = (a['Costo_Unidad'] as num?)?.toDouble() ?? 0.0;
      final precioUnidad = (a['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
      final valorRef = costoUnidad > 0 ? costoUnidad : precioUnidad;

      if (agrupados.containsKey(name)) {
        final prevDiff = agrupados[name]!['diferencia'] as int;
        agrupados[name]!['diferencia'] = prevDiff + diff;
        agrupados[name]!['valor'] = (prevDiff + diff) * valorRef;
      } else {
        agrupados[name] = {
          'diferencia': diff,
          'valor': diff * valorRef,
        };
      }
    }

    for (var a in agrupados.values) {
      final val = a['valor'] as double;
      if (val > 0) totalSobranteConsol += val;
      if (val < 0) totalFaltanteConsol += val.abs();
    }

    if (!mounted) return;

    await _mostrarDialogoConciliacion(
      campana: campana,
      totalSobranteInv: totalSobranteConsol,
      totalFaltanteInv: totalFaltanteConsol,
      balanceInv: totalSobranteConsol - totalFaltanteConsol,
    );
  }

  /// Diálogo modal para auditar y conciliar inventario físico con sobrantes de caja
  Future<void> _mostrarDialogoConciliacion({
    required Map<String, dynamic> campana,
    required double totalSobranteInv,
    required double totalFaltanteInv,
    required double balanceInv,
  }) async {
    final campanaId = campana['ID'] as int;
    final campanaNombre = campana['NOMBRE'] ?? 'Campaña';
    final startStr = campana['FECHA_INICIO'] as String;
    final endStr = campana['FECHA_FIN'] as String? ??
        DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    // Consultar sobrantes de caja registrados en el periodo sin mutar la tabla original
    final sobrantesCaja =
        await _sobranteCajaRepo.obtenerSobrantesPorRango(startStr, endStr);

    double totalSobranteCaja = 0.0;
    for (var s in sobrantesCaja) {
      totalSobranteCaja += (s['MONTO'] as num?)?.toDouble() ?? 0.0;
    }

    final balanceGlobal = balanceInv + totalSobranteCaja;

    // Verificar si ya existe un cuadre guardado previamente para esta campaña
    final cuadreExistente =
        await _cuadreGlobalRepo.obtenerCuadrePorCampana(campanaId);

    final TextEditingController obsController = TextEditingController(
      text: cuadreExistente?['OBSERVACIONES'] ?? '',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        bool guardando = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 880, maxHeight: 720),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1D1D1F),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFF34C759),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Conciliación y Cuadre Global de Campaña',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$campanaNombre  •  $startStr  ➜  ${campana['FECHA_FIN'] ?? 'En Curso'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.65),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white70),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      ),

                      // Alerta informativa si ya fue guardado previamente
                      if (cuadreExistente != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    const Color(0xFF34C759).withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF34C759), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cuadre registrado previamente el ${cuadreExistente['FECHA_CUADRE']}. Puedes modificar las observaciones y volver a guardar.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D1D1F),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Tarjetas KPI de Comparación Financiera
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                        child: Row(
                          children: [
                            // 1. Balance Inventario
                            Expanded(
                              child: _cardConciliacionKpi(
                                titulo: 'BALANCE INVENTARIO',
                                subtitulo:
                                    'Sob: S/ ${formatMoney(totalSobranteInv)} | Falt: S/ ${formatMoney(totalFaltanteInv)}',
                                valor:
                                    '${balanceInv >= 0 ? '+' : '-'} S/ ${formatMoney(balanceInv.abs())}',
                                color: balanceInv >= 0
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFFF9500),
                                icon: Icons.inventory_2_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 2. Sobrantes Caja Chica
                            Expanded(
                              child: _cardConciliacionKpi(
                                titulo: 'SOBRANTES EN CAJA',
                                subtitulo:
                                    '${sobrantesCaja.length} entrega(s) registradas',
                                valor: '+ S/ ${formatMoney(totalSobranteCaja)}',
                                color: const Color(0xFF007AFF),
                                icon: Icons.point_of_sale_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 3. Balance Global Compensado
                            Expanded(
                              child: _cardConciliacionKpi(
                                titulo: 'BALANCE GLOBAL',
                                subtitulo: balanceGlobal >= 0
                                    ? 'Superávit / Cubierto con caja'
                                    : 'Déficit residual pendiente',
                                valor:
                                    '${balanceGlobal >= 0 ? '+' : '-'} S/ ${formatMoney(balanceGlobal.abs())}',
                                color: balanceGlobal >= 0
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFFF3B30),
                                icon: Icons.account_balance_rounded,
                                isHighlight: true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Sección Detalle de Caja
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded,
                                      size: 16, color: Color(0xFF007AFF)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Sobrantes de Caja Registrados en este Periodo',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D1D1F),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${sobrantesCaja.length} registro(s) • Total: S/ ${formatMoney(totalSobranteCaja)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Header de tabla
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text('VENDEDOR',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontFamily: 'Outfit')),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text('FECHA Y HORA',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontFamily: 'Outfit')),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text('MOTIVO / NOTA',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontFamily: 'Outfit')),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('MONTO (S/)',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                              fontFamily: 'Outfit')),
                                    ),
                                  ],
                                ),
                              ),

                              // Lista de sobrantes
                              Expanded(
                                child: sobrantesCaja.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No se registraron entregas de sobrantes de caja en las fechas de esta campaña.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        itemCount: sobrantesCaja.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, idx) {
                                          final s = sobrantesCaja[idx];
                                          final vendedor =
                                              s['NOMBRE_VENDEDOR'] ?? 'Vendedor';
                                          final fecha = s['FECHA'] ?? '';
                                          final nota = (s['NOTA'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? s['NOTA']
                                              : '-';
                                          final monto = (s['MONTO'] as num?)
                                                  ?.toDouble() ??
                                              0.0;

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    vendedor,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF1D1D1F),
                                                        fontFamily: 'Outfit'),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    fecha,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontFamily: 'Outfit'),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    nota,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade700,
                                                        fontFamily: 'Outfit'),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    '+ S/ ${formatMoney(monto)}',
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Color(0xFF34C759),
                                                        fontFamily: 'Outfit'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),

                              const SizedBox(height: 10),

                              // Campo de Observaciones
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Observaciones / Conclusiones del Administrador:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1D1D1F),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: obsController,
                                    maxLines: 2,
                                    style: const TextStyle(
                                        fontSize: 12, fontFamily: 'Outfit'),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Escribe aquí las conclusiones, compensaciones autorizadas o dictamen de la campaña...',
                                      hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                          fontFamily: 'Outfit'),
                                      filled: true,
                                      fillColor: const Color(0xFFF9F9FA),
                                      contentPadding: const EdgeInsets.all(10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF007AFF)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer Buttons
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBFBFC),
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(24)),
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            // Botón Exportar Acta PDF
                            OutlinedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf_rounded,
                                  color: Color(0xFFFF3B30), size: 18),
                              label: const Text(
                                'Exportar Acta PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF3B30),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              onPressed: () => _generarActaConciliacionPDF(
                                campana: campana,
                                totalSobranteInv: totalSobranteInv,
                                totalFaltanteInv: totalFaltanteInv,
                                balanceInv: balanceInv,
                                totalSobranteCaja: totalSobranteCaja,
                                balanceGlobal: balanceGlobal,
                                sobrantesCaja: sobrantesCaja,
                                observaciones: obsController.text.trim(),
                              ),
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFFFF3B30)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const Spacer(),

                            // Botón Guardar Cuadre
                            ElevatedButton.icon(
                              icon: guardando
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded,
                                      color: Colors.white, size: 18),
                              label: Text(
                                cuadreExistente != null
                                    ? 'Actualizar Cuadre'
                                    : 'Guardar Cuadre',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              onPressed: guardando
                                  ? null
                                  : () async {
                                      setDialogState(() => guardando = true);
                                      try {
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        final adminId =
                                            prefs.getInt('adminId') ?? 1;
                                        final fechaCuadre = DateFormat(
                                                'yyyy-MM-dd HH:mm:ss')
                                            .format(DateTime.now());

                                        await _cuadreGlobalRepo.guardarCuadre(
                                          campanaId: campanaId,
                                          campanaNombre: campanaNombre,
                                          fechaCuadre: fechaCuadre,
                                          fechaInicioCampana: startStr,
                                          fechaFinCampana: endStr,
                                          totalSobranteInv: totalSobranteInv,
                                          totalFaltanteInv: totalFaltanteInv,
                                          balanceInv: balanceInv,
                                          totalSobranteCaja: totalSobranteCaja,
                                          balanceGlobal: balanceGlobal,
                                          observaciones:
                                              obsController.text.trim(),
                                          adminId: adminId,
                                        );

                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                        _showSnackBar(
                                            'Cuadre global de campaña guardado exitosamente.');
                                      } catch (e) {
                                        setDialogState(() => guardando = false);
                                        _showSnackBar(
                                            'Error al guardar cuadre global: $e',
                                            isError: true);
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Botón Cerrar
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D1D1F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cerrar',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cardConciliacionKpi({
    required String titulo,
    required String subtitulo,
    required String valor,
    required Color color,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlight ? color.withOpacity(0.4) : Colors.grey.shade200,
          width: isHighlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                    fontFamily: 'Outfit',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              fontFamily: 'Outfit',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _generarActaConciliacionPDF({
    required Map<String, dynamic> campana,
    required double totalSobranteInv,
    required double totalFaltanteInv,
    required double balanceInv,
    required double totalSobranteCaja,
    required double balanceGlobal,
    required List<Map<String, dynamic>> sobrantesCaja,
    required String observaciones,
  }) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final fechaEmision = DateFormat('dd/MM/yyyy HH:mm').format(now);

      final startStr = campana['FECHA_INICIO'] as String;
      final endStr = campana['FECHA_FIN'] as String? ??
          now.toIso8601String().replaceFirst('T', ' ').substring(0, 19);

      final myFont = pw.Font.helvetica();
      final myFontBold = pw.Font.helveticaBold();

      final baseStyle =
          pw.TextStyle(font: myFont, fontSize: 9, color: PdfColors.black);
      final boldStyle =
          pw.TextStyle(font: myFontBold, fontSize: 9, color: PdfColors.black);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PHARMA SALUD',
                          style: boldStyle.copyWith(
                              fontSize: 22, color: PdfColors.red900)),
                      pw.Text('ACTA DE CONCILIACIÓN GLOBAL DE CAMPAÑA',
                          style: boldStyle.copyWith(
                              fontSize: 12, color: PdfColors.grey800)),
                      pw.Text(
                          'Auditoría Integral de Inventario Físico vs. Sobrantes de Caja',
                          style: baseStyle.copyWith(
                              fontSize: 9, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Campaña: ${campana['NOMBRE']}',
                          style: boldStyle.copyWith(fontSize: 11)),
                      pw.Text('Periodo: $startStr al $endStr',
                          style: baseStyle.copyWith(
                              fontSize: 8, color: PdfColors.grey700)),
                      pw.Text('Fecha Emisión: $fechaEmision',
                          style: baseStyle.copyWith(
                              fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
            ],
          ),
          build: (context) => [
            // Resumen Ejecutivo de Liquidación
            pw.Text('1. RESUMEN EJECUTIVO DE LIQUIDACIÓN',
                style:
                    boldStyle.copyWith(fontSize: 11, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                // Col 1: Inventario
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('INVENTARIO DE STOCK',
                            style: boldStyle.copyWith(
                                fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Sobrante: S/ ${formatMoney(totalSobranteInv)}',
                            style: baseStyle.copyWith(fontSize: 8)),
                        pw.Text('Faltante: S/ ${formatMoney(totalFaltanteInv)}',
                            style: baseStyle.copyWith(fontSize: 8)),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.Text(
                          'Balance: ${balanceInv >= 0 ? '+' : '-'} S/ ${formatMoney(balanceInv.abs())}',
                          style: boldStyle.copyWith(
                            fontSize: 11,
                            color: balanceInv >= 0
                                ? PdfColors.green800
                                : PdfColors.orange900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Col 2: Sobrantes Caja
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SOBRANTES DE CAJA',
                            style: boldStyle.copyWith(
                                fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text('Entregas Caja: ${sobrantesCaja.length}',
                            style: baseStyle.copyWith(fontSize: 8)),
                        pw.Text('Medio: Efectivo Físico',
                            style: baseStyle.copyWith(fontSize: 8)),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.Text(
                          '+ S/ ${formatMoney(totalSobranteCaja)}',
                          style: boldStyle.copyWith(
                              fontSize: 11, color: PdfColors.blue800),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Col 3: Balance Global
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: balanceGlobal >= 0
                            ? PdfColors.green300
                            : PdfColors.red300,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: balanceGlobal >= 0
                          ? PdfColors.green50
                          : PdfColors.red50,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BALANCE GLOBAL COMPENSADO',
                            style: boldStyle.copyWith(
                                fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          balanceGlobal >= 0
                              ? 'Estado: SUPERÁVIT / CUBIERTO'
                              : 'Estado: DÉFICIT RESIDUAL',
                          style: boldStyle.copyWith(
                            fontSize: 8,
                            color: balanceGlobal >= 0
                                ? PdfColors.green800
                                : PdfColors.red800,
                          ),
                        ),
                        pw.Text('(Inv. Stock + Sobrantes Caja)',
                            style: baseStyle.copyWith(
                                fontSize: 7, color: PdfColors.grey600)),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.Text(
                          '${balanceGlobal >= 0 ? '+' : '-'} S/ ${formatMoney(balanceGlobal.abs())}',
                          style: boldStyle.copyWith(
                            fontSize: 13,
                            color: balanceGlobal >= 0
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Detalle de Sobrantes de Caja
            pw.Text('2. DETALLE DE SOBRANTES DE CAJA EN EL PERIODO',
                style:
                    boldStyle.copyWith(fontSize: 11, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            if (sobrantesCaja.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'No se registraron entregas de sobrantes de caja física durante el rango de fechas de esta campaña.',
                  style: baseStyle.copyWith(color: PdfColors.grey600),
                ),
              )
            else
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(4),
                  3: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Vendedor', style: boldStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Fecha y Hora', style: boldStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Nota / Motivo', style: boldStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Monto (S/)',
                            style: boldStyle, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  for (var s in sobrantesCaja)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(s['NOMBRE_VENDEDOR'] ?? 'Vendedor',
                              style: baseStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(s['FECHA'] ?? '', style: baseStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            (s['NOTA'] as String?)?.isNotEmpty == true
                                ? s['NOTA']
                                : '-',
                            style: baseStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'S/ ${formatMoney((s['MONTO'] as num?)?.toDouble() ?? 0.0)}',
                            style: boldStyle.copyWith(color: PdfColors.green800),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            pw.SizedBox(height: 18),

            // Observaciones
            pw.Text('3. OBSERVACIONES Y DICTAMEN ADMINISTRATIVO',
                style:
                    boldStyle.copyWith(fontSize: 11, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey50,
              ),
              child: pw.Text(
                observaciones.isNotEmpty
                    ? observaciones
                    : 'Sin observaciones adicionales registradas. Se da fe de los resultados obtenidos entre la toma física de inventario y los fondos de caja asignados.',
                style: baseStyle.copyWith(lineSpacing: 1.5),
              ),
            ),
            pw.SizedBox(height: 35),

            // Firmas
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 170, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Firma del Administrador / Gerencia',
                        style: boldStyle.copyWith(fontSize: 8)),
                    pw.Text('Aprobado y Conforme',
                        style: baseStyle.copyWith(
                            fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 170, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Responsable de Inventario',
                        style: boldStyle.copyWith(fontSize: 8)),
                    pw.Text('Auditoría / Farmacéutico',
                        style: baseStyle.copyWith(
                            fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final directory = await getApplicationSupportDirectory();
      final folderPath = '${directory.path}/PharmaSalud/Reportes/Conciliaciones';
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final cleanName = (campana['NOMBRE'] as String)
          .replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final file = File(
          '$folderPath/Acta_Conciliacion_${cleanName}_ID_${campana['ID']}.pdf');
      await file.writeAsBytes(await pdf.save());

      _showSnackBar('Acta de conciliación guardada en PDF.');
      await _abrirPDF(file.path);
    } catch (e) {
      _showSnackBar('Error al generar acta de conciliación PDF: $e',
          isError: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (var ctrl in _inputControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }
}
