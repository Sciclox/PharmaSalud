import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:intl/intl.dart';

class AdminRegistroVentasWidget extends StatefulWidget {
  const AdminRegistroVentasWidget({super.key});

  @override
  _AdminRegistroVentasWidgetState createState() =>
      _AdminRegistroVentasWidgetState();
}

class _AdminRegistroVentasWidgetState extends State<AdminRegistroVentasWidget>
    with SingleTickerProviderStateMixin {
  final RegistroVentasRepository _registroVentasRepository =
      RegistroVentasRepository();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  List<ProductoVenta> _productosFiltrados = [];
  List<ProductoVenta> _productosMostrados = [];
  double _sobranteFiltrado = 0.0;
  bool _orderDescending = true;

  late AnimationController _fadeController;
  final TextEditingController _fechaInicialController =
      TextEditingController();
  final TextEditingController _filtroController = TextEditingController();
  final FocusNode _filtroFocusNode = FocusNode();
  List<Map<String, dynamic>> _usuarios = [];
  String? _usuarioSeleccionado;
  String _filtroTexto = "";
  String? _metodoPagoSeleccionado;
  String? _tipoVentaSeleccionado;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _productosFiltrados = [];
    _productosMostrados = [];

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final hoy = DateTime.now();
    _fechaInicialController.text =
        "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";

    _fechaInicialController.addListener(() {
      if (_fechaInicialController.text.length == 10) {
        _filtrarVentas();
      }
    });

    _obtenerUsuarios();
    // Cargar todas las ventas del día al iniciar
    _cargarVentasDelDia();
  }

  /// Carga todas las ventas del día (sin filtro de vendedor)
  Future<void> _cargarVentasDelDia() async {
    setState(() => _isLoading = true);

    String fecha = _fechaInicialController.text;
    String? fechaIso = _parseFecha(fecha);
    if (fechaIso == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final List<Map<String, dynamic>> maps = await _registroVentasRepository
          .obtenerDetallesVentasPorFecha(fechaIso);

      final sobrantesList = await SobranteCajaRepository().obtenerSobrantesFiltrados(
        fecha: fechaIso,
        tipo: 'SOBRANTE',
      );
      double sobranteSum = 0.0;
      for (final s in sobrantesList) {
        sobranteSum += (s['MONTO'] as num).toDouble();
      }

      setState(() {
        _sobranteFiltrado = sobranteSum;
        _productosFiltrados =
            List.generate(maps.length, (i) => ProductoVenta.fromMap(maps[i]));
        _aplicarFiltrosLocales();
      });
    } catch (e) {
      print("Error al cargar ventas del día: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Filtra ventas: si hay vendedor seleccionado filtra por vendedor + fecha,
  /// si no, carga todas las del día.
  Future<void> _filtrarVentas() async {
    if (_usuarioSeleccionado == null) {
      // Sin vendedor seleccionado, cargar todas las ventas del día
      _cargarVentasDelDia();
      return;
    }

    setState(() => _isLoading = true);

    int idUsuario = int.parse(_usuarioSeleccionado!);
    String fecha = _fechaInicialController.text;
    String? fechaIso = _parseFecha(fecha);
    if (fechaIso == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final List<Map<String, dynamic>> maps = await _registroVentasRepository
          .obtenerDetallesVentasPorUsuarioConFecha(idUsuario, fechaIso);

      final sobrantesList = await SobranteCajaRepository().obtenerSobrantesFiltrados(
        fecha: fechaIso,
        usuarioId: idUsuario,
        tipo: 'SOBRANTE',
      );
      double sobranteSum = 0.0;
      for (final s in sobrantesList) {
        sobranteSum += (s['MONTO'] as num).toDouble();
      }

      setState(() {
        _sobranteFiltrado = sobranteSum;
        _productosFiltrados =
            List.generate(maps.length, (i) => ProductoVenta.fromMap(maps[i]));
        _aplicarFiltrosLocales();
      });
    } catch (e) {
      print("Error al filtrar ventas: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Convierte la fecha de dd/mm/yyyy a yyyy-mm-dd. Retorna null si es inválida.
  String? _parseFecha(String fecha) {
    if (fecha.length == 10) {
      List<String> parts = fecha.split('/');
      if (parts.length == 3) {
        return "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    }
    return null;
  }

  Color _getTipoVentaColor(String tipoVenta) {
    final tipo = tipoVenta.toLowerCase();
    if (tipo.contains('caja')) {
      return const Color(0xFFEA580C); // Naranja elegante para Caja
    } else if (tipo.contains('blister')) {
      return const Color(0xFF7C3AED); // Púrpura/Violeta para Blíster
    } else {
      return const Color(0xFF059669); // Verde Esmeralda para Unidad
    }
  }

  void _aplicarFiltrosLocales() {
    setState(() {
      _productosMostrados = _productosFiltrados.where((producto) {
        // 1. Filtro por nombre
        final matchesNombre = producto.nombreProducto
            .toLowerCase()
            .contains(_filtroTexto.toLowerCase());

        // 2. Filtro por método de pago
        final String mp = (producto.metodoPago == 'Física') ? 'Efectivo' : producto.metodoPago;
        final matchesPago = _metodoPagoSeleccionado == null ||
            _metodoPagoSeleccionado == 'Todos' ||
            mp.toLowerCase() == _metodoPagoSeleccionado!.toLowerCase();

        // 3. Filtro por tipo de venta
        final matchesTipoVenta = _tipoVentaSeleccionado == null ||
            _tipoVentaSeleccionado == 'Todos' ||
            producto.tipoVenta.toLowerCase() == _tipoVentaSeleccionado!.toLowerCase();

        return matchesNombre && matchesPago && matchesTipoVenta;
      }).toList();

      _productosMostrados.sort((a, b) {
        final dtA = DateTime.tryParse(a.fecha) ?? DateTime(1970);
        final dtB = DateTime.tryParse(b.fecha) ?? DateTime(1970);
        return _orderDescending ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
      });
    });
  }

  void _filtrarPorNombre(String texto) {
    _filtroTexto = texto;
    _aplicarFiltrosLocales();
  }

  Future<void> _obtenerUsuarios() async {
    final usuarios = await _usuarioRepository.readUsuariosV02();
    setState(() {
      _usuarios = usuarios;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fechaInicialController.dispose();
    _filtroController.dispose();
    super.dispose();
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
            // Header Minimalista
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
                          'Registro de Ventas',
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
                        'Histórico y detalle de transacciones por vendedor',
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
                // Total Vendido Badge + VER RESUMEN + Ordenar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón Ver Resumen
                    InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: _mostrarResumenPagos,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assessment_rounded, size: 16, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              'VER RESUMEN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFF3B30).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TOTAL VENDIDO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF3B30).withOpacity(0.8),
                              letterSpacing: 1.1,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            'S/ ${formatMoney(_productosFiltrados.where((item) => item.devolucion != 'Si').fold(0.0, (sum, item) => sum + item.precioVenta) + _sobranteFiltrado)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B30),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Barra Unificada de Herramientas (Filtros + Búsqueda)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fila 1: Filtros dropdown y Fecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 1. Selector de Vendedor
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Vendedor',
                              style: TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: CustomDropdown<String>(
                                hintText: 'Seleccionar...',
                                items: _usuarios
                                    .map((u) => u['NOMBRE_USUARIO'] as String)
                                    .toList(),
                                initialItem: _usuarioSeleccionado == null
                                    ? null
                                    : _usuarios.firstWhere(
                                        (u) =>
                                            u['ID_USUARIO'].toString() ==
                                            _usuarioSeleccionado,
                                        orElse: () => {
                                              'NOMBRE_USUARIO': ''
                                            })['NOMBRE_USUARIO'],
                                onChanged: (value) {
                                  final user = _usuarios.firstWhere(
                                      (u) => u['NOMBRE_USUARIO'] == value);
                                  setState(() {
                                    _usuarioSeleccionado =
                                        user['ID_USUARIO'].toString();
                                  });
                                  _filtrarVentas();
                                },
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: const Color(0xFFF5F5F7),
                                  expandedFillColor: Colors.white,
                                  closedBorder: Border.all(
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.05)),
                                  closedBorderRadius: BorderRadius.circular(10),
                                  expandedBorderRadius: BorderRadius.circular(10),
                                  hintStyle: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  headerStyle: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: Color(0xFF1D1D1F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  listItemStyle: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Selector de Pago
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Pago',
                              style: TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: CustomDropdown<String>(
                                hintText: 'Todos',
                                items: const ['Todos', 'Efectivo', 'Yape', 'Tarjeta'],
                                initialItem: _metodoPagoSeleccionado ?? 'Todos',
                                onChanged: (value) {
                                  setState(() {
                                    _metodoPagoSeleccionado = (value == 'Todos') ? null : value;
                                  });
                                  _aplicarFiltrosLocales();
                                },
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: const Color(0xFFF5F5F7),
                                  expandedFillColor: Colors.white,
                                  closedBorder: Border.all(
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.05)),
                                  closedBorderRadius: BorderRadius.circular(10),
                                  expandedBorderRadius: BorderRadius.circular(10),
                                  hintStyle: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    headerStyle: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: Color(0xFF1D1D1F),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    listItemStyle: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: Color(0xFF1D1D1F),
                                    ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Selector de Tipo de Venta
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Tipo de Venta',
                              style: TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: CustomDropdown<String>(
                                hintText: 'Todos',
                                items: const ['Todos', 'Venta por unidad', 'Venta por caja', 'Venta por blister'],
                                initialItem: _tipoVentaSeleccionado ?? 'Todos',
                                onChanged: (value) {
                                  setState(() {
                                    _tipoVentaSeleccionado = (value == 'Todos') ? null : value;
                                  });
                                  _aplicarFiltrosLocales();
                                },
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: const Color(0xFFF5F5F7),
                                  expandedFillColor: Colors.white,
                                  closedBorder: Border.all(
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.05)),
                                  closedBorderRadius: BorderRadius.circular(10),
                                  expandedBorderRadius: BorderRadius.circular(10),
                                  hintStyle: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    headerStyle: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: Color(0xFF1D1D1F),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    listItemStyle: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 14,
                                      color: Color(0xFF1D1D1F),
                                    ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 2. Input de Fecha (Ancho Fijo)
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Fecha',
                              style: TextStyle(
                                color: Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _fechaInicialController,
                                readOnly: true,
                                mouseCursor: SystemMouseCursors.click,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/aaaa',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF1D1D1F).withOpacity(0.4),
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F5F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.05)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.05)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  suffixIcon: Icon(Icons.calendar_month_rounded,
                                      size: 16,
                                      color:
                                          const Color(0xFF1D1D1F).withOpacity(0.4)),
                                ),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1D1D1F)),
                                onTap: () async {
                                  final date = await showAppDatePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    _fechaInicialController.text = DateFormat('dd/MM/yyyy').format(date);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fila 2: Búsqueda y Limpieza
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 5. Búsqueda Local (Expanded)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Buscar en resultados',
                              style: TextStyle(
                                color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            KeyFocusWrapper(
                              bindings: {LogicalKeyboardKey.f1: _filtroFocusNode},
                              actions: {LogicalKeyboardKey.escape: () => _filtroController.clear()},
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          const Color(0xFF1D1D1F).withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.filter_list_rounded,
                                        color:
                                            const Color(0xFF1D1D1F).withOpacity(0.3),
                                        size: 18),
                                    const SizedBox(width: 8),
                                    const F1Badge(label: 'F1'),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _filtroController,
                                        focusNode: _filtroFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Filtrar por producto...',
                                          hintStyle: TextStyle(
                                            color: const Color(0xFF1D1D1F)
                                                .withOpacity(0.3),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: 'Outfit',
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Outfit',
                                            color: Color(0xFF1D1D1F)),
                                        onChanged: _filtrarPorNombre,
                                      ),
                                    ),
                                    if (_productosMostrados.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${_productosMostrados.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1D1D1F)
                                              .withOpacity(0.5),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 3. Botón de Limpiar Selección
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D1F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _usuarioSeleccionado = null;
                                _filtroController.clear();
                                _filtroTexto = "";
                                _metodoPagoSeleccionado = null;
                                _tipoVentaSeleccionado = null;
                              });
                              // Recargar todas las ventas del día
                              _cargarVentasDelDia();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cabecera de Tabla
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: _tableHeader('PRODUCTO', align: TextAlign.start)),
                  Expanded(
                      flex: 1, child: Center(child: _tableHeader('CANTIDAD'))),
                  Expanded(flex: 2, child: Center(child: _tableHeader('TIPO'))),
                  Expanded(
                      flex: 1, child: Center(child: _tableHeader('PAGO'))),
                  Expanded(
                      flex: 1, child: Center(child: _tableHeader('PRECIO'))),
                  Expanded(
                      flex: 2, child: Center(child: _tableHeader('FECHA'))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de Resultados
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : _productosMostrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded,
                                  size: 64,
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.1)),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin registros de venta',
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
                                    color: const Color(0xFF1D1D1F)
                                        .withOpacity(0.4)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _productosMostrados.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          itemBuilder: (context, index) {
                            final producto = _productosMostrados[index];
                            return Material(
                              color: Colors.white,
                              borderRadius: (index == 0 &&
                                      _productosMostrados.length == 1)
                                  ? BorderRadius.circular(12)
                                  : index == 0
                                      ? const BorderRadius.vertical(
                                          top: Radius.circular(12))
                                      : index == _productosMostrados.length - 1
                                          ? const BorderRadius.vertical(
                                              bottom: Radius.circular(12))
                                          : BorderRadius.zero,
                              child: InkWell(
                                onTap:
                                    () {}, // Accion opcional para habilitar hover
                                hoverColor:
                                    const Color(0xFFFF3B30).withOpacity(0.08),
                                borderRadius: (index == 0 &&
                                        _productosMostrados.length == 1)
                                    ? BorderRadius.circular(12)
                                    : index == 0
                                        ? const BorderRadius.vertical(
                                            top: Radius.circular(12))
                                        : index ==
                                                _productosMostrados.length - 1
                                            ? const BorderRadius.vertical(
                                                bottom: Radius.circular(12))
                                            : BorderRadius.zero,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          producto.nombreProducto,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF1D1D1F),
                                              fontFamily: 'Outfit'),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            producto.cantidad.toString(),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D1D1F),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  final colorTipo = _getTipoVentaColor(producto.tipoVenta);
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: colorTipo.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      producto.tipoVenta.toUpperCase(),
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                          color: colorTipo,
                                                          fontFamily: 'Outfit'),
                                                    ),
                                                  );
                                                },
                                              ),
                                              if (producto.devolucion == 'Si') ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF9500).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Devuelto',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFFF9500),
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Columna PAGO
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: _buildMetodoPagoBadge(producto.metodoPago),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'S/ ${formatMoney(producto.precioVenta)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1D1D1F),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Text(
                                            _formatFecha(producto.fecha),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: const Color(0xFF1D1D1F)
                                                    .withOpacity(0.5),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

  Widget _buildMetodoPagoBadge(String metodoPago) {
    final String label = (metodoPago == 'Física') ? 'Efectivo' : metodoPago;
    Color badgeColor;
    switch (label) {
      case 'Yape':
        badgeColor = const Color(0xFF7D52F4);
        break;
      case 'Tarjeta':
        badgeColor = const Color(0xFF007AFF);
        break;
      default:
        badgeColor = const Color(0xFF34C759);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Future<void> _mostrarResumenPagos() async {
    final activos = _productosFiltrados.where((p) => p.devolucion != 'Si');
    final double total = activos.fold(0.0, (sum, p) => sum + p.precioVenta);
    final double totalEfectivo = activos
        .where((p) => p.metodoPago == 'Física' || p.metodoPago == 'Efectivo')
        .fold(0.0, (sum, p) => sum + p.precioVenta);
    final double totalYape = activos
        .where((p) => p.metodoPago == 'Yape')
        .fold(0.0, (sum, p) => sum + p.precioVenta);
    final double totalTarjeta = activos
        .where((p) => p.metodoPago == 'Tarjeta')
        .fold(0.0, (sum, p) => sum + p.precioVenta);

    int? idUsuario =
        _usuarioSeleccionado != null ? int.tryParse(_usuarioSeleccionado!) : null;
    String fecha = _fechaInicialController.text;
    String? fechaIso = _parseFecha(fecha);

    final List<Map<String, dynamic>> sobrantesList =
        await SobranteCajaRepository().obtenerSobrantesFiltrados(
      fecha: fechaIso,
      usuarioId: idUsuario,
      tipo: 'SOBRANTE',
    );
    double totalSobrante = 0.0;
    for (final s in sobrantesList) {
      totalSobrante += (s['MONTO'] as num).toDouble();
    }

    final double totalConSobrante = total + totalSobrante;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D1D1F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Resumen de Pagos",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Outfit',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Distribución de ingresos del período filtrado",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
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
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "VENTA TOTAL",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B30),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            "S/ ${formatMoney(totalConSobrante)}",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF3B30),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildResumenRow("Efectivo", totalEfectivo, Icons.payments_rounded, const Color(0xFF34C759)),
                    const SizedBox(height: 12),
                    _buildResumenRow("Yape", totalYape, Icons.qr_code_scanner_rounded, const Color(0xFF7D52F4)),
                    const SizedBox(height: 12),
                    _buildResumenRow("Tarjeta", totalTarjeta, Icons.credit_card_rounded, const Color(0xFF007AFF)),
                    const SizedBox(height: 12),
                    _buildResumenRow("Sobrante de Caja", totalSobrante, Icons.account_balance_wallet_rounded, const Color(0xFFE8920B)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D1D1F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledMouseCursor: SystemMouseCursors.click,
                        ),
                        child: const Text(
                          "ENTENDIDO",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
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

  Widget _buildResumenRow(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D1D1F),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          Text(
            "S/ ${formatMoney(amount)}",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D1D1F),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.center}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D1D1F).withOpacity(0.3),
        letterSpacing: 1.2,
        fontFamily: 'Outfit',
      ),
    );
  }

  String _formatFecha(String fecha) {
    if (fecha.contains('-')) {
      try {
        DateTime parsed = DateTime.parse(fecha);
        return "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}";
      } catch (e) {
        return fecha;
      }
    }
    return fecha;
  }
}

class ProductoVenta {
  final int id;
  final int registroVentaId;
  final String nombreProducto;
  final int cantidad;
  final String tipoVenta;
  final double precioVenta;
  final String fecha;
  final String devolucion;
  final String metodoPago;

  ProductoVenta({
    required this.id,
    required this.registroVentaId,
    required this.nombreProducto,
    required this.cantidad,
    required this.tipoVenta,
    required this.precioVenta,
    required this.fecha,
    required this.devolucion,
    required this.metodoPago,
  });

  factory ProductoVenta.fromMap(Map<String, dynamic> map) {
    return ProductoVenta(
      id: map['ID'],
      registroVentaId: map['REGISTRO_VENTA_ID'],
      nombreProducto: map['NOMBRE_PRODUCTO'],
      cantidad: map['CANTIDAD'],
      tipoVenta: map['TIPO_VENTA'],
      precioVenta: map['PRECIO_VENTA'],
      fecha: map['FECHA'],
      devolucion: map['DEVOLUCION'] ?? 'No',
      metodoPago: map['METODO_PAGO'] ?? 'Efectivo',
    );
  }
}
