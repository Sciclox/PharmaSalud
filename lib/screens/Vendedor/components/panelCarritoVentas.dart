import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/carritoVentas.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/screens/Vendedor/components/editarProducto.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeCargando.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeGuardado.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_carrito_completo.dart';
import 'package:pharma_salud/screens/Vendedor/ventasHome.dart';

class PanelCarritoVentas extends StatefulWidget {
  final int userId;
  final String userName;
  final String gender;
  final VoidCallback onRecargar;
  final bool recargar;

  const PanelCarritoVentas({
    super.key,
    required this.userId,
    required this.userName,
    required this.gender,
    required this.onRecargar,
    required this.recargar,
  });

  @override
  State<PanelCarritoVentas> createState() => _PanelCarritoVentasState();
}

class _PanelCarritoVentasState extends State<PanelCarritoVentas> {
  late Future<List<Map<String, dynamic>>> _cartItemsFuture;

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

  @override
  void initState() {
    super.initState();
    _reloadCartItems();
  }

  @override
  void didUpdateWidget(covariant PanelCarritoVentas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recargar != widget.recargar) {
      _reloadCartItems();
    }
  }

  void _reloadCartItems() {
    setState(() {
      _cartItemsFuture = CartItemRepository().getCartItems(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: const Color.fromARGB(0, 255, 255, 255),
      child: SafeArea(
        child: _PanelCarritoVentasContent(
          userId: widget.userId,
          userName: widget.userName,
          gender: widget.gender,
          onRecargar: widget.onRecargar,
          onRecargarLista: _reloadCartItems,
          cartItemRepository: CartItemRepository(),
          kardexRepository: KardexRepository(),
          productoRepository: ProductoRepository(),
          fechaVencimientoRepository: FechaVencimientoRepository(),
          registroVentasRepository: RegistroVentasRepository(),
          cartItemsFuture: _cartItemsFuture,
        ),
      ),
    );
  }
}

class _PanelCarritoVentasContent extends StatefulWidget {
  final CartItemRepository cartItemRepository;
  final KardexRepository kardexRepository;
  final ProductoRepository productoRepository;
  final FechaVencimientoRepository fechaVencimientoRepository;
  final RegistroVentasRepository registroVentasRepository;
  final int userId;
  final String userName;
  final String gender;
  final VoidCallback onRecargar;
  final VoidCallback onRecargarLista;
  final Future<List<Map<String, dynamic>>> cartItemsFuture;

  const _PanelCarritoVentasContent({
    required this.cartItemRepository,
    required this.kardexRepository,
    required this.registroVentasRepository,
    required this.productoRepository,
    required this.fechaVencimientoRepository,
    required this.userId,
    required this.userName,
    required this.gender,
    required this.onRecargar,
    required this.onRecargarLista,
    required this.cartItemsFuture,
  });

  @override
  State<_PanelCarritoVentasContent> createState() =>
      _PanelCarritoVentasContentState();
}

class _PanelCarritoVentasContentState
    extends State<_PanelCarritoVentasContent> {
  final TextEditingController _efectivoController = TextEditingController();
  double _vuelto = 0.0;
  double _ultimoTotal = 0.0;
  String _metodoPago = 'Efectivo';

  Color _getTipoVentaColor(String tipoVenta) {
    final tipo = tipoVenta.toLowerCase();
    if (tipo.contains('caja')) {
      return const Color(0xFFEA580C);
    } else if (tipo.contains('blister')) {
      return const Color(0xFF7C3AED);
    } else {
      return const Color(0xFF059669);
    }
  }

  @override
  void initState() {
    super.initState();
    _efectivoController.addListener(_calcularVuelto);
  }

  @override
  void dispose() {
    _efectivoController.dispose();
    super.dispose();
  }

  void _calcularVuelto() {
    final efectivo = double.tryParse(_efectivoController.text) ?? 0.0;
    setState(() {
      _vuelto = efectivo > 0 ? efectivo - _ultimoTotal : 0.0;
    });
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

    await widget.cartItemRepository.actualizarItemDelCarrito(
      item['ID'],
      tipoVenta: item['TIPO_VENTA'],
      cantidad: nuevaCantidad,
      precioVenta: nuevoTotal,
    );

    widget.onRecargarLista();
    widget.onRecargar();
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
              'Eliminar producto',
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
      await widget.cartItemRepository.removeItemFromCart(item['ID']);
      widget.onRecargarLista();
      widget.onRecargar();
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
      await widget.cartItemRepository.clearCart(widget.userId);
      widget.onRecargarLista();
      widget.onRecargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.cartItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)));
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar el carrito.'));
        } else {
          final cartItems = snapshot.data!;
          double total = cartItems.fold(
              0.0, (sum, item) => sum + (item['PRECIO_VENTA'] ?? 0.0));

          if (_ultimoTotal != total) {
            _ultimoTotal = total;
            // Recalcular vuelto si el total cambia (ej. eliminar item)
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _calcularVuelto());
          }

          return Column(
            children: [
              // Encabezado Carrito Compacto & Elegante
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF1D1D1F).withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined,
                              color: Color(0xFFFF3B30), size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Carrito',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D1D1F),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cartItems.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (cartItems.isNotEmpty) ...[
                          IconButton(
                            icon: const Icon(Icons.open_in_full_rounded, size: 16),
                            tooltip: 'Ver carrito completo',
                            onPressed: () {
                              CarritoCompletoModal.show(
                                context,
                                userId: widget.userId,
                                userName: widget.userName,
                                gender: widget.gender,
                                onRecargarTodo: () {
                                  widget.onRecargarLista();
                                  widget.onRecargar();
                                },
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F5F7),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(28, 28),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFFF3B30)),
                            tooltip: 'Vaciar carrito',
                            onPressed: _confirmarVaciarCarrito,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                              padding: const EdgeInsets.all(6),
                              minimumSize: const Size(28, 28),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL A COBRAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF3B30).withOpacity(0.8),
                              letterSpacing: 1.1,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            'S/ ${formatMoney(total)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF3B30),
                              fontFamily: 'Outfit',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('El carrito está vacío',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontFamily: 'Outfit',
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: cartItems.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          return _buildCartItem(cartItems[index]);
                        },
                      ),
              ),
              const SizedBox(height: 10),
              _buildMetodoPagoSelector(),
              const SizedBox(height: 8),
              _metodoPago == 'Efectivo'
                  ? _buildCalculadoraPago(total)
                  : _buildElectronicPaymentInfo(total),
              const SizedBox(height: 10),
              // Botón Finalizar Venta Pharma
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: cartItems.isNotEmpty
                      ? () => _guardarVenta(context, total, cartItems)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledMouseCursor: SystemMouseCursors.click,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'FINALIZAR OPERACIÓN',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final tipo = (item['TIPO_VENTA'] ?? '').toString();
    final colorTipo = _getTipoVentaColor(tipo);
    final int cantidad = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
    final double precioVenta = (item['PRECIO_VENTA'] ?? 0.0).toDouble();
    final double precioUnit = _getPrecioUnitario(item);
    final int maxStock = _getStockMaximoDisponible(item);
    final bool esReceta = (item['RECETA_MEDICA'] ?? 0) == 1;

    String tipoAbrev = 'UNIDAD';
    if (tipo.toLowerCase().contains('caja')) tipoAbrev = 'CAJA';
    if (tipo.toLowerCase().contains('blister')) tipoAbrev = 'BLÍSTER';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Nombre del producto y botón de eliminar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item['Nombre_Producto'] ?? 'Producto Desconocido',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1D1D1F),
                    fontFamily: 'Outfit',
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                tooltip: 'Quitar',
                onPressed: () => _confirmarEliminarItem(item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila 2: Modalidad, Receta médica y Precio Unitario
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorTipo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: colorTipo.withOpacity(0.25), width: 0.5),
                ),
                child: Text(
                  tipoAbrev,
                  style: TextStyle(
                    color: colorTipo,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              if (esReceta) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.35),
                      width: 0.5,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_late_outlined,
                          size: 9, color: Color(0xFFD97706)),
                      SizedBox(width: 3),
                      Text(
                        'RECETA',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                'S/ ${formatMoney(precioUnit)} c/u',
                style: TextStyle(
                  color: const Color(0xFF1D1D1F).withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
              const Spacer(),
              // Botón de cambiar presentación
              InkWell(
                onTap: () => _abrirDialogoEditar(item),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Text(
                        'Presentación',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 3: Steppers de cantidad y Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Inline Stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _miniStepper(
                      icon: Icons.remove_rounded,
                      onTap: () => _modificarCantidad(item, -1),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      child: Text(
                        '$cantidad',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    _miniStepper(
                      icon: Icons.add_rounded,
                      onTap: () => _modificarCantidad(item, 1),
                      disabled: cantidad >= maxStock,
                    ),
                  ],
                ),
              ),
              // Subtotal
              Text(
                'S/ ${formatMoney(precioVenta)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF1D1D1F),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStepper({
    required IconData icon,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: disabled ? Colors.grey.shade300 : const Color(0xFF1D1D1F),
        ),
      ),
    );
  }

  Future<void> _guardarVenta(BuildContext context, double total,
      List<Map<String, dynamic>> cartItems) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingDialog(
            message: "Guardando la venta, por favor espere..."),
      );

      final usuarioId = widget.userId;
      final hoy = DateTime.now();
      final fecha = DateFormat('yyyy-MM-dd HH:mm:ss').format(hoy);
      final pagoCon = _metodoPago == 'Efectivo'
          ? (double.tryParse(_efectivoController.text) ?? 0.0)
          : total;
      final vuelto = _metodoPago == 'Efectivo' ? _vuelto : 0.0;

      int registroVentaId =
          await widget.registroVentasRepository.agregarRegistroVenta({
        'FECHA': fecha,
        'TOTAL': total,
        'PAGO_CON': pagoCon,
        'VUELTO': vuelto,
        'USUARIO_ID': usuarioId,
        'METODO_PAGO': _metodoPago,
      });

      for (var item in cartItems) {
        int detalleVentaId =
            await widget.registroVentasRepository.agregarDetalleVenta({
          'REGISTRO_VENTA_ID': registroVentaId,
          'PRODUCTO_ID': item['PRODUCTO_ID'],
          'NOMBRE_PRODUCTO': item['Nombre_Producto'],
          'USUARIO_ID': usuarioId,
          'FECHA': fecha,
          'TIPO_VENTA': item['TIPO_VENTA'],
          'CANTIDAD': item['CANTIDAD'],
          'PRECIO_VENTA': item['PRECIO_VENTA'],
        });

        // Calcular unidades físicas a descontar
        int cantidadUnidades = (item['CANTIDAD'] as num?)?.toInt() ?? 1;
        if (item['TIPO_VENTA'] == 'Venta por caja') {
          cantidadUnidades = (cantidadUnidades *
                  (item['Cantidad_Presentacion'] ?? 1))
              .toInt();
        } else if (item['TIPO_VENTA'] == 'Venta por blister') {
          cantidadUnidades = (cantidadUnidades *
                  (item['Cantidad_Presentacion_blister'] ?? 1))
              .toInt();
        }

        final int productoId = (item['PRODUCTO_ID'] as num?)?.toInt() ?? 0;

        // Obtener stock actual de la BD justo antes de descontar para secuencia cronológica perfecta
        final prodActual = await widget.productoRepository.getProductoById(productoId);
        final int stockAnterior = (prodActual?['Cantidad_Total'] as num?)?.toInt() ?? 0;
        final int stockResultante = stockAnterior - cantidadUnidades;

        // 1. Descontar existencias físicas en BD y lotes
        await widget.productoRepository.descontarCantidadTotal(productoId, cantidadUnidades);
        await widget.fechaVencimientoRepository.restarCantidad(productoId, cantidadUnidades);

        // 2. Registrar asiento oficial en KARDEX vinculado al detalle de venta
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
        await widget.kardexRepository.insertKardexEntry(kardexEntry);
      }

      await widget.cartItemRepository.clearCart(widget.userId);
      Navigator.of(context).pop();

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

      await mostrarDialogoExito(context, cartItems, total, pagoCon, vuelto,
          ticketId: registroVentaId.toString(),
          vendedor: widget.userName,
          metodoPago: _metodoPago);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 800),
              content: Text('Error: $e')));
    }
  }

  void _abrirDialogoEditar(Map<String, dynamic> item) async {
    showDialog(
      context: context,
      builder: (_) => EditarProductoDialog(
        productoId: item['PRODUCTO_ID'],
        nombreProducto: item['Nombre_Producto'], // 👈 nuevo
        tipoVentaActual: item['TIPO_VENTA'],
        cantidadActual: item['CANTIDAD'],
        onGuardar: (nuevoTipo, nuevaCantidad, nuevoTotal) async {
          await _procesarActualizacionProducto(
              item, nuevoTipo, nuevaCantidad, nuevoTotal);
        },
      ),
    );
  }

  Future<void> _procesarActualizacionProducto(Map<String, dynamic> item,
      String nuevoTipo, int nuevaCantidad, double nuevoTotal) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const LoadingDialog(message: "Actualizando producto..."),
      );

      // Actualizar únicamente el ítem del carrito (el inventario físico y Kardex no se tocan hasta finalizar la venta)
      await widget.cartItemRepository.actualizarItemDelCarrito(
        item['ID'],
        tipoVenta: nuevoTipo,
        cantidad: nuevaCantidad,
        precioVenta: nuevoTotal,
      );

      // Refrescar UI
      widget.onRecargarLista();
      widget.onRecargar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text('Error al editar: $e')),
      );
    } finally {
      Navigator.of(context).pop(); // cerrar el diálogo de carga
    }
  }

  Widget _buildCalculadoraPago(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF86868B)),
          const SizedBox(width: 6),
          Text(
            'PAGA CON:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _efectivoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'Outfit',
                color: Color(0xFF1D1D1F),
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.25),
                  fontSize: 14,
                ),
                prefixText: 'S/ ',
                prefixStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
            'VUELTO: ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _vuelto < 0
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF34C759),
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          Text(
            'S/ ${formatMoney(_vuelto)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _vuelto < 0
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF34C759),
              fontFamily: 'Outfit',
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoSelector() {
    final options = [
      {'name': 'Efectivo', 'icon': Icons.payments_rounded, 'color': const Color(0xFF34C759)},
      {'name': 'Yape', 'icon': Icons.qr_code_scanner_rounded, 'color': const Color(0xFF7D52F4)},
      {'name': 'Tarjeta', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF007AFF)},
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D1D1F).withValues(alpha: 0.05)),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _metodoPago == opt['name'];
          final color = opt['color'] as Color;
          return Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _metodoPago = opt['name'] as String;
                    if (_metodoPago != 'Efectivo') {
                      _efectivoController.clear();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        opt['icon'] as IconData,
                        color: isSelected ? color : const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        opt['name'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F).withValues(alpha: 0.55),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildElectronicPaymentInfo(double total) {
    final Color themeColor = _metodoPago == 'Yape' ? const Color(0xFF7D52F4) : const Color(0xFF007AFF);
    final IconData icon = _metodoPago == 'Yape' ? Icons.qr_code_scanner_rounded : Icons.credit_card_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pago exacto S/ ${formatMoney(total)} con $_metodoPago (sin vuelto)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: themeColor,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

