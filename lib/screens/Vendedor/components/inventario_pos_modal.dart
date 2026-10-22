import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/conteo_inventario.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_historial_inventarios.dart';

class InventarioPosModal extends StatefulWidget {
  final int userId;
  final String userName;

  const InventarioPosModal({
    super.key,
    required this.userId,
    required this.userName,
  });

  static Future<void> show(BuildContext context, {required int userId, required String userName}) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        barrierColor: Colors.black.withValues(alpha: 0.35),
        pageBuilder: (context, animation, secondaryAnimation) {
          return InventarioPosModal(userId: userId, userName: userName);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<InventarioPosModal> createState() => _InventarioPosModalState();
}

class _InventarioPosModalState extends State<InventarioPosModal> {
  final ConteoInventarioRepository _conteoRepo = ConteoInventarioRepository();
  final ProductoRepository _productoRepo = ProductoRepository();

  // Modo: 'GLOBAL' (Hoja Compartida) o 'INDIVIDUAL' (Mi Reporte de Turno)
  String _modoActual = 'GLOBAL';

  // Vista principal: 'CONTADOS' o 'PENDIENTES'
  String _vistaPrincipal = 'CONTADOS';

  // Filtro de lista de contados: 'TODOS', 'CONFORMES', 'DESCUADRES'
  String _filtroLista = 'TODOS';

  // Filtro buscador para la lista de pendientes
  final TextEditingController _filtroPendientesController = TextEditingController();
  String _filtroPendientesTexto = '';

  // Datos
  List<Map<String, dynamic>> _reporteVivo = [];
  List<Map<String, dynamic>> _todosLosProductos = [];
  bool _cargando = true;

  // Búsqueda y Selección
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _sugerencias = [];

  // Producto activo para contar
  Map<String, dynamic>? _productoSeleccionado;
  int _stockVivoSistema = 0;
  Map<String, dynamic>? _conteoPrevioProducto;
  final TextEditingController _conteoFisicoController = TextEditingController();
  final FocusNode _conteoFisicoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _cargarReporteVivo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _conteoFisicoController.dispose();
    _conteoFisicoFocusNode.dispose();
    _filtroPendientesController.dispose();
    super.dispose();
  }

  Future<void> _cargarReporteVivo() async {
    setState(() => _cargando = true);
    final itemsFuture = _conteoRepo.obtenerReporteVivo(
      modo: _modoActual,
      usuarioId: widget.userId,
    );
    final prodsFuture = _productoRepo.getAllProductos();
    final results = await Future.wait([itemsFuture, prodsFuture]);

    if (mounted) {
      setState(() {
        _reporteVivo = results[0];
        _todosLosProductos = results[1];
        _cargando = false;
      });
    }
  }

  Future<void> _cambiarModo(String nuevoModo) async {
    if (_modoActual == nuevoModo) return;
    setState(() {
      _modoActual = nuevoModo;
      _productoSeleccionado = null;
      _sugerencias = [];
      _searchController.clear();
    });
    await _cargarReporteVivo();
    _searchFocusNode.requestFocus();
  }

  Future<void> _buscarProductos(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() => _sugerencias = []);
      return;
    }

    final todos = _todosLosProductos.isNotEmpty ? _todosLosProductos : await _productoRepo.getAllProductos();
    final filtrados = todos.where((p) {
      final nombre = (p['Nombre_Producto'] ?? '').toString().toLowerCase();
      final barra = (p['Codigo_Barra'] ?? '').toString().toLowerCase();
      final sku = 'prd-${p['ID'].toString().padLeft(4, '0')}';
      return nombre.contains(cleanQuery.toLowerCase()) ||
          barra == cleanQuery.toLowerCase() ||
          sku.contains(cleanQuery.toLowerCase());
    }).take(8).toList();

    // Si coincide exactamente con un código de barra, seleccionarlo de inmediato
    final matchExacto = todos.where((p) =>
        (p['Codigo_Barra'] ?? '').toString().trim() == cleanQuery && cleanQuery.isNotEmpty).toList();

    if (mounted) {
      setState(() {
        _sugerencias = filtrados;
      });

      if (matchExacto.isNotEmpty) {
        _seleccionarProducto(matchExacto.first);
      }
    }
  }

  Future<void> _seleccionarProducto(Map<String, dynamic> prod) async {
    final int prodId = prod['ID'] as int;

    // Lectura en tiempo real del stock vivo para evitar desincronización por ventas
    final prodFresco = await _productoRepo.getProductoById(prodId);
    final stockVivo = (prodFresco?['Cantidad_Total'] as int?) ?? 0;

    // Verificar si ya fue contado en este borrador
    final previo = await _conteoRepo.obtenerConteoDeProducto(
      modo: _modoActual,
      productoId: prodId,
      usuarioId: widget.userId,
    );

    setState(() {
      _productoSeleccionado = prodFresco ?? prod;
      _stockVivoSistema = stockVivo;
      _conteoPrevioProducto = previo;
      _sugerencias = [];
      _searchController.clear();
      _conteoFisicoController.text = previo != null ? '${previo['CONTEO_FISICO']}' : '';
    });

    _conteoFisicoFocusNode.requestFocus();
  }

  Future<void> _registrarConteo({required int cantidadFisica}) async {
    if (_productoSeleccionado == null) return;

    final prod = _productoSeleccionado!;
    final prodId = prod['ID'] as int;
    final nombre = prod['Nombre_Producto'] ?? 'Producto Desconocido';
    final barra = prod['Codigo_Barra'] ?? '';
    final tipo = prod['Tipo_Producto'] ?? '--';
    final qtyPres = (prod['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
    final pUnidad = (prod['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
    final cUnidad = (prod['Costo_Unidad'] as num?)?.toDouble() ?? 0.0;

    // Volver a consultar stock vivo en el segundo exacto de la confirmación
    final prodVivo = await _productoRepo.getProductoById(prodId);
    final stockFinalSistema = (prodVivo?['Cantidad_Total'] as int?) ?? _stockVivoSistema;

    await _conteoRepo.registrarOActualizarConteo(
      modo: _modoActual,
      productoId: prodId,
      nombreProducto: nombre,
      codigoBarra: barra,
      tipoProducto: tipo,
      cantidadPresentacion: qtyPres,
      stockSistema: stockFinalSistema,
      conteoFisico: cantidadFisica,
      precioVenta: pUnidad,
      costoUnidad: cUnidad,
      usuarioId: widget.userId,
      nombreUsuario: widget.userName,
    );

    setState(() {
      _productoSeleccionado = null;
      _conteoPrevioProducto = null;
      _conteoFisicoController.clear();
    });

    await _cargarReporteVivo();
    _searchFocusNode.requestFocus();
  }

  /// Marcar conforme directamente desde la lista de pendientes (1 toque)
  Future<void> _marcarConformeDirecto(Map<String, dynamic> prod) async {
    final int prodId = prod['ID'] as int;
    final prodVivo = await _productoRepo.getProductoById(prodId);
    final stockVivo = (prodVivo?['Cantidad_Total'] as int?) ?? (prod['Cantidad_Total'] as int? ?? 0);

    await _conteoRepo.registrarOActualizarConteo(
      modo: _modoActual,
      productoId: prodId,
      nombreProducto: prod['Nombre_Producto'] ?? 'Producto Desconocido',
      codigoBarra: prod['Codigo_Barra'] ?? '',
      tipoProducto: prod['Tipo_Producto'] ?? '--',
      cantidadPresentacion: (prod['Cantidad_Presentacion'] as num?)?.toInt() ?? 1,
      stockSistema: stockVivo,
      conteoFisico: stockVivo,
      precioVenta: (prod['Precio_Unidad'] as num?)?.toDouble() ?? 0.0,
      costoUnidad: (prod['Costo_Unidad'] as num?)?.toDouble() ?? 0.0,
      usuarioId: widget.userId,
      nombreUsuario: widget.userName,
    );

    await _cargarReporteVivo();
  }

  Future<void> _eliminarItem(int idConteo) async {
    await _conteoRepo.eliminarItemConteo(idConteo);
    await _cargarReporteVivo();
  }

  Future<void> _limpiarBorrador() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restart_alt_rounded,
                  color: Color(0xFFFF3B30),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¿Reiniciar Conteo?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _modoActual == 'GLOBAL'
                    ? 'Estás a punto de borrar todos los conteos registrados en la hoja compartida de la botica.'
                    : 'Estás a punto de borrar los conteos que has registrado en tu turno actual.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Se descartarán los ${_reporteVivo.length} productos contados. Esta acción no se puede deshacer.',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Sí, Reiniciar',
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
      await _conteoRepo.limpiarBorrador(modo: _modoActual, usuarioId: widget.userId);
      await _cargarReporteVivo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Borrador de conteo reiniciado correctamente.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _enviarReporte() async {
    if (_reporteVivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos contados para enviar.')),
      );
      return;
    }

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFF34C759),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enviar Reporte al Admin',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se enviará el borrador de conteo con ${_reporteVivo.length} productos verificados al Administrador.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El stock vivo de la botica NO se modificará hasta que el Administrador revise y aplique el ajuste final.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
                        'Volver',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
                      ),
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
                      child: const Text(
                        'Confirmar y Enviar',
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
      await _conteoRepo.enviarReporte(modo: _modoActual, usuarioId: widget.userId);
      if (!mounted) return;
      await _cargarReporteVivo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF34C759),
          content: Text('Reporte de inventario enviado al Administrador con éxito.'),
          duration: Duration(seconds: 3),
        ),
      );
      ModalHistorialInventariosPOS.show(
        context,
        userId: widget.userId,
        userName: widget.userName,
      );
    }
  }

  // Cálculos estadísticos
  int get _totalProductos => _todosLosProductos.length;
  int get _totalContados => _reporteVivo.length;
  int get _totalPendientes => (_todosLosProductos.length - _totalContados).clamp(0, _todosLosProductos.length);
  int get _totalConformes => _reporteVivo.where((r) => (r['DIFERENCIA'] as int) == 0).length;
  int get _totalFaltantes => _reporteVivo.where((r) => (r['DIFERENCIA'] as int) < 0).length;
  int get _totalSobrantes => _reporteVivo.where((r) => (r['DIFERENCIA'] as int) > 0).length;

  List<Map<String, dynamic>> get _itemsFiltradosContados {
    if (_filtroLista == 'CONFORMES') {
      return _reporteVivo.where((r) => (r['DIFERENCIA'] as int) == 0).toList();
    } else if (_filtroLista == 'FALTANTES') {
      return _reporteVivo.where((r) => (r['DIFERENCIA'] as int) < 0).toList();
    } else if (_filtroLista == 'SOBRANTES') {
      return _reporteVivo.where((r) => (r['DIFERENCIA'] as int) > 0).toList();
    } else if (_filtroLista == 'DESCUADRES') {
      return _reporteVivo.where((r) => (r['DIFERENCIA'] as int) != 0).toList();
    }
    return _reporteVivo;
  }

  List<Map<String, dynamic>> get _productosPendientes {
    final contadosIds = _reporteVivo.map((r) => r['PRODUCTO_ID'] as int).toSet();
    final pendientes = _todosLosProductos.where((p) => !contadosIds.contains(p['ID'] as int)).toList();

    if (_filtroPendientesTexto.isNotEmpty) {
      final q = _filtroPendientesTexto.toLowerCase();
      return pendientes.where((p) {
        final nombre = (p['Nombre_Producto'] ?? '').toString().toLowerCase();
        final barra = (p['Codigo_Barra'] ?? '').toString().toLowerCase();
        final sku = 'prd-${p['ID'].toString().padLeft(4, '0')}';
        return nombre.contains(q) || barra.contains(q) || sku.contains(q);
      }).toList();
    }
    return pendientes;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F7),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    _buildStatsBar(),
                    const SizedBox(height: 14),
                    _buildActionZone(),
                    const SizedBox(height: 14),
                    _buildFilterTabs(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _vistaPrincipal == 'CONTADOS'
                          ? _buildReportTable()
                          : _buildPendientesTable(),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: Color(0xFFFF3B30), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toma de Inventario en Tiempo Real',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D1D1F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Verificación física de stock vivo • Operador: ${widget.userName}',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: const Color(0xFF1D1D1F).withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Selector de Modalidad (Global vs Individual)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _modeButton(
                      icon: Icons.groups_outlined,
                      label: 'Hoja Compartida (Global)',
                      selected: _modoActual == 'GLOBAL',
                      onTap: () => _cambiarModo('GLOBAL'),
                    ),
                    const SizedBox(width: 4),
                    _modeButton(
                      icon: Icons.person_outline_rounded,
                      label: 'Mi Reporte (Individual)',
                      selected: _modoActual == 'INDIVIDUAL',
                      onTap: () => _cambiarModo('INDIVIDUAL'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  ModalHistorialInventariosPOS.show(
                    context,
                    userId: widget.userId,
                    userName: widget.userName,
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text(
                  'Historial',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D1D1F),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F7),
                  foregroundColor: const Color(0xFF1D1D1F),
                ),
                tooltip: 'Cerrar y volver a ventas (Borrador guardado)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final textColor = selected ? const Color(0xFF1D1D1F) : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final porcentaje = _totalProductos > 0 ? (_totalContados / _totalProductos * 100) : 0.0;
    return Row(
      children: [
        _statCard('Total Botica', '$_totalProductos', Icons.storefront_outlined, const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        _statCard('Contados', '$_totalContados (${porcentaje.toStringAsFixed(1)}%)', Icons.task_alt_rounded, const Color(0xFF1D1D1F)),
        const SizedBox(width: 8),
        _statCard('Faltan Contar', '$_totalPendientes', Icons.hourglass_top_rounded, const Color(0xFFEA580C)),
        const SizedBox(width: 8),
        _statCard('Conformes', '$_totalConformes', Icons.check_circle_outline, const Color(0xFF34C759)),
        const SizedBox(width: 8),
        _statCard('Faltantes', '$_totalFaltantes', Icons.trending_down_rounded, const Color(0xFFFF3B30)),
        const SizedBox(width: 8),
        _statCard('Sobrantes', '$_totalSobrantes', Icons.trending_up_rounded, const Color(0xFF007AFF)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Color(0xFF6B7280))),
                  Text(
                    value,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _productoSeleccionado != null ? const Color(0xFFFF3B30).withValues(alpha: 0.4) : const Color(0xFFE5E7EB),
          width: _productoSeleccionado != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador / Escáner
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _buscarProductos,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: Color(0xFF1D1D1F),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Pistolear código de barra o escribir nombre / SKU para contar...',
                      hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFFF3B30), size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              if (_productoSeleccionado != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _productoSeleccionado = null;
                      _conteoPrevioProducto = null;
                      _conteoFisicoController.clear();
                    });
                    _searchFocusNode.requestFocus();
                  },
                  icon: const Icon(Icons.cancel_rounded, color: Colors.grey),
                  tooltip: 'Cancelar selección',
                ),
              ],
            ],
          ),

          // Sugerencias de búsqueda rápida
          if (_sugerencias.isNotEmpty && _productoSeleccionado == null) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (context, index) {
                  final p = _sugerencias[index];
                  final stock = p['Cantidad_Total'] ?? 0;
                  final barra = p['Codigo_Barra'] ?? '--';
                  return ListTile(
                    dense: true,
                    title: Text(
                      p['Nombre_Producto'] ?? '',
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Código: $barra • Tipo: ${p['Tipo_Producto']} • Presentación: ${p['Cantidad_Presentacion'] ?? 1} u.',
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.grey),
                    ),
                    trailing: Text(
                      'Stock Vivo: $stock u.',
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1D1D1F)),
                    ),
                    onTap: () => _seleccionarProducto(p),
                  );
                },
              ),
            ),
          ],

          // Panel de Conteo del Producto Seleccionado
          if (_productoSeleccionado != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productoSeleccionado!['Nombre_Producto'] ?? '',
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '${_productoSeleccionado!['Tipo_Producto']}'.toUpperCase(),
                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                              ),
                            ),
                            Text(
                              'Caja x ${_productoSeleccionado!['Cantidad_Presentacion'] ?? 1} unid.',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.grey[600]),
                            ),
                            if (_productoSeleccionado!['Codigo_Barra'] != null && _productoSeleccionado!['Codigo_Barra'].toString().isNotEmpty)
                              Text('• Barra: ${_productoSeleccionado!['Codigo_Barra']}', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                        if (_conteoPrevioProducto != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.info_outline, size: 14, color: Color(0xFF007AFF)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Ya contado en este borrador por ${_conteoPrevioProducto!['NOMBRE_USUARIO']} (${_conteoPrevioProducto!['CONTEO_FISICO']} u.). Al confirmar se actualizará.',
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Color(0xFF007AFF)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stock Vivo Sistema
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Column(
                      children: [
                        const Text('STOCK VIVO SISTEMA', style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                        Text('$_stockVivoSistema u.', style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Botón Rápido: Conforme (1 toque)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34C759),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _registrarConteo(cantidadFisica: _stockVivoSistema),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text('Conforme ($_stockVivoSistema)', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),

                  // Input para Descuadre (Cantidad Física Total)
                  SizedBox(
                    width: 110,
                    height: 44,
                    child: TextField(
                      controller: _conteoFisicoController,
                      focusNode: _conteoFisicoFocusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Físico u.',
                        hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null && parsed >= 0) {
                          _registrarConteo(cantidadFisica: parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D1D1F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final parsed = int.tryParse(_conteoFisicoController.text.trim());
                      if (parsed != null && parsed >= 0) {
                        _registrarConteo(cantidadFisica: parsed);
                      }
                    },
                    child: const Text('Guardar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Switch principal: Ya Contados vs Faltan Contar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _vistaTabButton(
                    id: 'CONTADOS',
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Ya Contados ($_totalContados)',
                    selected: _vistaPrincipal == 'CONTADOS',
                  ),
                  const SizedBox(width: 4),
                  _vistaTabButton(
                    id: 'PENDIENTES',
                    icon: Icons.pending_actions_rounded,
                    label: 'Faltan Contar ($_totalPendientes)',
                    selected: _vistaPrincipal == 'PENDIENTES',
                    badgeColor: _totalPendientes > 0 ? const Color(0xFFEA580C) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Subfiltros para cuando estamos en CONTADOS
            if (_vistaPrincipal == 'CONTADOS') ...[
              _filterChip('TODOS', 'Todos ($_totalContados)'),
              const SizedBox(width: 6),
              _filterChip('CONFORMES', 'Conformes ($_totalConformes)'),
              const SizedBox(width: 6),
              _filterChip('FALTANTES', 'Faltantes ($_totalFaltantes)'),
              const SizedBox(width: 6),
              _filterChip('SOBRANTES', 'Sobrantes ($_totalSobrantes)'),
            ],
          ],
        ),
        const SizedBox(width: 16),

        Flexible(
          child: Text(
            _vistaPrincipal == 'PENDIENTES'
                ? 'Mostrando productos que aún faltan verificar en este inventario'
                : (_modoActual == 'GLOBAL' ? 'Hoja consolidada de toda la botica' : 'Conteos registrados en tu turno'),
            style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _vistaTabButton({
    required String id,
    required String label,
    required bool selected,
    IconData? icon,
    Color? badgeColor,
  }) {
    final textColor = selected
        ? (badgeColor ?? const Color(0xFF1D1D1F))
        : (badgeColor?.withValues(alpha: 0.8) ?? const Color(0xFF6B7280));
    return InkWell(
      onTap: () => setState(() => _vistaPrincipal = id),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final selected = _filtroLista == id;
    return InkWell(
      onTap: () => setState(() => _filtroLista = id),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? const Color(0xFF1D1D1F) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildReportTable() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)));
    }

    if (_itemsFiltradosContados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              _reporteVivo.isEmpty
                  ? 'Aún no has registrado ningún producto.\nUsa el buscador o revisa la pestaña "Faltan Contar" para comenzar.'
                  : 'No hay productos con el filtro seleccionado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Cabecera
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF9FAFB),
              child: const Row(
                children: [
                  SizedBox(width: 60, child: Text('HORA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)))),
                  Expanded(flex: 4, child: Text('PRODUCTO', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)))),
                  Expanded(flex: 1, child: Center(child: Text('SIS.', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  Expanded(flex: 1, child: Center(child: Text('FÍSICO', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  Expanded(flex: 2, child: Center(child: Text('DIFERENCIA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  Expanded(flex: 2, child: Center(child: Text('VENDEDORA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Filas
            Expanded(
              child: ListView.separated(
                itemCount: _itemsFiltradosContados.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (context, index) {
                  final item = _itemsFiltradosContados[index];
                  final fechaHora = (item['FECHA_HORA'] as String? ?? '').split(' ');
                  final hora = fechaHora.length > 1 ? fechaHora[1].substring(0, 5) : '--:--';
                  final dif = (item['DIFERENCIA'] as num?)?.toInt() ?? 0;
                  final stockSis = (item['STOCK_SISTEMA'] as num?)?.toInt() ?? 0;
                  final conteoFis = (item['CONTEO_FISICO'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(hora, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Color(0xFF6B7280))),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['NOMBRE_PRODUCTO'] ?? '',
                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
                              ),
                              Text(
                                'Tipo: ${item['TIPO_PRODUCTO']} • Pres: ${item['CANTIDAD_PRESENTACION']} u.',
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text('$stockSis', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text('$conteoFis', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F))),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: _buildDiferenciaBadge(dif),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['NOMBRE_USUARIO'] ?? 'Vendedora',
                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            tooltip: 'Eliminar de reporte',
                            onPressed: () => _eliminarItem(item['ID'] as int),
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
    );
  }

  /// Tabla interactiva de productos que faltan contar
  Widget _buildPendientesTable() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)));
    }

    final pendientes = _productosPendientes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Barra de búsqueda dentro de pendientes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF9FAFB),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: TextField(
                        controller: _filtroPendientesController,
                        onChanged: (val) => setState(() => _filtroPendientesTexto = val.trim()),
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Filtrar pendientes por nombre, SKU o código de barra...',
                          hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey[400]),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 10, right: 6),
                            child: Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF6B7280)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          suffixIcon: _filtroPendientesTexto.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    _filtroPendientesController.clear();
                                    setState(() => _filtroPendientesTexto = '');
                                  },
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${pendientes.length} productos pendientes',
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Cabecera tabla pendientes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF9FAFB),
              child: const Row(
                children: [
                  Expanded(flex: 6, child: Text('PRODUCTO PENDIENTE', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)))),
                  Expanded(flex: 1, child: Center(child: Text('TIPO', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  Expanded(flex: 2, child: Center(child: Text('STOCK SISTEMA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                  Expanded(flex: 3, child: Center(child: Text('ACCIONES RÁPIDAS', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))))),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Lista de pendientes
            Expanded(
              child: pendientes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.celebration_rounded, size: 48, color: Color(0xFF34C759)),
                          const SizedBox(height: 10),
                          Text(
                            _filtroPendientesTexto.isNotEmpty
                                ? 'No se encontraron productos pendientes con ese filtro.'
                                : '¡Excelente trabajo! No queda ningún producto pendiente por contar en este inventario.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: pendientes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      itemBuilder: (context, index) {
                        final p = pendientes[index];
                        final stock = (p['Cantidad_Total'] as int?) ?? 0;
                        final barra = (p['Codigo_Barra'] ?? '').toString();
                        final tipo = (p['Tipo_Producto'] ?? '--').toString();
                        final qtyPres = (p['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['Nombre_Producto'] ?? '',
                                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
                                    ),
                                    Text(
                                      barra.isNotEmpty
                                          ? 'Presentación: Caja x $qtyPres u. • Barra: $barra'
                                          : 'Presentación: Caja x $qtyPres u.',
                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      tipo.toUpperCase(),
                                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    '$stock u.',
                                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF34C759),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _marcarConformeDirecto(p),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: Text('Conforme ($stock)', style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF1D1D1F),
                                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => _seleccionarProducto(p),
                                      child: const Text('Contar', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
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
    );
  }

  Widget _buildDiferenciaBadge(int dif) {
    if (dif == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: Color(0xFF34C759)),
            SizedBox(width: 4),
            Text('OK (Conforme)', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34C759))),
          ],
        ),
      );
    } else if (dif < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Faltan ${dif.abs()} u.',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF3B30)),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Sobran $dif u.',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)),
        ),
      );
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: _reporteVivo.isNotEmpty ? _limpiarBorrador : null,
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            label: const Text('Reiniciar Conteo', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Salir a Ventas', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: _reporteVivo.isNotEmpty ? _enviarReporte : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar Reporte al Admin', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
