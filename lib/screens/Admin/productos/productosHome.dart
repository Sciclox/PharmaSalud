import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/screens/Admin/productos/editar.dart';
import 'package:pharma_salud/screens/Admin/productos/registrar.dart';
import 'package:pharma_salud/screens/Admin/productos/ajuste_rapido.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pharma_salud/database/dbf_migrator.dart';

class ProductoScreen extends StatefulWidget {
  const ProductoScreen({super.key});

  @override
  _ProductoScreenState createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  final FechaVencimientoRepository _fechaVencimientoRepository =
      FechaVencimientoRepository();
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _sortAscending = true;
  String? _sortColumn;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    _productos = await _productoRepository.getAllProductos();
    
    if (_searchController.text.isNotEmpty) {
      _filterProductos(_searchController.text);
    } else {
      _productosFiltrados = List.from(_productos);
      _applySort();
      setState(() {});
    }
  }

  void _applySort() {
    if (_sortColumn == null) return;

    _productosFiltrados.sort((a, b) {
      dynamic valA, valB;
      if (_sortColumn == 'STOCK') {
        valA = a['Cantidad_Total'] ?? 0;
        valB = b['Cantidad_Total'] ?? 0;
      } else {
        return 0;
      }

      return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
    });
  }

  void _filterProductos(String query) {
    _productosFiltrados = _productos
        .where((producto) =>
            (producto['Nombre_Producto']
                    ?.toLowerCase()
                    .contains(query.toLowerCase()) ??
                false) ||
            (producto['Codigo_Barra']
                    ?.toLowerCase()
                    .contains(query.toLowerCase()) ??
                false))
        .toList();

    _applySort();
    setState(() {});
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false; // Por defecto de mayor a menor para stock
      }
      _applySort();
    });
  }

  Future<void> _exportCsv() async {
    await _productoRepository.exportProductosToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text('Productos exportados a CSV exitosamente.')),
    );
  }

  Future<void> _exportEscasosCsv() async {
    await _productoRepository.exportarProductosStockBajoToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text('Productos exportados a CSV exitosamente.')),
    );
  }

  Future<void> _importCsv() async {
    _showLoadingDialog('Importando productos...');
    await _productoRepository.importProductosFromCSV();
    Navigator.of(context).pop(); // Cerrar el diálogo de carga
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text('Productos importados desde CSV exitosamente.')),
    );
    await _loadProductos();
  }

  Future<void> _deleteProducto(Map<String, dynamic> producto) async {
    final int id = producto['ID'];
    final int cantidadTotal = producto['Cantidad_Total'] ?? 0;
    final String nombre = producto['Nombre_Producto'] ?? 'Producto Eliminado';

    await _productoRepository.deleteProducto(id);
    await _fechaVencimientoRepository.deleteFechaVencimientoPorProductoId(id);

    if (cantidadTotal > 0) {
      final hoy = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final adminRealName = prefs.getString('adminName') ?? "Administrador";

      await KardexRepository().insertKardexEntry({
        'NOMBRE_PRODUCTO': nombre,
        'FECHA_MOVIMIENTO': "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')} ${hoy.hour.toString().padLeft(2, '0')}:${hoy.minute.toString().padLeft(2, '0')}:${hoy.second.toString().padLeft(2, '0')}",
        'TIPO_MOVIMIENTO': 'Eliminado',
        'CANTIDAD': cantidadTotal,
        'USUARIO': adminRealName,
        'STOCK_ANTERIOR': cantidadTotal,
        'STOCK_RESULTANTE': 0,
      });
    }

    await _loadProductos();
  }

  Future<void> _deleteAllProductos() async {
    _showLoadingDialog('Eliminando productos...');
    await _productoRepository.deleteAllProductos();
    await _fechaVencimientoRepository.deleteAllFechasVencimiento();
    Navigator.of(context).pop(); // Cerrar el diálogo de carga
    await _loadProductos();
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromARGB(0, 0, 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Por favor, espere un momento',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            // Header Minimalista Pharma
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
                          'Productos',
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
                        'Control técnico de inventario y existencias',
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
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const FormularioProducto(),
                    ).then((value) {
                      if (value == true) _loadProductos();
                    });
                  },
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('NUEVO PRODUCTO',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D1D1F),
                    side: BorderSide(
                        color: const Color(0xFF1D1D1F).withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Barra de Filtros y Herramientas
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyFocusWrapper(
                  bindings: {LogicalKeyboardKey.f1: _searchFocusNode},
                  actions: {LogicalKeyboardKey.escape: () => _searchController.clear()},
                  child: Container(
                    width: double.infinity,
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
                              hintText: 'Buscar por nombre o fórmula...',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _toolButton(Icons.upload_file_outlined, 'Importar', _importCsv),
                    const SizedBox(width: 8),
                    _toolButton(Icons.download_outlined, 'CSV', _exportCsv),
                    const SizedBox(width: 8),
                    _toolButton(
                        Icons.warning_amber_rounded, 'Escasos', _exportEscasosCsv),
                    const SizedBox(width: 8),
                    _toolButton(Icons.storage_outlined, 'DBF', _migrarDesdeDbf),
                    const SizedBox(width: 8),
                    _toolButton(Icons.delete_outline_rounded, 'Vaciar', () async {
                      if (await _showDeleteAllConfirmationDialog(context))
                        _deleteAllProductos();
                    }, isDestructive: true),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Cabecera de Datos Técnica
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 4, child: Center(child: _tableHeader('PRODUCTO'))),
                  Expanded(flex: 2, child: Center(child: _tableHeader('TIPO'))),
                  Expanded(
                    flex: 2,
                    child: _tableHeader(
                      'STOCK (C/U)',
                      isSortable: true,
                      onTap: () => _onSort('STOCK'),
                      isSorted: _sortColumn == 'STOCK',
                      ascending: _sortAscending,
                    ),
                  ),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('P. VENTA CAJA'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('P. BLÍSTER'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('P. VENTA UNIT.'))),
                  Expanded(
                      flex: 2, child: Center(child: _tableHeader('ACCIONES'))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de Productos (Data-Grid)
            Expanded(
              child: _productosFiltrados.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _productosFiltrados.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                      itemBuilder: (context, index) {
                        final producto = _productosFiltrados[index];
                        return _buildDataRow(producto, index);
                      },
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
            'Sin registros de inventario',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1D1D1F)),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba ajustando los filtros de búsqueda',
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
    final tipo = producto['Tipo_Producto'] ?? '--';
    final qtyTotal = producto['Cantidad_Total'] ?? 0;
    final qtyPres = producto['Cantidad_Presentacion'] ?? 1;
    final pUnidad = (producto['Precio_Unidad'] ?? 0.0).toDouble();
    final pCaja = (producto['Precio_Caja'] ?? 0.0).toDouble();
    final pBlister = (producto['Precio_Blister'] ?? 0.0).toDouble();
    final tieneBlister = (producto['Blister_SiNo'] ?? 0) == 1 || pBlister > 0;

    final stockMinimo = producto['Stock_Minimo'] ?? 0;
    final esCritico = qtyTotal <= stockMinimo;

    int stockCaja = (tipo == 'Caja') ? (qtyTotal / qtyPres).floor() : 0;
    int stockUnidad =
        (tipo == 'Caja') ? (qtyTotal % qtyPres) : qtyTotal.toInt();

    return Material(
      color: Colors.white,
      borderRadius: (index == 0 && _productosFiltrados.length == 1)
          ? BorderRadius.circular(12)
          : index == 0
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : index == _productosFiltrados.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AjusteRapidoModal(producto: producto),
          ).then((value) {
            if (value == true) _loadProductos();
          });
        },
        hoverColor: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: (index == 0 && _productosFiltrados.length == 1)
            ? BorderRadius.circular(12)
            : index == 0
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : index == _productosFiltrados.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                    : BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            producto['Nombre_Producto'] ?? 'N/A',
                            softWrap: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1D1D1F),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        if ((producto['ES_OCULTO'] ?? 0) == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5856D6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DISCRETO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5856D6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if ((producto['RECETA_MEDICA'] ?? 0) == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFF9500).withOpacity(0.35),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_late_outlined,
                                    size: 10, color: Color(0xFFD97706)),
                                SizedBox(width: 3),
                                Text(
                                  'RECETA MÉDICA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'SKU: PRD-${producto['ID'].toString().padLeft(4, '0')}',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF1D1D1F).withOpacity(0.3),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
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
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tipo == 'Caja') ...[
                      Text(
                        '$stockCaja',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: esCritico
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF1D1D1F),
                            fontFamily: 'Outfit'),
                      ),
                      Text(
                        ' / $stockUnidad',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: esCritico
                                ? const Color(0xFFFF3B30).withOpacity(0.5)
                                : const Color(0xFF1D1D1F).withOpacity(0.3),
                            fontFamily: 'Outfit'),
                      ),
                    ] else
                      Text(
                        '$stockUnidad',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: esCritico
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF1D1D1F),
                            fontFamily: 'Outfit'),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    tipo == 'Caja' ? 'S/ ${formatMoney(pCaja)}' : '--',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Outfit',
                      color: tipo == 'Caja'
                          ? const Color(0xFF1D1D1F)
                          : const Color(0xFF1D1D1F).withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    (tieneBlister && pBlister > 0)
                        ? 'S/ ${formatMoney(pBlister)}'
                        : '--',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Outfit',
                      color: (tieneBlister && pBlister > 0)
                          ? const Color(0xFF1D1D1F)
                          : const Color(0xFF1D1D1F).withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'S/ ${formatMoney(pUnidad)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1D1D1F),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionIcon(Icons.edit_outlined, () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            ProductoEditForm(productId: producto['ID']),
                      ).then((value) {
                        if (value == true) _loadProductos();
                      });
                    }),
                    const SizedBox(width: 8),
                    _actionIcon(Icons.delete_outline_rounded, () async {
                      if (await _showDeleteConfirmationDialog(context))
                        _deleteProducto(producto);
                    }, isDestructive: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String text,
      {bool isSortable = false,
      VoidCallback? onTap,
      bool isSorted = false,
      bool ascending = true}) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFF1D1D1F).withOpacity(0.02),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSorted
                    ? const Color(0xFF1D1D1F)
                    : const Color(0xFF1D1D1F).withOpacity(0.3),
                letterSpacing: 1.2,
                fontFamily: 'Outfit',
              ),
            ),
            if (isSortable) ...[
              const SizedBox(width: 4),
              Icon(
                isSorted
                    ? (ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 12,
                color: isSorted
                    ? const Color(0xFF1D1D1F)
                    : const Color(0xFF1D1D1F).withOpacity(0.2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: (isDestructive
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF1D1D1F))
                  .withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: (isDestructive
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF1D1D1F))
                    .withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: (isDestructive
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF1D1D1F))
                    .withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive
              ? const Color(0xFFFF3B30).withOpacity(0.7)
              : const Color(0xFF1D1D1F).withOpacity(0.4),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Alerta Estilo Pharma (Dark like VentasHome)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1D1F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          size: 48,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "¿Eliminar Producto?",
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
                        "Esta acción eliminará el registro de forma permanente",
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

                // Body con botones
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "No podrás recuperar los datos del inventario una vez confirmada la eliminación.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: const Color(0xFF1D1D1F).withOpacity(0.5),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide(
                                    color: const Color(0xFF1D1D1F)
                                        .withOpacity(0.1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'CANCELAR',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.4),
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'ELIMINAR',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
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
      },
    ).then((value) => value ?? false);
  }

  Future<bool> _showDeleteAllConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Crítico (Dark with Warning Icon)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1D1F),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFF3B30),
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "¡Acción Crítica!",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF3B30),
                          fontFamily: 'Outfit',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Eliminación total del inventario",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),

                // Body con botones
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "¿Estás completamente seguro? Esta operación borrará irremediablemente todos los productos registrados.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: Color(0xFF1D1D1F),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'SÍ, ELIMINAR TODO EL INVENTARIO',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'CANCELAR OPERACIÓN',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.4),
                                  letterSpacing: 1.1,
                                ),
                              ),
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
      },
    ).then((value) => value ?? false);
  }

  Future<void> _migrarDesdeDbf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dbf'],
    );
    if (result == null || result.paths.first == null) return;
    final filePath = result.paths.first!;

    _showLoadingDialog('Migrando productos desde DBF...');

    try {
      final migrados = await DbfMigrator.migrarProductosDesdeDbf(
        dbfFilePath: filePath,
        soloConStock: true,
        onProgress: (current, total, name) {
          // Actualizar mensaje del diálogo de carga
        },
      );

      if (mounted) Navigator.of(context).pop();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Migración completada'),
          content: Text('Se migraron $migrados productos correctamente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      await _loadProductos();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error de migración'),
          content: Text('Ocurrió un error: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }
}
