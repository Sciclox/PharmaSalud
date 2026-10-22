import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/utils/snackbar_manager.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';
import 'package:pharma_salud/screens/Vendedor/components/confirmarDevolucionDialog.dart';

class DetallesVentaWidget extends StatefulWidget {
  final int userId;
  final String userName;
  final VoidCallback onDevolucionSuccess;

  const DetallesVentaWidget({
    super.key,
    required this.userId,
    required this.userName,
    required this.onDevolucionSuccess,
  });
  @override
  _DetallesVentaWidgetState createState() => _DetallesVentaWidgetState();
}

class _DetallesVentaWidgetState extends State<DetallesVentaWidget>
    with SingleTickerProviderStateMixin {
  final RegistroVentasRepository _registroVentasRepository =
      RegistroVentasRepository();
  final ProductoRepository _productoRepo = ProductoRepository();
  final KardexRepository _kardexRepo = KardexRepository();
  final SobranteCajaRepository _sobranteRepo = SobranteCajaRepository();
  late Future<List<ProductoVenta>> _futureProductos;
  List<ProductoVenta> _todosLosProductos = [];
  List<ProductoVenta> _productosFiltrados = [];
  double _sobranteHoy = 0.0;
  bool _isProcessingReturn = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _soloDevolucion = false;
  bool _orderDescending = true;

  @override
  void initState() {
    super.initState();
    _futureProductos = _obtenerTodosLosProductos(widget.userId);

    _searchController.addListener(_aplicarFiltros);
  }

  void _aplicarFiltros() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      final list = _todosLosProductos.where((producto) {
        final matchesQuery = query.isEmpty ||
            producto.nombreProducto.toLowerCase().contains(query);
        final matchesDevolucion =
            !_soloDevolucion || producto.devolucion == 'Si';
        return matchesQuery && matchesDevolucion;
      }).toList();

      list.sort((a, b) {
        final dtA = DateTime.tryParse(a.fecha) ?? DateTime(1970);
        final dtB = DateTime.tryParse(b.fecha) ?? DateTime(1970);
        return _orderDescending ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
      });

      _productosFiltrados = list;
    });
  }

  void _toggleFiltroDevolucion() {
    setState(() => _soloDevolucion = !_soloDevolucion);
    _aplicarFiltros();
  }

  String _formatearFecha(String fechaStr) {
    try {
      DateTime dt = DateTime.parse(fechaStr);
      return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
    } catch (e) {
      return fechaStr;
    }
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

  Future<List<ProductoVenta>> _obtenerTodosLosProductos(int userId) async {
    final hoy = DateTime.now();
    String fechaHoy =
        "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
    final List<Map<String, dynamic>> maps = await _registroVentasRepository
        .obtenerDetallesVentasPorUsuarioConFecha(userId, fechaHoy);

    final sobranteList = await _sobranteRepo.obtenerSobrantesFiltrados(
      fecha: fechaHoy,
      usuarioId: userId,
      tipo: 'SOBRANTE',
    );
    _sobranteHoy = 0.0;
    for (final s in sobranteList) {
      _sobranteHoy += (s['MONTO'] as num).toDouble();
    }

    final productos =
        List.generate(maps.length, (i) => ProductoVenta.fromMap(maps[i]));

    productos.sort((a, b) {
      final dtA = DateTime.tryParse(a.fecha) ?? DateTime(1970);
      final dtB = DateTime.tryParse(b.fecha) ?? DateTime(1970);
      int cmp = dtB.compareTo(dtA);
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });

    _todosLosProductos = productos;
    _productosFiltrados = List.from(productos);
    return productos;
  }

  Future<void> _procesarDevolucion(ProductoVenta item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmarDevolucionDialog(
        nombreProducto: item.nombreProducto,
        cantidad: item.cantidad,
        tipoVenta: item.tipoVenta,
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingReturn = true);

    try {
      // 1. Obtener stock anterior del producto
      final productoMap = await _productoRepo.getProductoById(item.productoId);
      int stockAnterior = (productoMap?['Cantidad_Total'] as num?)?.toInt() ?? 0;

      int unidadesADevolver = item.cantidad;
      if (item.tipoVenta.contains('caja')) {
        unidadesADevolver = item.cantidad * item.cantidadPresentacion;
      } else if (item.tipoVenta.contains('blister')) {
        unidadesADevolver = item.cantidad * item.cantidadPresentacionBlister;
      }

      int stockResultante = stockAnterior + unidadesADevolver;

      // 2. Aumentar stock
      await _productoRepo.incrementarStock(item.productoId, unidadesADevolver);

      // 3. Insertar movimiento de ingreso por Devolución en KARDEX
      final hoy = DateTime.now();
      final fechaIso =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')} ${hoy.hour.toString().padLeft(2, '0')}:${hoy.minute.toString().padLeft(2, '0')}:${hoy.second.toString().padLeft(2, '0')}";

      Map<String, dynamic> kardexEntry = {
        'CANTIDAD': unidadesADevolver,
        'TIPO_MOVIMIENTO': 'Devolución (${item.tipoVenta})',
        'FECHA_MOVIMIENTO': fechaIso,
        'USUARIO': widget.userName.isNotEmpty ? widget.userName : 'Vendedor',
        'NOMBRE_PRODUCTO': item.nombreProducto,
        'STOCK_ANTERIOR': stockAnterior,
        'STOCK_RESULTANTE': stockResultante,
        'ID_DETALLE_VENTA': item.id,
      };
      await _kardexRepo.insertKardexEntry(kardexEntry);

      // 4. Marcar detalle como devuelto
      await _registroVentasRepository.marcarDetalleComoDevuelto(item.id);

      SnackbarManager.show(
        context,
        const SnackBar(
          content: Text('Devolución procesada exitosamente'),
          backgroundColor: Color(0xFF34C759),
        ),
      );

      setState(() {
        _futureProductos = _obtenerTodosLosProductos(widget.userId);
      });
      widget.onDevolucionSuccess();
    } catch (e) {
      SnackbarManager.show(
        context,
        SnackBar(content: Text('Error al procesar devolución: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingReturn = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductoVenta>>(
      future: _futureProductos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)));
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar los productos'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'Sin ventas hoy',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                      fontFamily: 'Outfit'),
                ),
              ],
            ),
          );
        } else {
          final productos = snapshot.data!;
          final double totalVendido = productos
              .where((item) => item.devolucion != 'Si')
              .fold(0.0, (sum, item) => sum + (item.precioVenta)) + _sobranteHoy;
          final double totalFisico = productos
              .where((item) => item.devolucion != 'Si' && (item.metodoPago == 'Física' || item.metodoPago == 'Efectivo'))
              .fold(0, (sum, item) => sum + (item.precioVenta));
          final double totalYape = productos
              .where((item) => item.devolucion != 'Si' && item.metodoPago == 'Yape')
              .fold(0, (sum, item) => sum + (item.precioVenta));
          final double totalTarjeta = productos
              .where((item) => item.devolucion != 'Si' && item.metodoPago == 'Tarjeta')
              .fold(0, (sum, item) => sum + (item.precioVenta));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado Enterprise Pharma
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded,
                            color: Color(0xFFFF3B30), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Registro del Día',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D1D1F).withOpacity(0.5),
                            fontFamily: 'Outfit',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'S/ ${formatMoney(totalVendido)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF3B30),
                        fontFamily: 'Outfit',
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VENTA TOTAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D1D1F).withOpacity(0.3),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Filtro devolución y Resumen
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _soloDevolucion
                            ? const Color(0xFFFF9500).withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _soloDevolucion
                              ? const Color(0xFFFF9500).withOpacity(0.3)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: _toggleFiltroDevolucion,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_return_rounded,
                              size: 14,
                              color: _soloDevolucion
                                  ? const Color(0xFFFF9500)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _soloDevolucion ? 'DEVUELTOS' : 'TODOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _soloDevolucion
                                    ? const Color(0xFFFF9500)
                                    : Colors.grey.shade500,
                                letterSpacing: 0.5,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: InkWell(
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () async {
                          final hoy = DateTime.now();
                          final fechaHoy =
                              "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
                          final sobrantes =
                              await SobranteCajaRepository().obtenerSobrantesFiltrados(
                            fecha: fechaHoy,
                            usuarioId: widget.userId,
                            tipo: 'SOBRANTE',
                          );
                          double totalSobrante = 0.0;
                          for (final s in sobrantes) {
                            totalSobrante += (s['MONTO'] as num).toDouble();
                          }
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (context) => ResumenPagosDialog(
                              totalVendido: totalVendido,
                              totalFisico: totalFisico,
                              totalYape: totalYape,
                              totalTarjeta: totalTarjeta,
                              totalSobrante: totalSobrante,
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assessment_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 🔍 Buscador Estilo Pharma
              KeyFocusWrapper(
                bindings: {LogicalKeyboardKey.f2: _searchFocusNode},
                actions: {LogicalKeyboardKey.escape: () => _searchController.clear()},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1D1D1F)),
                    decoration: InputDecoration(
                      hintText: 'Filtrar transacciones hoy...',
                      hintStyle: TextStyle(
                          color: const Color(0xFF1D1D1F).withOpacity(0.3),
                          fontSize: 13),
                      prefixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_rounded,
                              color: const Color(0xFF1D1D1F).withOpacity(0.3),
                              size: 18),
                          const SizedBox(width: 6),
                          const F1Badge(label: 'F2'),
                          const SizedBox(width: 10),
                        ],
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Lista de Productos vendidos
              Expanded(
                child: ListView.builder(
                  itemCount: _productosFiltrados.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final producto = _productosFiltrados[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  producto.nombreProducto,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                      fontFamily: 'Outfit'),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final colorTipo = _getTipoVentaColor(producto.tipoVenta);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: colorTipo.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            producto.tipoVenta.toUpperCase(),
                                            style: TextStyle(
                                              color: colorTipo,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CANT: ${producto.cantidad}',
                                      style: TextStyle(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.3),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 10,
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.2)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatearFecha(producto.fecha),
                                      style: TextStyle(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.3),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'S/${formatMoney(producto.precioVenta)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Outfit'),
                              ),
                              const SizedBox(height: 8),
                              if (producto.devolucion == 'Si')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9500)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DEVUELTO',
                                    style: TextStyle(
                                      color: Color(0xFFFF9500),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else
                                IconButton(
                                  onPressed: _isProcessingReturn
                                      ? null
                                      : () => _procesarDevolucion(producto),
                                  icon: const Icon(
                                      Icons.assignment_return_rounded,
                                      color: Color(0xFFFF3B30),
                                      size: 18),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Devolución',
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF3B30)
                                        .withOpacity(0.05),
                                    padding: EdgeInsets.zero,
                                    enabledMouseCursor: SystemMouseCursors.click,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }
      },
    );
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
  final int productoId;
  final String devolucion;
  final int cantidadPresentacion;
  final int cantidadPresentacionBlister;
  final String metodoPago;

  ProductoVenta({
    required this.id,
    required this.registroVentaId,
    required this.nombreProducto,
    required this.cantidad,
    required this.tipoVenta,
    required this.precioVenta,
    required this.fecha,
    required this.productoId,
    required this.devolucion,
    required this.cantidadPresentacion,
    required this.cantidadPresentacionBlister,
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
      productoId: map['PRODUCTO_ID'],
      devolucion: map['DEVOLUCION'] ?? 'No',
      cantidadPresentacion: map['Cantidad_Presentacion'] ?? 1,
      cantidadPresentacionBlister: map['Cantidad_Presentacion_blister'] ?? 1,
      metodoPago: map['METODO_PAGO'] ?? 'Efectivo',
    );
  }
}

class ResumenPagosDialog extends StatelessWidget {
  final double totalVendido;
  final double totalFisico;
  final double totalYape;
  final double totalTarjeta;
  final double totalSobrante;

  const ResumenPagosDialog({
    super.key,
    required this.totalVendido,
    required this.totalFisico,
    required this.totalYape,
    required this.totalTarjeta,
    this.totalSobrante = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double totalConSobrante = totalVendido + totalSobrante;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header con degradado sutil
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
                    "Distribución de ingresos del día de hoy",
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
                  // Card Total
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

                  // Distribución de Medios de Pago
                  _buildMetodoRow(
                    label: "Efectivo",
                    amount: totalFisico,
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF34C759),
                  ),
                  const SizedBox(height: 12),
                  _buildMetodoRow(
                    label: "Yape",
                    amount: totalYape,
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF7D52F4),
                  ),
                  const SizedBox(height: 12),
                  _buildMetodoRow(
                    label: "Tarjeta",
                    amount: totalTarjeta,
                    icon: Icons.credit_card_rounded,
                    color: const Color(0xFF007AFF),
                  ),
                  const SizedBox(height: 12),
                  _buildMetodoRow(
                    label: "Sobrante de Caja",
                    amount: totalSobrante,
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFFE8920B),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botón Cerrar
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
    );
  }

  Widget _buildMetodoRow({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
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
}
