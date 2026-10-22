import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/carritoVentas.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeCargando.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeGuardado.dart';
import 'package:pharma_salud/screens/Vendedor/ventasHome.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class CarritoCompletoModal extends StatefulWidget {
  final int userId;
  final String userName;
  final String gender;
  final VoidCallback onRecargarTodo;

  const CarritoCompletoModal({
    super.key,
    required this.userId,
    required this.userName,
    required this.gender,
    required this.onRecargarTodo,
  });

  static Future<void> show(
    BuildContext context, {
    required int userId,
    required String userName,
    required String gender,
    required VoidCallback onRecargarTodo,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CarritoCompletoModal(
        userId: userId,
        userName: userName,
        gender: gender,
        onRecargarTodo: onRecargarTodo,
      ),
    );
  }

  @override
  State<CarritoCompletoModal> createState() => _CarritoCompletoModalState();
}

class _CarritoCompletoModalState extends State<CarritoCompletoModal> {
  final CartItemRepository _cartRepo = CartItemRepository();
  final ProductoRepository _productoRepo = ProductoRepository();
  final KardexRepository _kardexRepo = KardexRepository();
  final FechaVencimientoRepository _fechaRepo = FechaVencimientoRepository();
  final RegistroVentasRepository _registroRepo = RegistroVentasRepository();

  final TextEditingController _efectivoController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  String _metodoPago = 'Efectivo';
  double _vuelto = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarCarrito();
    _efectivoController.addListener(_calcularVuelto);
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCarrito() async {
    setState(() => _cargando = true);
    final items = await _cartRepo.getCartItems(widget.userId);
    if (mounted) {
      setState(() {
        _items = items;
        _cargando = false;
      });
      _calcularVuelto();
    }
  }

  double get _totalVenta {
    return _items.fold(0.0, (sum, item) => sum + (item['PRECIO_VENTA'] ?? 0.0));
  }

  void _calcularVuelto() {
    final double total = _totalVenta;
    final efectivo = double.tryParse(_efectivoController.text) ?? 0.0;
    setState(() {
      _vuelto = efectivo > 0 ? efectivo - total : 0.0;
    });
  }

  Color _getTipoVentaColor(String tipoVenta) {
    final tipo = tipoVenta.toLowerCase();
    if (tipo.contains('caja')) {
      return const Color(0xFFEA580C); // Naranja Caja
    } else if (tipo.contains('blister')) {
      return const Color(0xFF7C3AED); // Púrpura Blíster
    } else {
      return const Color(0xFF059669); // Verde Esmeralda Unidad
    }
  }

  double _getPrecioUnitario(Map<String, dynamic> item) {
    final tipoVenta = item['TIPO_VENTA'] ?? '';
    if (tipoVenta == 'Venta por caja') {
      final pCaja = (item['Precio_Caja'] as num?)?.toDouble() ?? 0.0;
      if (pCaja > 0) return pCaja;
    } else if (tipoVenta == 'Venta por blister') {
      final pBlister = (item['Precio_Blister'] as num?)?.toDouble() ?? 0.0;
      if (pBlister > 0) return pBlister;
    } else {
      final pUnid = (item['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
      if (pUnid > 0) return pUnid;
    }
    final int cant = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
    final double tot = (item['PRECIO_VENTA'] as num?)?.toDouble() ?? 0.0;
    return cant > 0 ? tot / cant : tot;
  }

  int _getStockMaximoDisponible(Map<String, dynamic> item) {
    final int stockTotalFisico = (item['Cantidad_Total'] as num?)?.toInt() ?? 0;
    final tipoVenta = item['TIPO_VENTA'] ?? '';
    if (tipoVenta == 'Venta por caja') {
      final int pres = (item['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
      return (stockTotalFisico / (pres > 0 ? pres : 1)).floor();
    } else if (tipoVenta == 'Venta por blister') {
      final int presB = (item['Cantidad_Presentacion_blister'] as num?)?.toInt() ?? 1;
      return (stockTotalFisico / (presB > 0 ? presB : 1)).floor();
    } else {
      return stockTotalFisico;
    }
  }

  Future<void> _modificarCantidad(Map<String, dynamic> item, int delta) async {
    final int cantidadActual = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
    final int nuevaCantidad = cantidadActual + delta;

    if (nuevaCantidad <= 0) {
      _confirmarEliminarItem(item);
      return;
    }

    final int maxStock = _getStockMaximoDisponible(item);
    if (nuevaCantidad > maxStock && delta > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock máximo alcanzado ($maxStock disponibles)'),
          backgroundColor: const Color(0xFF1D1D1F),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final double precioUnit = _getPrecioUnitario(item);
    final double nuevoTotal = precioUnit * nuevaCantidad;

    await _cartRepo.actualizarItemDelCarrito(
      item['ID'],
      tipoVenta: item['TIPO_VENTA'],
      cantidad: nuevaCantidad,
      precioVenta: nuevoTotal,
    );

    await _cargarCarrito();
    widget.onRecargarTodo();
  }

  Future<void> _confirmarEliminarItem(Map<String, dynamic> item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 22),
            SizedBox(width: 8),
            Text(
              'Eliminar del carrito',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '¿Desea quitar "${item['Nombre_Producto']}" del carrito?',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF1D1D1F)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(fontFamily: 'Outfit', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _cartRepo.removeItemFromCart(item['ID']);
      await _cargarCarrito();
      widget.onRecargarTodo();
    }
  }

  Future<void> _confirmarVaciarCarrito() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.remove_shopping_cart_outlined, color: Color(0xFFFF3B30), size: 22),
            SizedBox(width: 8),
            Text(
              'Vaciar carrito',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          '¿Está seguro de que desea retirar todos los productos del carrito actual?',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF1D1D1F)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(fontFamily: 'Outfit', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Vaciar Todo', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _cartRepo.clearCart(widget.userId);
      await _cargarCarrito();
      widget.onRecargarTodo();
    }
  }

  Future<void> _finalizarVenta() async {
    if (_items.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const LoadingDialog(message: 'Procesando venta...'),
      );

      final double total = _totalVenta;
      final usuarioId = widget.userId;
      final hoy = DateTime.now();
      final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(hoy);
      final pagoCon = _metodoPago == 'Efectivo'
          ? (double.tryParse(_efectivoController.text) ?? total)
          : total;
      final vuelto = _metodoPago == 'Efectivo' ? _vuelto : 0.0;

      final int registroVentaId = await _registroRepo.agregarRegistroVenta({
        'FECHA': fecha,
        'TOTAL': total,
        'PAGO_CON': pagoCon,
        'VUELTO': vuelto,
        'USUARIO_ID': usuarioId,
        'METODO_PAGO': _metodoPago,
      });

      for (var item in _items) {
        int detalleVentaId = await _registroRepo.agregarDetalleVenta({
          'REGISTRO_VENTA_ID': registroVentaId,
          'PRODUCTO_ID': item['PRODUCTO_ID'],
          'NOMBRE_PRODUCTO': item['Nombre_Producto'],
          'USUARIO_ID': usuarioId,
          'FECHA': fecha,
          'TIPO_VENTA': item['TIPO_VENTA'],
          'CANTIDAD': item['CANTIDAD'],
          'PRECIO_VENTA': item['PRECIO_VENTA'],
        });

        int cantidadUnidades = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
        if (item['TIPO_VENTA'] == 'Venta por caja') {
          cantidadUnidades = (cantidadUnidades * (item['Cantidad_Presentacion'] ?? 1)).toInt();
        } else if (item['TIPO_VENTA'] == 'Venta por blister') {
          cantidadUnidades = (cantidadUnidades * (item['Cantidad_Presentacion_blister'] ?? 1)).toInt();
        }

        final int productoId = (item['PRODUCTO_ID'] as num?)?.toInt() ?? 0;
        final prodActual = await _productoRepo.getProductoById(productoId);
        final int stockAnterior = (prodActual?['Cantidad_Total'] as num?)?.toInt() ?? 0;
        final int stockResultante = stockAnterior - cantidadUnidades;

        await _productoRepo.descontarCantidadTotal(productoId, cantidadUnidades);
        await _fechaRepo.restarCantidad(productoId, cantidadUnidades);

        Map<String, dynamic> kardexEntry = {
          'CANTIDAD': cantidadUnidades,
          'TIPO_MOVIMIENTO': item['TIPO_VENTA'],
          'FECHA_MOVIMIENTO': fecha,
          'USUARIO': widget.userName,
          'NOMBRE_PRODUCTO': item['Nombre_Producto'],
          'STOCK_ANTERIOR': stockAnterior,
          'STOCK_RESULTANTE': stockResultante,
          'ID_DETALLE_VENTA': detalleVentaId,
        };
        await _kardexRepo.insertKardexEntry(kardexEntry);
      }

      await _cartRepo.clearCart(widget.userId);

      // Cerrar diálogo de carga y modal completo
      if (mounted) {
        Navigator.of(context).pop(); // Cierra loading
        Navigator.of(context).pop(); // Cierra CarritoCompletoModal
      }

      // Reemplazar pantalla home para reset
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => VendedorScreen(
            userId: usuarioId,
            userName: widget.userName,
            gender: widget.gender,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

      await mostrarDialogoExito(
        context,
        _items,
        total,
        pagoCon,
        vuelto,
        ticketId: registroVentaId.toString(),
        vendedor: widget.userName,
        metodoPago: _metodoPago,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Cierra loading si está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la venta: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final modalWidth = (size.width * 0.88).clamp(850.0, 1150.0);
    final modalHeight = (size.height * 0.88).clamp(520.0, 780.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: modalWidth,
        height: modalHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFC),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
          border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.08)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
                      )
                    : _items.isEmpty
                        ? _buildEmptyState()
                        : _buildTable(),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFFFF3B30),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Carrito de Ventas',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1D1F),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      '${_items.length} ${_items.length == 1 ? "ÍTEM" : "ÍTEMS"}',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Revisión panorámica y liquidación de productos añadidos',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_items.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _confirmarVaciarCarrito,
              icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFFF3B30)),
              label: const Text(
                'VACIAR CARRITO',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B30),
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFFFF3B30).withValues(alpha: 0.25)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cerrar (ESC)',
            icon: const Icon(Icons.close_rounded, color: Color(0xFF1D1D1F), size: 22),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF5F5F7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'El carrito está vacío',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agregue productos para visualizar y liquidar el carrito aquí.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
            label: const Text(
              'AGREGAR PRODUCTOS (ESC)',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D1D1F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F5),
            border: Border(
              bottom: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
            ),
          ),
          child: Row(
            children: [
              _colHeader('#', 35),
              _colHeader('PRODUCTO', 320, isExpanded: true, textAlign: TextAlign.start),
              _colHeader('MODALIDAD', 120),
              _colHeader('STOCK DISP.', 100),
              _colHeader('PRECIO', 110),
              _colHeader('CANTIDAD', 140),
              _colHeader('SUBTOTAL', 110),
              _colHeader('ACCIÓN', 60),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.04),
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildTableRow(item, index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _colHeader(
    String title,
    double width, {
    bool isExpanded = false,
    TextAlign textAlign = TextAlign.center,
  }) {
    final text = Text(
      title,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D1D1F).withValues(alpha: 0.4),
        letterSpacing: 1,
      ),
    );
    if (isExpanded) {
      return Expanded(child: text);
    }
    return SizedBox(width: width, child: text);
  }

  Widget _buildTableRow(Map<String, dynamic> item, int index) {
    final String nombre = item['Nombre_Producto'] ?? 'Producto Desconocido';
    final String tipoVenta = item['TIPO_VENTA'] ?? 'Venta por unidad';
    final int cantidad = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
    final double precioVenta = (item['PRECIO_VENTA'] as num?)?.toDouble() ?? 0.0;
    final double precioUnit = _getPrecioUnitario(item);
    final int maxStock = _getStockMaximoDisponible(item);
    final bool esReceta = (item['RECETA_MEDICA'] ?? 0) == 1;
    final Color colorTipo = _getTipoVentaColor(tipoVenta);

    String tipoVentaDisplay = 'UNIDAD';
    if (tipoVenta.contains('caja')) tipoVentaDisplay = 'CAJA';
    if (tipoVenta.contains('blister')) tipoVentaDisplay = 'BLÍSTER';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 35,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.3),
              ),
            ),
          ),
          // Producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    ),
                    if (esReceta) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 10, color: Color(0xFFD97706)),
                            SizedBox(width: 3),
                            Text(
                              'RECETA MÉDICA',
                              style: TextStyle(
                                fontFamily: 'Outfit',
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
                const SizedBox(height: 2),
                Text(
                  'ID: #${item['PRODUCTO_ID']} • Presentación estándar',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          // Modalidad
          SizedBox(
            width: 120,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorTipo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorTipo.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Text(
                  tipoVentaDisplay,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: colorTipo,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          // Stock Disp.
          SizedBox(
            width: 100,
            child: Text(
              '$maxStock disp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: maxStock <= 5 ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F).withValues(alpha: 0.6),
              ),
            ),
          ),
          // P. Unitario
          SizedBox(
            width: 110,
            child: Text(
              'S/ ${formatMoney(precioUnit)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.7),
              ),
            ),
          ),
          // Cantidad (Steppers)
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _modificarCantidad(item, -1),
                ),
                Container(
                  width: 44,
                  alignment: Alignment.center,
                  child: Text(
                    '$cantidad',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ),
                _stepperButton(
                  icon: Icons.add_rounded,
                  onTap: () => _modificarCantidad(item, 1),
                  disabled: cantidad >= maxStock,
                ),
              ],
            ),
          ),
          // Subtotal
          SizedBox(
            width: 110,
            child: Text(
              'S/ ${formatMoney(precioVenta)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),
          // Acción (Eliminar)
          SizedBox(
            width: 60,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF3B30)),
                tooltip: 'Quitar producto',
                onPressed: () => _confirmarEliminarItem(item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF5F5F7) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.1)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14, color: disabled ? Colors.grey.shade300 : const Color(0xFF1D1D1F)),
        onPressed: disabled ? null : onTap,
      ),
    );
  }

  Widget _buildFooter() {
    final double total = _totalVenta;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFF1D1D1F).withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sección Izquierda: Método de Pago + Calculadora/Info alineados
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MÉTODO DE PAGO',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMetodoPagoSelector(),
                  const SizedBox(width: 12),
                  if (_metodoPago == 'Efectivo')
                    _buildCalculadoraSection(total)
                  else
                    _buildElectronicInfoSection(total),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Sección Derecha: Total a Liquidar + Botón Finalizar Venta
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.06)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL A LIQUIDAR',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                    letterSpacing: 1.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'S/ ${formatMoney(total)}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1D1D1F),
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _items.isNotEmpty ? _finalizarVenta : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 22),
                  SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FINALIZAR',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'VENTA',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoSelector() {
    final metodos = [
      {'name': 'Efectivo', 'icon': Icons.payments_rounded, 'color': const Color(0xFF34C759)},
      {'name': 'Yape', 'icon': Icons.qr_code_scanner_rounded, 'color': const Color(0xFF7D52F4)},
      {'name': 'Tarjeta', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF007AFF)},
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: metodos.map((m) {
          final isSel = _metodoPago == m['name'];
          final Color color = m['color'] as Color;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _metodoPago = m['name'] as String;
                  if (_metodoPago != 'Efectivo') _efectivoController.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m['icon'] as IconData,
                      size: 15,
                      color: isSel ? color : const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m['name'] as String,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        color: isSel ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F).withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalculadoraSection(double total) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_outlined, size: 15, color: Color(0xFF86868B)),
          const SizedBox(width: 6),
          Text(
            'PAGA CON:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _efectivoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty) return newValue;
                  if (RegExp(r'^\d*\.?\d{0,2}$').hasMatch(text)) {
                    return newValue;
                  }
                  return oldValue;
                }),
              ],
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1D1D1F),
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.25),
                ),
                prefixText: 'S/ ',
                prefixStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            height: 20,
            width: 1,
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          Text(
            'VUELTO:',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: _vuelto < 0 ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'S/ ${formatMoney(_vuelto)}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: _vuelto < 0 ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicInfoSection(double total) {
    final Color themeColor = _metodoPago == 'Yape' ? const Color(0xFF7D52F4) : const Color(0xFF007AFF);
    final IconData icon = _metodoPago == 'Yape' ? Icons.qr_code_scanner_rounded : Icons.credit_card_rounded;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: themeColor, size: 16),
          const SizedBox(width: 8),
          Text(
            'Pago exacto: ',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.65),
            ),
          ),
          Text(
            'S/ ${formatMoney(total)}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: themeColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'SIN VUELTO',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: themeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
