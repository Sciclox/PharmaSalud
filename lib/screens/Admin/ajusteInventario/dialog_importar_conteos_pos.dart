import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/conteo_inventario.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/screens/Admin/ajusteInventario/dialog_conteo_cruzado.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_historial_inventarios.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DialogImportarConteosPos extends StatefulWidget {
  final VoidCallback? onAjustesAplicados;

  const DialogImportarConteosPos({
    super.key,
    this.onAjustesAplicados,
  });

  @override
  State<DialogImportarConteosPos> createState() => _DialogImportarConteosPosState();
}

class _DialogImportarConteosPosState extends State<DialogImportarConteosPos> {
  final ConteoInventarioRepository _conteoRepo = ConteoInventarioRepository();
  final ProductoRepository _productoRepo = ProductoRepository();

  List<Map<String, dynamic>> _conteos = [];
  Map<int, int> _ventasPosteriores = {};
  Map<int, int> _stockActualMap = {};
  Set<int> _seleccionados = {};
  bool _cargando = true;

  // Filtros
  String _filtroModo = 'TODOS'; // 'TODOS', 'GLOBAL', 'INDIVIDUAL'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final lista = await _conteoRepo.obtenerConteosParaAdmin();

    final Map<int, int> ventasMap = {};
    final Map<int, int> stockMap = {};
    final Set<int> selSet = {};

    for (final item in lista) {
      final id = item['ID'] as int;
      final prodId = item['PRODUCTO_ID'] as int;
      final fechaHora = item['FECHA_HORA'] as String;

      final ventas = await _conteoRepo.obtenerVentasPosteriores(prodId, fechaHora);
      ventasMap[id] = ventas;

      final prodDb = await _productoRepo.getProductoById(prodId);
      stockMap[id] = (prodDb?['Cantidad_Total'] as num?)?.toInt() ??
          ((item['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);

      selSet.add(id);
    }

    if (mounted) {
      setState(() {
        _conteos = lista;
        _ventasPosteriores = ventasMap;
        _stockActualMap = stockMap;
        _seleccionados = selSet;
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _itemsFiltrados {
    List<Map<String, dynamic>> lista = _conteos;
    if (_filtroModo == 'GLOBAL') {
      lista = lista.where((c) => c['MODO'] == 'GLOBAL').toList();
    } else if (_filtroModo == 'INDIVIDUAL') {
      lista = lista.where((c) => c['MODO'] == 'INDIVIDUAL').toList();
    }

    if (_searchQuery.isNotEmpty) {
      lista = lista.where((c) {
        final nombre = (c['NOMBRE_PRODUCTO'] ?? '').toString().toLowerCase();
        final usuario = (c['NOMBRE_USUARIO'] ?? '').toString().toLowerCase();
        final id = c['PRODUCTO_ID']?.toString().toLowerCase() ?? '';
        return nombre.contains(_searchQuery) ||
            usuario.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }).toList();
    }

    return lista;
  }

  int get _totalSobrantes {
    int count = 0;
    for (final c in _itemsFiltrados) {
      final id = c['ID'] as int;
      final fis = (c['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
      final vPost = _ventasPosteriores[id] ?? 0;
      final fisReal = (fis - vPost).clamp(0, 999999);
      final stkAct = _stockActualMap[id] ?? ((c['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);
      if (fisReal - stkAct > 0) count++;
    }
    return count;
  }

  int get _totalFaltantes {
    int count = 0;
    for (final c in _itemsFiltrados) {
      final id = c['ID'] as int;
      final fis = (c['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
      final vPost = _ventasPosteriores[id] ?? 0;
      final fisReal = (fis - vPost).clamp(0, 999999);
      final stkAct = _stockActualMap[id] ?? ((c['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);
      if (fisReal - stkAct < 0) count++;
    }
    return count;
  }

  int get _totalConformes {
    int count = 0;
    for (final c in _itemsFiltrados) {
      final id = c['ID'] as int;
      final fis = (c['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
      final vPost = _ventasPosteriores[id] ?? 0;
      final fisReal = (fis - vPost).clamp(0, 999999);
      final stkAct = _stockActualMap[id] ?? ((c['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);
      if (fisReal - stkAct == 0) count++;
    }
    return count;
  }

  Future<void> _eliminarItem(Map<String, dynamic> item) async {
    final id = item['ID'] as int;
    final nombreProd = item['NOMBRE_PRODUCTO'] ?? 'este producto';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Descartar este reporte?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El conteo registrado para este producto se eliminará de la lista de pendientes y no se aplicará ningún ajuste.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF6B7280)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nombreProd,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text(
                        'Sí, descartar',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar == true) {
      await _conteoRepo.eliminarItemConteo(id);
      await _cargarDatos();
    }
  }

  /// Aprueba directamente y aplica el ajuste en stock y kardex sin pasos intermedios
  Future<void> _aprobarConteosDirecto(List<Map<String, dynamic>> itemsParaAprobar) async {
    if (itemsParaAprobar.isEmpty) return;

    int cantSobrantes = 0;
    int cantFaltantes = 0;
    int cantConformes = 0;

    for (final it in itemsParaAprobar) {
      final id = it['ID'] as int;
      final fis = (it['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
      final vPost = _ventasPosteriores[id] ?? 0;
      final fisReal = (fis - vPost).clamp(0, 999999);
      final stkAct = _stockActualMap[id] ?? ((it['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);
      final dif = fisReal - stkAct;
      if (dif > 0) {
        cantSobrantes++;
      } else if (dif < 0) {
        cantFaltantes++;
      } else {
        cantConformes++;
      }
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fact_check_rounded, color: Color(0xFF34C759), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                itemsParaAprobar.length == 1
                    ? '¿Aprobar ajuste de stock?'
                    : '¿Aprobar ${itemsParaAprobar.length} ajustes de stock?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El stock vivo de la botica se actualizará de inmediato al conteo físico real y se registrarán los movimientos en el Kardex.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    if (cantSobrantes > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sobrantes a incorporar:', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF007AFF))),
                          Text('$cantSobrantes prod.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                        ],
                      ),
                    if (cantFaltantes > 0) ...[
                      if (cantSobrantes > 0) const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Faltantes a descontar:', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFFF3B30))),
                          Text('$cantFaltantes prod.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30))),
                        ],
                      ),
                    ],
                    if (cantConformes > 0) ...[
                      if (cantSobrantes > 0 || cantFaltantes > 0) const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Conformes (sin descuadre):', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF34C759))),
                          Text('$cantConformes prod.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF34C759))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Sí, aprobar y aplicar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    final adminName = prefs.getString('adminName') ?? 'Administrador';

    if (!mounted) return;
    setState(() => _cargando = true);
    await _conteoRepo.aplicarAjustesAdmin(
      itemsParaAjustar: itemsParaAprobar,
      nombreAdmin: adminName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF34C759),
          content: Text(
            itemsParaAprobar.length == 1
                ? 'Stock ajustado y movimiento registrado en Kardex con éxito.'
                : '${itemsParaAprobar.length} ajustes aplicados y registrados en Kardex con éxito.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onAjustesAplicados?.call();
      await _cargarDatos();
      if (_conteos.isEmpty && mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatearFechaHora(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(fechaStr);
      return DateFormat('dd/MM/yyyy • hh:mm a').format(dt);
    } catch (_) {
      return fechaStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.92).clamp(940.0, 1120.0);
    final dialogHeight = (size.height * 0.88).clamp(540.0, 740.0);

    final items = _itemsFiltrados;
    final seleccionadosCount = _seleccionados.length;
    final todosSeleccionados = items.isNotEmpty && _seleccionados.length == items.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(),
              _buildToolbar(items, todosSeleccionados),
              Expanded(
                child: _buildTablaContenido(items),
              ),
              _buildFooter(items, seleccionadosCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalPendientes = _conteos.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Aprobación de Conteos Físicos',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: totalPendientes > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: totalPendientes > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '$totalPendientes pendientes',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: totalPendientes > 0 ? const Color(0xFF92400E) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Revisa las existencias físicas reportadas desde el POS y aprueba directamente el ajuste en el stock vivo',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  DialogConteoCruzado.show(
                    context,
                    onAjustesAplicados: () {
                      _cargarDatos();
                      widget.onAjustesAplicados?.call();
                    },
                  );
                },
                icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                label: const Text(
                  'Comparar Conteos',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ModalHistorialInventariosPOS.show(
                    context,
                    userName: 'Administrador',
                    esAdmin: true,
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text(
                  'Historial',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                tooltip: 'Cerrar diálogo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(List<Map<String, dynamic>> itemsFiltrados, bool todosSeleccionados) {
    final globalCount = _conteos.where((c) => c['MODO'] == 'GLOBAL').length;
    final indCount = _conteos.where((c) => c['MODO'] == 'INDIVIDUAL').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          // Selector de modalidad
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filtroSegmento('TODOS', 'Todos (${_conteos.length})'),
                _filtroSegmento('GLOBAL', 'Hoja Global ($globalCount)', icon: Icons.groups_outlined),
                _filtroSegmento('INDIVIDUAL', 'Por Turno ($indCount)', icon: Icons.person_outline_rounded),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Buscador de productos
          SizedBox(
            width: 230,
            height: 36,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Buscar por producto...',
                hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Chips de métricas de descuadre
          if (_totalSobrantes > 0) ...[
            _badgeDescuadre(
              icon: Icons.trending_up_rounded,
              label: '+$_totalSobrantes Sobrantes',
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
            ),
            const SizedBox(width: 8),
          ],
          if (_totalFaltantes > 0) ...[
            _badgeDescuadre(
              icon: Icons.trending_down_rounded,
              label: '-$_totalFaltantes Faltantes',
              color: const Color(0xFFDC2626),
              bgColor: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFECACA),
            ),
            const SizedBox(width: 8),
          ],
          if (_totalConformes > 0) ...[
            _badgeDescuadre(
              icon: Icons.check_circle_outline_rounded,
              label: '$_totalConformes Conformes',
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFBBF7D0),
            ),
            const SizedBox(width: 8),
          ],

          // Botón Seleccionar / Deseleccionar todos
          if (itemsFiltrados.isNotEmpty)
            InkWell(
              onTap: () {
                setState(() {
                  if (todosSeleccionados) {
                    _seleccionados.clear();
                  } else {
                    _seleccionados = itemsFiltrados.map((c) => c['ID'] as int).toSet();
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      todosSeleccionados ? Icons.deselect_rounded : Icons.select_all_rounded,
                      size: 15,
                      color: const Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      todosSeleccionados ? 'Deseleccionar' : 'Seleccionar todos',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filtroSegmento(String valor, String label, {IconData? icon}) {
    final activo = _filtroModo == valor;

    return GestureDetector(
      onTap: () {
        if (_filtroModo != valor) {
          setState(() => _filtroModo = valor);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: activo
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: activo ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeDescuadre({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaContenido(List<Map<String, dynamic>> items) {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF16A34A)),
            SizedBox(height: 14),
            Text(
              'Cargando conteos del POS...',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.task_alt_rounded, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No hay conteos pendientes',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Todos los reportes enviados desde el POS han sido revisados y procesados.',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Cabecera de la tabla
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 44),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'PRODUCTO Y REGISTRO',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ORIGEN / RESPONSABLE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'SISTEMA → FÍSICO',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Center(
                      child: Text(
                        'AJUSTE A APLICAR',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: Center(
                      child: Text(
                        'ACCIONES',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filas con scroll
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = item['ID'] as int;
                  final isSelected = _seleccionados.contains(id);

                  final conteoFisico = (item['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
                  final ventasPost = _ventasPosteriores[id] ?? 0;
                  final fisicoEnTienda = (conteoFisico - ventasPost).clamp(0, 999999);
                  final stockActualBd = _stockActualMap[id] ??
                      ((item['STOCK_SISTEMA'] as num?)?.toInt() ?? 0);
                  final diferenciaNeta = fisicoEnTienda - stockActualBd;

                  return _buildFilaProducto(
                    item: item,
                    id: id,
                    isSelected: isSelected,
                    stockActualBd: stockActualBd,
                    fisicoEnTienda: fisicoEnTienda,
                    ventasPost: ventasPost,
                    diferenciaNeta: diferenciaNeta,
                    isEven: index.isEven,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaProducto({
    required Map<String, dynamic> item,
    required int id,
    required bool isSelected,
    required int stockActualBd,
    required int fisicoEnTienda,
    required int ventasPost,
    required int diferenciaNeta,
    required bool isEven,
  }) {
    final nombre = item['NOMBRE_PRODUCTO'] ?? 'Producto #${item['PRODUCTO_ID']}';
    final prodId = item['PRODUCTO_ID']?.toString() ?? '';
    final modo = item['MODO'] ?? 'GLOBAL';
    final usuario = item['NOMBRE_USUARIO'] ?? 'Operador';
    final fecha = _formatearFechaHora(item['FECHA_HORA']);
    final presentacion = item['CANTIDAD_PRESENTACION']?.toString() ?? '1';

    Color difColor;
    Color difBg;
    Color difBorder;
    String difTexto;
    IconData difIcon;

    if (diferenciaNeta == 0) {
      difColor = const Color(0xFF16A34A);
      difBg = const Color(0xFFF0FDF4);
      difBorder = const Color(0xFFBBF7D0);
      difTexto = '0 Conforme';
      difIcon = Icons.check_circle_outline_rounded;
    } else if (diferenciaNeta > 0) {
      difColor = const Color(0xFF2563EB);
      difBg = const Color(0xFFEFF6FF);
      difBorder = const Color(0xFFBFDBFE);
      difTexto = '+$diferenciaNeta Sobrante';
      difIcon = Icons.trending_up_rounded;
    } else {
      difColor = const Color(0xFFDC2626);
      difBg = const Color(0xFFFEF2F2);
      difBorder = const Color(0xFFFECACA);
      difTexto = '$diferenciaNeta Faltante';
      difIcon = Icons.trending_down_rounded;
    }

    return Material(
      color: isSelected ? const Color(0xFFF0FDF4).withValues(alpha: 0.6) : (isEven ? Colors.white : const Color(0xFFFAFAFA)),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _seleccionados.remove(id);
            } else {
              _seleccionados.add(id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
                width: 3.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Checkbox de selección
              SizedBox(
                width: 44,
                child: Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _seleccionados.add(id);
                      } else {
                        _seleccionados.remove(id);
                      }
                    });
                  },
                ),
              ),

              // Columna 1: Producto y Registro
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'SKU: prd-${prodId.padLeft(4, '0')}',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  $fecha',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•  Pres.: $presentacion u.',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Columna 2: Origen / Responsable
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: modo == 'GLOBAL' ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: modo == 'GLOBAL' ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF),
                        ),
                      ),
                      child: Text(
                        modo == 'GLOBAL' ? 'GLOBAL' : 'INDIV.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: modo == 'GLOBAL' ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        usuario,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Columna 3: Sistema → Físico
              Expanded(
                flex: 2,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stock en sistema
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stockActualBd u.',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Text(
                            'Sistema',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFCBD5E1)),
                      ),

                      // Conteo Físico
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$fisicoEnTienda u.',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (ventasPost > 0)
                            Text(
                              '-$ventasPost ventas',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEA580C),
                              ),
                            )
                          else
                            const Text(
                              'Físico',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Columna 4: Ajuste a Aplicar
              SizedBox(
                width: 140,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: difBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: difBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(difIcon, size: 13, color: difColor),
                        const SizedBox(width: 5),
                        Text(
                          difTexto,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: difColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Columna 5: Acciones individuales
              SizedBox(
                width: 86,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón Aprobar solo este producto
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      color: const Color(0xFF16A34A),
                      tooltip: 'Aprobar solo este producto',
                      style: IconButton.styleFrom(
                        hoverColor: const Color(0xFFDCFCE7),
                        padding: const EdgeInsets.all(6),
                      ),
                      onPressed: () => _aprobarConteosDirecto([item]),
                    ),

                    // Botón Descartar reporte
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      color: const Color(0xFF94A3B8),
                      tooltip: 'Descartar reporte',
                      style: IconButton.styleFrom(
                        hoverColor: const Color(0xFFFEE2E2),
                        padding: const EdgeInsets.all(6),
                      ),
                      onPressed: () => _eliminarItem(item),
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

  Widget _buildFooter(List<Map<String, dynamic>> items, int seleccionadosCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Resumen de selección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: seleccionadosCount > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: seleccionadosCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$seleccionadosCount de ${items.length} productos seleccionados para ajuste',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Se aplicará el nuevo stock en la BD y se generará el movimiento de auditoría en el Kardex.',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Botones de acción
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: seleccionadosCount > 0
                    ? () {
                        final itemsSel = items.where((c) => _seleccionados.contains(c['ID'])).toList();
                        _aprobarConteosDirecto(itemsSel);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  disabledBackgroundColor: const Color(0xFF94A3B8).withValues(alpha: 0.3),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text(
                  'Aprobar y Aplicar al Stock ($seleccionadosCount)',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
