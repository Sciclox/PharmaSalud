import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class EditarProductoDialog extends StatefulWidget {
  final int productoId;
  final String nombreProducto;
  final String tipoVentaActual;
  final int cantidadActual;
  final Function(String nuevoTipoVenta, int nuevaCantidad, double nuevoTotal)
      onGuardar;

  const EditarProductoDialog({
    super.key,
    required this.productoId,
    required this.nombreProducto,
    required this.tipoVentaActual,
    required this.cantidadActual,
    required this.onGuardar,
  });

  @override
  State<EditarProductoDialog> createState() => _EditarProductoDialogState();
}

class _EditarProductoDialogState extends State<EditarProductoDialog> {
  late String _tipoVenta;
  late int _cantidad;
  late double _total;
  int _stock = 0;
  bool _cargando = true;
  Map<String, dynamic>? _producto;

  late double _precioUnidad;
  late double _precioCaja;
  late double _precioBlister;
  late int _presentacionCaja;
  late int _presentacionBlister;
  late int _cantidadTotal;

  @override
  void initState() {
    super.initState();
    _tipoVenta = widget.tipoVentaActual;
    _cantidad = widget.cantidadActual;
    _cargarDatosProducto();
  }

  Future<void> _cargarDatosProducto() async {
    final producto =
        await ProductoRepository().getProductoById(widget.productoId);

    setState(() {
      _producto = producto;
      _precioUnidad = producto?['Precio_Unidad'] ?? 0.0;
      _precioCaja = producto?['Precio_Caja'] ?? 0.0;
      _precioBlister = producto?['Precio_Blister'] ?? 0.0;
      _presentacionCaja = producto?['Cantidad_Presentacion'] ?? 1;
      _presentacionBlister = producto?['Cantidad_Presentacion_blister'] ?? 1;
      _cantidadTotal = producto?['Cantidad_Total'] ?? 0;

      _calcularTotalYStock();
      _cargando = false;
    });
  }

  void _calcularTotalYStock() {
    switch (_tipoVenta) {
      case 'Venta por caja':
        _stock =
            (_cantidadTotal / (_presentacionCaja > 0 ? _presentacionCaja : 1))
                .floor();
        _total = _precioCaja * _cantidad;
        break;
      case 'Venta por blister':
        _stock = (_cantidadTotal /
                (_presentacionBlister > 0 ? _presentacionBlister : 1))
            .floor();
        _total = _precioBlister * _cantidad;
        break;
      default:
        _stock = _cantidadTotal;
        _total = _precioUnidad * _cantidad;
    }
  }

  void _actualizarCantidad(int nuevaCantidad) {
    setState(() {
      _cantidad = nuevaCantidad;
      _calcularTotalYStock();
    });
  }

  void _actualizarTipoVenta(String? nuevoTipo) {
    if (nuevoTipo == null) return;
    setState(() {
      _tipoVenta = nuevoTipo;
      _cantidad = 1;
      _calcularTotalYStock();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> tiposVenta = ['Venta por unidad', 'Venta por caja'];
    if (!_cargando && (_producto?['Blister_SiNo'] ?? 0) == 1) {
      tiposVenta.add('Venta por blister');
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _cargando
            ? const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Estilo Pharma
                    _buildModernHeader(),

                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProductInfoSection(),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _buildQuantitySelector(),
                              ),
                              const SizedBox(width: 16),
                              if ((_producto?['Tipo_Producto'] ?? '') !=
                                  'Unidad')
                                Expanded(
                                  flex: 1,
                                  child: _buildVentaTypeDropdown(tiposVenta),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildStockAlert(),
                          const SizedBox(height: 32),
                          _buildSummaryAndActions(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1D1D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_document,
                color: Color(0xFFFF3B30), size: 18),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Modificar Selección',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.nombreProducto,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D1D1F),
            fontFamily: 'Outfit',
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AJUSTE DE PARÁMETROS DE VENTA',
          style: TextStyle(
            fontSize: 10,
            color: const Color(0xFF1D1D1F).withOpacity(0.4),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildVentaTypeDropdown(List<String> tiposVenta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MODALIDAD',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: CustomDropdown<String>(
            hintText: 'Seleccionar...',
            items: tiposVenta,
            initialItem: _tipoVenta,
            onChanged: _actualizarTipoVenta,
            decoration: CustomDropdownDecoration(
              closedFillColor: const Color(0xFFF5F5F7),
              expandedFillColor: Colors.white,
              closedBorder: Border.all(color: Colors.black.withOpacity(0.05)),
              closedBorderRadius: BorderRadius.circular(12),
              expandedBorderRadius: BorderRadius.circular(12),
              hintStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              headerStyle: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Color(0xFF1D1D1F),
                fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CANTIDAD',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(
                  Icons.remove_rounded,
                  _cantidad > 1
                      ? () => _actualizarCantidad(_cantidad - 1)
                      : null),
              Text(
                '$_cantidad',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Outfit'),
              ),
              _buildCircleButton(
                  Icons.add_rounded,
                  _cantidad < _stock
                      ? () => _actualizarCantidad(_cantidad + 1)
                      : null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback? onPressed) {
    final bool isDisabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: isDisabled ? Colors.grey.shade400 : const Color(0xFF1D1D1F),
          ),
        ),
      ),
    );
  }

  Widget _buildStockAlert() {
    final bool lowStock = _stock < 5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lowStock
            ? const Color(0xFFFF3B30).withOpacity(0.05)
            : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lowStock
              ? const Color(0xFFFF3B30).withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            lowStock ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: lowStock
                ? const Color(0xFFFF3B30)
                : const Color(0xFF1D1D1F).withOpacity(0.4),
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            'Stock disponible:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D1D1F).withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Text(
            '$_stock unidades',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color:
                  lowStock ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndActions() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            border:
                Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nuevo Importe',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F)),
              ),
              Text(
                'S/ ${formatMoney(_total)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF3B30),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _stock == 0
                    ? null
                    : () {
                        widget.onGuardar(_tipoVenta, _cantidad, _total);
                        Navigator.of(context).pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor:
                      const Color(0xFFFF3B30).withOpacity(0.3),
                ),
                child: const Text('GUARDAR CAMBIOS',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
