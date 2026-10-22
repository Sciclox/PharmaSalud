import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/carritoVentas.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeCargando.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class CartDialogSeleccionado {
  static Future<void> showCart(
    BuildContext context,
    Map<String, dynamic> producto,
    int userId,
    VoidCallback onProductoAgregado,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CartDialogWidget(
        producto: producto,
        userId: userId,
        onProductoAgregado: onProductoAgregado,
      ),
    );
  }
}

class CartDialogWidget extends StatefulWidget {
  final Map<String, dynamic> producto;
  final int userId;
  final VoidCallback onProductoAgregado;

  const CartDialogWidget({
    super.key,
    required this.producto,
    required this.userId,
    required this.onProductoAgregado,
  });

  @override
  State<CartDialogWidget> createState() => _CartDialogWidgetState();
}

class _CartDialogWidgetState extends State<CartDialogWidget> {
  String _selectedVentaType = 'Venta por unidad';
  int _cantidad = 1;
  int _stockDisponibleTotal = 0;
  int _unidadesEnCarrito = 0;
  late int _stock;
  late double _precioUnidad;
  late double _precioCaja;
  late double _precioBlister;
  late double _total;
  String _userName = '';
  bool _mostrarTodosVencimientos = false;

  final TextEditingController _cantidadController =
      TextEditingController(text: '1');
  final FocusNode _cantidadFocusNode = FocusNode();
  final FocusNode _dialogFocusNode = FocusNode();

  final CartItemRepository _cartItemRepository = CartItemRepository();
  final FechaVencimientoRepository _fechaVencimientoRepository =
      FechaVencimientoRepository();
  List<Map<String, dynamic>> _fechasVencimiento = [];

  @override
  void initState() {
    super.initState();
    _initializeValues();
    _loadFechasVencimiento();
    _loadUserName();
    _cargarStockDisponible();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cantidadFocusNode.requestFocus();
      _cantidadController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _cantidadController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _cantidadFocusNode.dispose();
    _dialogFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarStockDisponible() async {
    final unidades =
        await _cartItemRepository.getUnidadesEnCarritoDeProducto(
      widget.producto['ID'],
      widget.userId,
    );
    final int stockFisico =
        (widget.producto['Cantidad_Total'] as num?)?.toInt() ?? 0;
    final disponible = (stockFisico - unidades).clamp(0, stockFisico);
    if (mounted) {
      setState(() {
        _unidadesEnCarrito = unidades;
        _stockDisponibleTotal = disponible;
        _updateTotal();
      });
    }
  }

  Future<void> _loadUserName() async {
    _userName = await UsuarioRepository().getUserNameById(widget.userId);
    if (mounted) setState(() {});
  }

  void _loadFechasVencimiento() async {
    int productoId = widget.producto['ID'];
    _fechasVencimiento = await _fechaVencimientoRepository
        .getFechasVencimientoByProductoId(productoId);
    if (mounted) setState(() {});
  }

  void _initializeValues() {
    _selectedVentaType = 'Venta por unidad';
    _stockDisponibleTotal =
        (widget.producto['Cantidad_Total'] as num?)?.toInt() ?? 0;
    _stock = _stockDisponibleTotal;
    _precioUnidad =
        (widget.producto['Precio_Unidad'] as num?)?.toDouble() ?? 0.0;
    _precioCaja =
        (widget.producto['Precio_Caja'] as num?)?.toDouble() ?? 0.0;
    _precioBlister =
        (widget.producto['Precio_Blister'] as num?)?.toDouble() ?? 0.0;
    _updateTotal();
  }

  void _updateTotal() {
    setState(() {
      switch (_selectedVentaType) {
        case 'Venta por caja':
          final presCaja =
              (widget.producto['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
          _stock = (_stockDisponibleTotal / (presCaja > 0 ? presCaja : 1)).floor();
          _total = _precioCaja * _cantidad;
          break;
        case 'Venta por blister':
          final presBlister =
              (widget.producto['Cantidad_Presentacion_blister'] as num?)
                      ?.toInt() ??
                  1;
          _stock = (_stockDisponibleTotal /
                  (presBlister > 0 ? presBlister : 1))
              .floor();
          _total = _precioBlister * _cantidad;
          break;
        case 'Venta por unidad':
        default:
          _stock = _stockDisponibleTotal;
          _total = _precioUnidad * _cantidad;
      }

      if (_stock <= 0) {
        _cantidad = 0;
      } else if (_cantidad > _stock) {
        _cantidad = _stock;
      } else if (_cantidad <= 0 && _stock > 0) {
        _cantidad = 1;
      }

      // Sincronizar el texto del input si difiere
      final textValue = int.tryParse(_cantidadController.text);
      if (textValue != _cantidad) {
        _cantidadController.text = '$_cantidad';
        _cantidadController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _cantidadController.text.length,
        );
      }
    });
  }

  void _onCantidadChanged(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed == null || parsed <= 0) {
      if (_stock > 0) {
        setState(() {
          _cantidad = 1;
          _updateTotal();
        });
      }
      return;
    }

    final int target = parsed.clamp(1, _stock > 0 ? _stock : 1);
    setState(() {
      _cantidad = target;
      switch (_selectedVentaType) {
        case 'Venta por caja':
          _total = _precioCaja * _cantidad;
          break;
        case 'Venta por blister':
          _total = _precioBlister * _cantidad;
          break;
        case 'Venta por unidad':
        default:
          _total = _precioUnidad * _cantidad;
      }
    });
  }

  void _incrementCantidad() {
    if (_stock > 0 && _cantidad < _stock) {
      setState(() {
        _cantidad++;
        _cantidadController.text = '$_cantidad';
        _updateTotal();
      });
    }
  }

  void _decrementCantidad() {
    if (_cantidad > 1) {
      setState(() {
        _cantidad--;
        _cantidadController.text = '$_cantidad';
        _updateTotal();
      });
    }
  }

  void _setPresetCantidad(int preset) {
    if (_stock <= 0) return;
    int nueva;
    if (preset == -1) {
      // MÁXIMO
      nueva = _stock;
    } else {
      nueva = (_cantidad + preset).clamp(1, _stock);
    }
    setState(() {
      _cantidad = nueva;
      _cantidadController.text = '$_cantidad';
      _updateTotal();
    });
  }

  double _getPrecioActual() {
    switch (_selectedVentaType) {
      case 'Venta por caja':
        return _precioCaja;
      case 'Venta por blister':
        return _precioBlister;
      case 'Venta por unidad':
      default:
        return _precioUnidad;
    }
  }

  Future<void> _addToCart() async {
    if (_cantidad <= 0 || _stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('No hay stock disponible para agregar este producto.'),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const LoadingDialog(message: "Agregando producto al carrito..."),
      );

      final hoy = DateTime.now();
      final fechaIso =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')} ${hoy.hour.toString().padLeft(2, '0')}:${hoy.minute.toString().padLeft(2, '0')}:${hoy.second.toString().padLeft(2, '0')}";

      await _cartItemRepository.addItemToCart({
        'REGISTRO_VENTA_ID': 1,
        'PRODUCTO_ID': widget.producto['ID'],
        'CANTIDAD': _cantidad,
        'PRECIO_VENTA': _total,
        'FECHA': fechaIso,
        'TIPO_VENTA': _selectedVentaType,
        'ID_KARDEX': 0,
        'ID_USUARIO': widget.userId,
      });

      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra diálogo de carga
      widget.onProductoAgregado(); // Recarga carrito y lista
      Navigator.of(context).pop(); // Cierra el modal
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Cierra diálogo de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text('Error al agregar al carrito: $e'),
        ),
      );
    }
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_stock > 0 && _cantidad > 0) {
          _addToCart();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _dialogFocusNode,
      onKeyEvent: _onKey,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Cabecera Moderna Pharma
                _buildHeader(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Información Completa del Producto
                      _buildProductHeroSection(),
                      const SizedBox(height: 20),

                      // 3. Tarjetas Interactivas de Modalidad / Presentación
                      _buildModalidadesSection(),
                      const SizedBox(height: 20),

                      // 4. Selector de Cantidad con Presets Rápidos
                      _buildQuantitySection(),
                      const SizedBox(height: 20),

                      // 5. Panel de Disponibilidad y Desglose de Stock
                      _buildStockBreakdownSection(),

                      // 6. Alerta de Vencimiento y Lotes (si aplica)
                      if (_fechasVencimiento.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildFechasVencimientoCard(),
                      ],

                      const SizedBox(height: 24),

                      // 7. Resumen Financiero y Acciones
                      _buildFooterActions(),
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

  // ===================== WIDGETS DE COMPONENTES =====================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom:
              BorderSide(color: const Color(0xFF1D1D1F).withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_shopping_cart_rounded,
              color: Color(0xFFFF3B30),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurar Venta',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  'Dispensación de mostrador • Vendedor: $_userName',
                  style: TextStyle(
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                    fontSize: 11,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.4),
            tooltip: 'Cerrar (Esc)',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              hoverColor: const Color(0xFFF0F0F2),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.08)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeroSection() {
    final bool requiereReceta = (widget.producto['RECETA_MEDICA'] ?? 0) == 1;
    final bool esOculto = (widget.producto['ES_OCULTO'] ?? 0) == 1;
    final String codigoBarra =
        widget.producto['Codigo_Barra']?.toString() ?? '';
    final String prodId =
        widget.producto['ID']?.toString().padLeft(4, '0') ?? '0000';
    final String tipoOriginal =
        widget.producto['Tipo_Producto']?.toString() ?? 'Unidad';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFFFF3B30),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.producto['Nombre_Producto'] ?? 'Producto',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D1D1F),
                        fontFamily: 'Outfit',
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadgePill(
                          label: 'REF: PS-$prodId',
                          icon: Icons.tag_rounded,
                          color: const Color(0xFF1D1D1F),
                        ),
                        if (codigoBarra.isNotEmpty)
                          _buildBadgePill(
                            label: codigoBarra,
                            icon: Icons.qr_code_rounded,
                            color: const Color(0xFF1D1D1F),
                          ),
                        _buildBadgePill(
                          label: 'Tipo: $tipoOriginal',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF1D1D1F),
                        ),
                        if (requiereReceta)
                          _buildBadgePill(
                            label: 'RECETA MÉDICA',
                            icon: Icons.assignment_late_outlined,
                            color: const Color(0xFFD97706),
                            backgroundColor:
                                const Color(0xFFFF9500).withValues(alpha: 0.12),
                            borderColor:
                                const Color(0xFFFF9500).withValues(alpha: 0.35),
                          ),
                        if (esOculto)
                          _buildBadgePill(
                            label: 'DISCRETO',
                            icon: Icons.visibility_off_rounded,
                            color: const Color(0xFF5856D6),
                            backgroundColor:
                                const Color(0xFF5856D6).withValues(alpha: 0.12),
                            borderColor:
                                const Color(0xFF5856D6).withValues(alpha: 0.35),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (requiereReceta) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Medicamento controlado: Requiere receta médica verificada antes de dispensar.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadgePill({
    required String label,
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor ?? color.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalidadesSection() {
    final bool tieneCaja = widget.producto['Tipo_Producto'] == 'Caja';
    final bool tieneBlister = widget.producto['Blister_SiNo'] == 1;

    final int presCaja =
        (widget.producto['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
    final int presBlister =
        (widget.producto['Cantidad_Presentacion_blister'] as num?)?.toInt() ?? 1;

    final int stockCajas =
        (_stockDisponibleTotal / (presCaja > 0 ? presCaja : 1)).floor();
    final int stockBlisters =
        (_stockDisponibleTotal / (presBlister > 0 ? presBlister : 1)).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PRESENTACIÓN / MODALIDAD',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF86868B),
                letterSpacing: 1.1,
                fontFamily: 'Outfit',
              ),
            ),
            Text(
              'Precio Seleccionado: S/ ${formatMoney(_getPrecioActual())}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF3B30),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 1. Tarjeta Unidad
            Expanded(
              child: _buildModalityCard(
                title: 'Unidad',
                typeKey: 'Venta por unidad',
                price: _precioUnidad,
                subtitle: 'Venta suelta',
                stockDisp: '$_stockDisponibleTotal unid.',
                icon: Icons.medication_outlined,
                isSelected: _selectedVentaType == 'Venta por unidad',
                color: const Color(0xFF059669),
              ),
            ),

            // 2. Tarjeta Blíster (si aplica)
            if (tieneBlister) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildModalityCard(
                  title: 'Blíster',
                  typeKey: 'Venta por blister',
                  price: _precioBlister,
                  subtitle: '$presBlister unid/blíst.',
                  stockDisp: '$stockBlisters blíst.',
                  icon: Icons.grid_view_rounded,
                  isSelected: _selectedVentaType == 'Venta por blister',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],

            // 3. Tarjeta Caja (si aplica)
            if (tieneCaja) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _buildModalityCard(
                  title: 'Caja',
                  typeKey: 'Venta por caja',
                  price: _precioCaja,
                  subtitle: '$presCaja unid/caja',
                  stockDisp: '$stockCajas cajas',
                  icon: Icons.inventory_2_outlined,
                  isSelected: _selectedVentaType == 'Venta por caja',
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildModalityCard({
    required String title,
    required String typeKey,
    required double price,
    required String subtitle,
    required String stockDisp,
    required IconData icon,
    required bool isSelected,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedVentaType = typeKey;
          _cantidad = 1;
          _cantidadController.text = '1';
          _updateTotal();
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1D1D1F).withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 16, color: color)
                else
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : const Color(0xFF1D1D1F),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'S/ ${formatMoney(price)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                Text(
                  stockDisp,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : Colors.grey.shade600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    final bool canIncrease = _stock > 0 && _cantidad < _stock;
    final bool canDecrease = _cantidad > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANTIDAD A DESPACHAR',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF86868B),
            letterSpacing: 1.1,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Selector interactivo (+ / - / input directo)
            Expanded(
              flex: 4,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    _buildStepButton(
                      icon: Icons.remove_rounded,
                      onPressed: canDecrease ? _decrementCantidad : null,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _cantidadController,
                        focusNode: _cantidadFocusNode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onCantidadChanged,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          color: Color(0xFF1D1D1F),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    _buildStepButton(
                      icon: Icons.add_rounded,
                      onPressed: canIncrease ? _incrementCantidad : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Botones de presets rápidos
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  _buildPresetChip('+1', 1),
                  const SizedBox(width: 6),
                  _buildPresetChip('+5', 5),
                  const SizedBox(width: 6),
                  _buildPresetChip('+10', 10),
                  const SizedBox(width: 6),
                  _buildPresetChip('MÁX', -1, isSpecial: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: disabled
                ? Colors.grey.shade400
                : const Color(0xFF1D1D1F),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, int value, {bool isSpecial = false}) {
    return Expanded(
      child: InkWell(
        onTap: () => _setPresetCantidad(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSpecial
                ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSpecial
                  ? const Color(0xFFFF3B30).withValues(alpha: 0.3)
                  : const Color(0xFF1D1D1F).withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSpecial ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F),
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBreakdownSection() {
    final int stockMinimo =
        (widget.producto['Stock_Minimo'] as num?)?.toInt() ?? 0;
    final bool isOutOfStock = _stockDisponibleTotal <= 0;
    final bool isLowStock =
        !isOutOfStock && _stockDisponibleTotal <= stockMinimo;

    final String tipoProducto =
        widget.producto['Tipo_Producto']?.toString() ?? 'Unidad';
    final int presCaja =
        (widget.producto['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;

    final int cajasCompletas =
        (_stockDisponibleTotal / (presCaja > 0 ? presCaja : 1)).floor();
    final int unidadesSueltas =
        _stockDisponibleTotal % (presCaja > 0 ? presCaja : 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOutOfStock
            ? const Color(0xFFFF3B30).withValues(alpha: 0.06)
            : isLowStock
                ? const Color(0xFFFF9500).withValues(alpha: 0.06)
                : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFFF3B30).withValues(alpha: 0.25)
              : isLowStock
                  ? const Color(0xFFFF9500).withValues(alpha: 0.3)
                  : const Color(0xFF1D1D1F).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.15)
                      : isLowStock
                          ? const Color(0xFFFF9500).withValues(alpha: 0.15)
                          : const Color(0xFF00C853).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOutOfStock
                      ? Icons.cancel_outlined
                      : isLowStock
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined,
                  size: 16,
                  color: isOutOfStock
                      ? const Color(0xFFFF3B30)
                      : isLowStock
                          ? const Color(0xFFD97706)
                          : const Color(0xFF00C853),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Stock disponible: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Text(
                          '$_stockDisponibleTotal unidades',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D1D1F),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    if (tipoProducto == 'Caja') ...[
                      const SizedBox(height: 2),
                      Text(
                        'Desglose: $cajasCompletas cajas + $unidadesSueltas unid. sueltas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D1D1F).withValues(alpha: 0.5),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? const Color(0xFFFF3B30)
                      : isLowStock
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOutOfStock
                      ? 'SIN STOCK'
                      : isLowStock
                          ? 'BAJO STOCK'
                          : 'DISPONIBLE',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          if (_unidadesEnCarrito > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 13, color: Color(0xFF5856D6)),
                  const SizedBox(width: 6),
                  Text(
                    'Tienes $_unidadesEnCarrito unidades ya agregadas en el carrito actual.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5856D6),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFechasVencimientoCard() {
    final proximo = _fechasVencimiento.first;
    DateTime? fechaVenc;
    try {
      fechaVenc = DateTime.parse(proximo['Fecha_Vencimiento']);
    } catch (e) {
      fechaVenc = DateFormat('dd/MM/yyyy').parse(proximo['Fecha_Vencimiento']);
    }

    final int dias = fechaVenc.difference(DateTime.now()).inDays;
    final bool isExpired = dias <= 0;
    final String fechaLabel = DateFormat('dd/MM/yyyy').format(fechaVenc);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isExpired
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  size: 16,
                  color: isExpired
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF00C853),
                ),
                const SizedBox(width: 8),
                Text(
                  'Próximo vencimiento: ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.55),
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  fechaLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D1D1F),
                    fontFamily: 'Outfit',
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.1)
                        : const Color(0xFF00C853).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExpired ? 'VENCIDO' : 'En $dias días',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isExpired
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF00C853),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                if (_fechasVencimiento.length > 1) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _mostrarTodosVencimientos = !_mostrarTodosVencimientos;
                      });
                    },
                    child: Icon(
                      _mostrarTodosVencimientos
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_mostrarTodosVencimientos && _fechasVencimiento.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ..._fechasVencimiento.skip(1).map((f) {
                    DateTime? fDate;
                    try {
                      fDate = DateTime.parse(f['Fecha_Vencimiento']);
                    } catch (e) {
                      fDate = DateFormat('dd/MM/yyyy')
                          .parse(f['Fecha_Vencimiento']);
                    }
                    final int d = fDate.difference(DateTime.now()).inDays;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(fDate),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            'Stock: ${f['Cantidad']} unid. (en $d días)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: const Color(0xFF1D1D1F)
                                  .withValues(alpha: 0.5),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    final double precioUnit = _getPrecioActual();
    final bool canAdd = _stock > 0 && _cantidad > 0;

    return Column(
      children: [
        // Cuadro de Resumen Económico
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total a pagar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1D1D1F),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'S/ ${formatMoney(precioUnit)}  ×  $_cantidad ${_selectedVentaType.replaceFirst('Venta por ', '')}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: const Color(0xFF1D1D1F).withValues(alpha: 0.5),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              Text(
                'S/ ${formatMoney(_total)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3B30),
                  fontFamily: 'Outfit',
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Botones de Acción
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D1D1F),
                  side: BorderSide(
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: canAdd ? _addToCart : null,
                icon: const Icon(Icons.add_shopping_cart_rounded,
                    size: 18, color: Colors.white),
                label: const Text(
                  'AÑADIR AL CARRITO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  disabledBackgroundColor:
                      const Color(0xFFFF3B30).withValues(alpha: 0.3),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
