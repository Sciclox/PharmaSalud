import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductoEditForm extends StatefulWidget {
  final int productId;
  const ProductoEditForm({super.key, required this.productId});

  @override
  _ProductoEditFormState createState() => _ProductoEditFormState();
}

class _ProductoEditFormState extends State<ProductoEditForm> {
  String tipoProducto = 'Unidad';
  bool hayBlister = false;
  bool esOculto = false;
  bool requiereReceta = false;
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final PageController _pageController = PageController();
  String? _stepError;

  // Listas de controladores para manejar dinámicamente las fechas y cantidades
  final List<TextEditingController> _fechaControllers = [];
  final List<TextEditingController> _cantidadControllers = [];

  final ProductoRepository _productoRepository = ProductoRepository();
  final FechaVencimientoRepository _fechaVencimientoRepository = FechaVencimientoRepository();
  final KardexRepository _kardexRepository = KardexRepository();
  bool isLoading = true;

  final nombreProductoController = TextEditingController();
  final nombreProductoFocusNode = FocusNode();
  final cantidadPresentacionController = TextEditingController();
  final cantidadPresentacionBlisterController = TextEditingController();
  final stockCajaController = TextEditingController();
  final stockUnidadController = TextEditingController();
  final precioUnidadController = TextEditingController();
  final precioCajaController = TextEditingController();
  final precioBlisterController = TextEditingController();
  final costoProductoController = TextEditingController();
  final stockMinimoController = TextEditingController();
  final codigoBarraController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductData();
    _loadFechasVencimiento();
  }

  Future<void> _loadProductData() async {
    try {
      var producto = await _productoRepository.getProductoById(widget.productId);
      if (producto != null) {
        nombreProductoController.text = producto['Nombre_Producto'] ?? '';
        cantidadPresentacionController.text = producto['Cantidad_Presentacion']?.toString() ?? '';

        final tipo = producto['Tipo_Producto'];
        final total = producto['Cantidad_Total'] ?? 0;
        final pres = producto['Cantidad_Presentacion'] ?? 1;

        stockCajaController.text = (tipo == 'Caja' ? (total / pres).floor() : 0).toString();
        stockUnidadController.text = (tipo == 'Caja' ? total % pres : total).toString();

        precioUnidadController.text = producto['Precio_Unidad']?.toString() ?? '';
        precioCajaController.text = producto['Precio_Caja']?.toString() ?? '';
        costoProductoController.text = (tipo == 'Caja' ? producto['Costo_Caja'] : producto['Costo_Unidad'])?.toString() ?? '';

        stockMinimoController.text = producto['Stock_Minimo']?.toString() ?? '';
        codigoBarraController.text = producto['Codigo_Barra'] ?? '';
        cantidadPresentacionBlisterController.text = producto['Cantidad_Presentacion_blister']?.toString() ?? '';
        precioBlisterController.text = producto['Precio_Blister']?.toString() ?? '';
        hayBlister = producto['Blister_SiNo'] == 1;
        esOculto = (producto['ES_OCULTO'] ?? 0) == 1;
        requiereReceta = (producto['RECETA_MEDICA'] ?? 0) == 1;
        tipoProducto = tipo;
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadFechasVencimiento() async {
    final fechas = await _fechaVencimientoRepository.getFechasVencimientoByProductoId(widget.productId);
    if (fechas.isNotEmpty) {
      _fechaControllers.clear();
      _cantidadControllers.clear();
      
      for (var f in fechas) {
        String d = f['Fecha_Vencimiento'];
        if (d.contains('-')) {
          try {
            DateTime p = DateTime.parse(d);
            d = "${p.day.toString().padLeft(2, '0')}/${p.month.toString().padLeft(2, '0')}/${p.year}";
          } catch (e) {}
        }
        _fechaControllers.add(TextEditingController()..text = d);
        _cantidadControllers.add(TextEditingController()..text = f['Cantidad'].toString());
      }
    }
    setState(() {});
  }

  Future<void> _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);
      try {
        final qtyPres = tipoProducto == 'Caja'
            ? (int.tryParse(cantidadPresentacionController.text) ?? 1)
            : 1;
        final sCaja = int.tryParse(stockCajaController.text) ?? 0;
        final sUnidad = int.tryParse(stockUnidadController.text) ?? 0;
        final costo = double.tryParse(costoProductoController.text) ?? 0.0;

        final prodAnt = await _productoRepository.getProductoById(widget.productId);
        final totalAnt = prodAnt?['Cantidad_Total'] ?? 0;

        final qtyTotal = tipoProducto == 'Caja' ? (sCaja * qtyPres) + sUnidad : sUnidad;

        final producto = {
          'ID': widget.productId,
          'Nombre_Producto': nombreProductoController.text.toUpperCase(),
          'Cantidad_Presentacion': qtyPres,
          'Tipo_Producto': tipoProducto,
          'Precio_Unidad': double.tryParse(precioUnidadController.text) ?? 0.0,
          'Precio_Caja': double.tryParse(precioCajaController.text) ?? 0.0,
          'Costo_Caja': tipoProducto == 'Caja' ? costo : 0.0,
          'Costo_Unidad': tipoProducto == 'Caja'
              ? (costo / (qtyPres > 0 ? qtyPres : 1))
              : costo,
          'Cantidad_Total': qtyTotal,
          'Stock_Minimo': int.tryParse(stockMinimoController.text) ?? 0,
          'Cantidad_Presentacion_blister':
              int.tryParse(cantidadPresentacionBlisterController.text) ?? 0,
          'Precio_Blister':
              double.tryParse(precioBlisterController.text) ?? 0.0,
          'Blister_SiNo': hayBlister ? 1 : 0,
          'Codigo_Barra': codigoBarraController.text,
          'ES_OCULTO': esOculto ? 1 : 0,
          'RECETA_MEDICA': requiereReceta ? 1 : 0,
        };

        await _productoRepository.updateProducto(producto);
        await _fechaVencimientoRepository.deleteFechaVencimientoPorProductoId(widget.productId);

        for (int i = 0; i < _fechaControllers.length; i++) {
          String fechaTexto = _fechaControllers[i].text;
          List<String> parts = fechaTexto.split('/');

          if (parts.length == 3) {
            String isoFecha = "${parts[2]}-${parts[1]}-${parts[0]}";
            int cantidad = int.tryParse(_cantidadControllers[i].text) ?? 0;

            if (cantidad > 0) {
              await _fechaVencimientoRepository
                  .insertFechaVencimiento(widget.productId, isoFecha, cantidad);
            }
          }
        }

        if (qtyTotal != totalAnt) {
          final hoy = DateTime.now();
          final prefs = await SharedPreferences.getInstance();
          final adminRealName = prefs.getString('adminName') ?? "Administrador";

          await _kardexRepository.insertKardexEntry({
            'NOMBRE_PRODUCTO': nombreProductoController.text.toUpperCase(),
            'FECHA_MOVIMIENTO':
                "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')} ${hoy.hour.toString().padLeft(2, '0')}:${hoy.minute.toString().padLeft(2, '0')}:${hoy.second.toString().padLeft(2, '0')}",
            'TIPO_MOVIMIENTO': qtyTotal > totalAnt ? 'Ingreso' : 'Salida',
            'CANTIDAD': (qtyTotal - totalAnt).abs(),
            'USUARIO': adminRealName,
            'STOCK_ANTERIOR': totalAnt,
            'STOCK_RESULTANTE': qtyTotal,
          });
        }

        if (mounted) {
          _showStatusSnackBar('Producto actualizado correctamente.', isError: false);
          // Usamos rootNavigator: true para asegurarnos de cerrar el diálogo
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoading = false);
          _showStatusSnackBar('Error al actualizar: $e', isError: true);
        }
      }
    }
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 800,
        height: 650,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Panel Lateral de Pasos
                _buildSidebar(),

                // Panel de Contenido Principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 32),
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (index) {
                                setState(() => _currentStep = index);
                              },
                              children: [
                                _buildStepIdentification(),
                                _buildStepInventoryPricing(),
                                _buildStepBatches(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildBottomActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1F),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          bottomLeft: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded,
                color: Color(0xFFFF3B30), size: 32),
          ),
          const SizedBox(height: 48),
          _sidebarItem(0, 'Identificación', 'Nombre y tipo de producto'),
          _sidebarItem(1, 'Inventario', 'Precios, stock y costos'),
          _sidebarItem(2, 'Lotes y Vencimiento', 'Control de caducidad'),
          const Spacer(),
          Text(
            'PharmaSalud v2.0',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int step, String title, String subtitle) {
    bool isSelected = _currentStep == step;
    bool isDone = _currentStep > step;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFF3B30)
                  : (isDone ? const Color(0xFF34C759) : Colors.white.withOpacity(0.05)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentStep == 0
                  ? 'Editar Producto'
                  : (_currentStep == 1 ? 'Control de Inventario' : 'Lotes y Control'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontFamily: 'Outfit',
                letterSpacing: -0.8,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1D1D1F), size: 28),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF5F5F7),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIdentification() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('INFORMACIÓN GENERAL', Icons.info_outline_rounded),
          const SizedBox(height: 24),
          _buildInputLabel('Nombre comercial / Científico'),
          KeyFocusWrapper(
            bindings: {LogicalKeyboardKey.f1: nombreProductoFocusNode},
            actions: {LogicalKeyboardKey.escape: () => nombreProductoController.clear()},
            child: _buildTextField(
              controller: nombreProductoController,
              hint: 'Ingrese nombre completo',
              icon: Icons.medication_outlined,
              badge: const F1Badge(label: 'F1'),
              focusNode: nombreProductoFocusNode,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Tipo de producto'),
                    _buildTypeSelector(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Alerta stock mínimo'),
                    _buildNumberField(
                      stockMinimoController,
                      '0',
                      Icons.warning_amber_rounded,
                      optional: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tipoProducto == 'Caja') ...[
            const SizedBox(height: 32),
            _buildInputLabel('Contenido del empaque (Unidades por Caja)'),
            _buildNumberField(
                cantidadPresentacionController, 'Indique cuántas unidades contiene la caja', Icons.layers_outlined),
          ],
          const SizedBox(height: 24),
          _buildInputLabel('Código de barra'),
          _buildTextField(
            controller: codigoBarraController,
            hint: 'Ingrese código de barras',
            icon: Icons.qr_code_outlined,
            optional: true,
          ),
          const SizedBox(height: 24),
          _buildDiscreetProductSwitch(),
          const SizedBox(height: 16),
          _buildRecetaMedicaSwitch(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF7A1528),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7A1528).withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tips_and_updates_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Elija "Caja" si el producto viene en paquetes con múltiples unidades, o "Unidad" si es venta individual.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.95),
                      fontFamily: 'Outfit',
                      height: 1.4,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscreetProductSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: esOculto ? const Color(0xFF5856D6).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esOculto
              ? const Color(0xFF5856D6).withOpacity(0.3)
              : const Color(0xFF1D1D1F).withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: esOculto
                  ? const Color(0xFF5856D6).withOpacity(0.15)
                  : const Color(0xFF1D1D1F).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              esOculto ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: esOculto ? const Color(0xFF5856D6) : const Color(0xFF1D1D1F).withOpacity(0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Producto Oculto / Discreto',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                Text(
                  'No aparecerá en el POS del vendedor a menos que se desbloquee con la clave secreta.',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF1D1D1F).withOpacity(0.45),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: esOculto,
            activeColor: const Color(0xFF5856D6),
            onChanged: (val) {
              setState(() {
                esOculto = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecetaMedicaSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: requiereReceta ? const Color(0xFFFF9500).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: requiereReceta
              ? const Color(0xFFFF9500).withOpacity(0.35)
              : const Color(0xFF1D1D1F).withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: requiereReceta
                  ? const Color(0xFFFF9500).withOpacity(0.15)
                  : const Color(0xFF1D1D1F).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.assignment_late_outlined,
              color: requiereReceta ? const Color(0xFFD97706) : const Color(0xFF1D1D1F).withOpacity(0.4),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requiere Receta Médica',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                Text(
                  'Medicamento controlado: alertará con un modal a la técnica/vendedor al intentar venderlo.',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF1D1D1F).withOpacity(0.45),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: requiereReceta,
            activeColor: const Color(0xFFFF9500),
            onChanged: (val) {
              setState(() {
                requiereReceta = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepInventoryPricing() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('DISPONIBILIDAD Y VALORES', Icons.analytics_outlined),
          const SizedBox(height: 32),
          
          // Nueva disposición de Column para mejor flujo vertical
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sección de STOCK (Superior)
              _buildStep2SectionCard(
                'CONTROL DE EXISTENCIAS',
                Icons.inventory_2_rounded,
                const Color(0xFF007AFF),
                tipoProducto == 'Caja' 
                  ? _buildStockGridCaja() 
                  : _buildStockGridUnidad(),
              ),
              const SizedBox(height: 24),
              // Sección de PRECIOS (Inferior)
              _buildStep2SectionCard(
                'ESTRUCTURA DE PRECIOS',
                Icons.payments_rounded,
                const Color(0xFF34C759),
                tipoProducto == 'Caja' 
                  ? _buildPriceGridCaja() 
                  : _buildPriceGridUnidad(),
              ),
            ],
          ),
          
          if (tipoProducto == 'Caja') ...[
            const SizedBox(height: 32),
            _buildBlisterSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2SectionCard(String title, IconData icon, Color color, Widget content) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1D1D1F).withOpacity(0.4),
                  letterSpacing: 1,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }

  Widget _buildStockGridCaja() {
    return Column(
      children: [
        _buildMinimalInputCard('Stock en Cajas', stockCajaController, Icons.all_inbox_rounded, '0'),
        const SizedBox(height: 16),
        _buildMinimalInputCard('Unidades Sueltas', stockUnidadController, Icons.widgets_rounded, '0'),
      ],
    );
  }

  Widget _buildStockGridUnidad() {
    return _buildMinimalInputCard('Stock Total Actual', stockUnidadController, Icons.inventory_2_rounded, '0');
  }

  Widget _buildPriceGridCaja() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMinimalInputCard('P. Venta Caja', precioCajaController, Icons.sell_rounded, '0.00', isDecimal: true, prefix: 'S/')),
            const SizedBox(width: 16),
            Expanded(child: _buildMinimalInputCard('P. Venta Unidad', precioUnidadController, Icons.style_rounded, '0.00', isDecimal: true, prefix: 'S/')),
          ],
        ),
        const SizedBox(height: 16),
        _buildMinimalInputCard('Costo de Inversión por Caja', costoProductoController, Icons.shopping_cart_checkout_rounded, '0.00', isDecimal: true, prefix: 'S/'),
      ],
    );
  }

  Widget _buildPriceGridUnidad() {
    return Column(
      children: [
        _buildMinimalInputCard('Precio de Venta Sugerido', precioUnidadController, Icons.sell_rounded, '0.00', isDecimal: true, prefix: 'S/'),
        const SizedBox(height: 16),
        _buildMinimalInputCard('Costo de Inversión Unitario', costoProductoController, Icons.receipt_long_rounded, '0.00', isDecimal: true, prefix: 'S/'),
      ],
    );
  }

  Widget _buildMinimalInputCard(String label, TextEditingController controller, IconData icon, String hint, {bool isDecimal = false, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF1D1D1F).withOpacity(0.3)),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D1D1F).withOpacity(0.4),
                fontFamily: 'Outfit',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildNumberField(controller, hint, null, isDecimal: isDecimal, prefix: prefix),
      ],
    );
  }

  Widget _buildStepBatches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CONTROL DE LOTES', Icons.calendar_month_rounded),
        const SizedBox(height: 8),
        Text(
          'Registre las fechas de vencimiento y cantidades de cada lote recibido.',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF1D1D1F).withOpacity(0.4),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _fechaControllers.isEmpty
              ? _buildEmptyBatchesState()
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _fechaControllers.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == _fechaControllers.length) {
                      return _buildAddBatchButton();
                    }
                    return _buildBatchRow(idx);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyBatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_note_rounded, size: 48, color: const Color(0xFF1D1D1F).withOpacity(0.15)),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin lotes registrados',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF1D1D1F).withOpacity(0.5),
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este paso es opcional',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF1D1D1F).withOpacity(0.3),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),
          _buildAddBatchButton(),
        ],
      ),
    );
  }

  Widget _buildAddBatchButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _fechaControllers.add(TextEditingController());
        _cantidadControllers.add(TextEditingController());
      }),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF34C759).withOpacity(0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
          color: const Color(0xFF34C759).withOpacity(0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 20, color: const Color(0xFF34C759)),
            const SizedBox(width: 10),
            Text(
              'Agregar nuevo lote',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF34C759),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchRow(int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del lote
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LOTE ${idx + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF007AFF),
                        letterSpacing: 0.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _fechaControllers[idx].dispose();
                  _cantidadControllers[idx].dispose();
                  _fechaControllers.removeAt(idx);
                  _cantidadControllers.removeAt(idx);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded, color: Color(0xFFFF3B30), size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Campos del lote
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Fecha de vencimiento'),
                    _buildTextField(
                      controller: _fechaControllers[idx],
                      hint: 'DD / MM / AAAA',
                      icon: Icons.event_rounded,
                      optional: true,
                      onTap: () async {
                        final date = await showAppDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          _fechaControllers[idx].text = DateFormat('dd/MM/yyyy').format(date);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Cantidad del lote'),
                    _buildNumberField(_cantidadControllers[idx], 'Ej: 50', Icons.inventory_rounded, optional: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        final nombreVacio = nombreProductoController.text.trim().isEmpty;
        final cajaVacia = tipoProducto == 'Caja' &&
            (cantidadPresentacionController.text.trim().isEmpty ||
                (int.tryParse(cantidadPresentacionController.text) ?? 0) <= 0);

        if (nombreVacio || cajaVacia) {
          setState(() => _stepError = 'Complete todos los campos requeridos antes de continuar.');
          return false;
        }
        setState(() => _stepError = null);
        return true;

      case 1:
        final precioUnitVacio = precioUnidadController.text.trim().isEmpty;
        final costoVacio = costoProductoController.text.trim().isEmpty;
        final stockVacio = tipoProducto == 'Caja'
            ? stockCajaController.text.trim().isEmpty
            : stockUnidadController.text.trim().isEmpty;
        final precioCajaVacio = tipoProducto == 'Caja' && precioCajaController.text.trim().isEmpty;

        if (precioUnitVacio || costoVacio || stockVacio || precioCajaVacio) {
          setState(() => _stepError = 'Complete todos los campos antes de continuar.');
          return false;
        }
        setState(() => _stepError = null);
        return true;

      case 2:
        if (_fechaControllers.isNotEmpty) {
          for (int i = 0; i < _fechaControllers.length; i++) {
            if (_fechaControllers[i].text.trim().isEmpty ||
                _cantidadControllers[i].text.trim().isEmpty) {
              setState(() => _stepError = 'Complete los campos de todos los lotes agregados o elimínelos.');
              return false;
            }
          }
        }
        setState(() => _stepError = null);
        return true;

      default:
        return true;
    }
  }

  Widget _buildBottomActions() {
    bool isLastStep = _currentStep == 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Error inline dentro del modal
        if (_stepError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B30), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _stepError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF3B30),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              _navButton('ANTERIOR', Icons.arrow_back_ios_new_rounded, () {
                setState(() => _stepError = null);
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }, isOutline: true)
            else
              const SizedBox(width: 100),
            
            _navButton(
              isLastStep ? 'ACTUALIZAR PRODUCTO' : 'SIGUIENTE PASO',
              isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              () {
                if (!_validateCurrentStep()) return;

                if (isLastStep) {
                  _guardarProducto();
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              color: isLastStep ? const Color(0xFF34C759) : const Color(0xFF1D1D1F),
            ),
          ],
        ),
      ],
    );
  }


  Widget _navButton(String label, IconData icon, VoidCallback onTap, {bool isOutline = false, Color color = const Color(0xFF1D1D1F)}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutline ? Colors.white : color,
        foregroundColor: isOutline ? const Color(0xFF1D1D1F) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOutline ? BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.1)) : BorderSide.none,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, fontFamily: 'Outfit'),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {Color color = const Color(0xFF1D1D1F)}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: color.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1D1D1F).withOpacity(0.8)),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1D1D1F),
            letterSpacing: 1.5,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1D1D1F).withOpacity(0.4),
          letterSpacing: 0.5,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool optional = false,
    VoidCallback? onTap,
    FocusNode? focusNode,
    Widget? badge,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: onTap != null,
      mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.text,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(hint, icon, badge: badge),
      validator: optional ? null : (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
      onTap: onTap,
    );
  }

  Widget _buildNumberField(TextEditingController controller, String hint, IconData? icon, {bool isDecimal = false, String? prefix, bool optional = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: [
        if (!isDecimal) FilteringTextInputFormatter.digitsOnly,
        if (isDecimal) FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700),
      decoration: _inputDecoration(hint, icon, prefix: prefix),
      validator: optional ? null : (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon, {String? prefix, Widget? badge}) {
    Widget? prefixWidget;
    if (icon != null && badge != null) {
      prefixWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16),
          Icon(icon, size: 20, color: const Color(0xFF1D1D1F).withOpacity(0.4)),
          const SizedBox(width: 8),
          badge,
          const SizedBox(width: 12),
        ],
      );
    } else if (icon != null) {
      prefixWidget = Icon(icon, size: 20, color: const Color(0xFF1D1D1F).withOpacity(0.4));
    } else if (badge != null) {
      prefixWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16),
          badge,
          const SizedBox(width: 12),
        ],
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0xFF1D1D1F).withOpacity(0.2), fontWeight: FontWeight.w700),
      prefixIcon: prefixWidget,
      prefixIconConstraints: (badge != null) ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
      prefixText: prefix != null ? '$prefix ' : null,
      prefixStyle: const TextStyle(color: Color(0xFF1D1D1F), fontWeight: FontWeight.w700, fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1D1D1F), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ['Unidad', 'Caja'].map((type) {
          final isSelected = tipoProducto == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => tipoProducto = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Text(
                  type,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF1D1D1F).withOpacity(0.4),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlisterSection() {
    return _buildStep2SectionCard(
      'VENTA POR BLISTER',
      Icons.auto_awesome_motion_rounded,
      const Color(0xFFFF9500),
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hayBlister ? 'Habilitado' : 'Deshabilitado',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hayBlister
                      ? const Color(0xFF34C759)
                      : const Color(0xFF1D1D1F).withOpacity(0.3),
                  fontFamily: 'Outfit',
                ),
              ),
              Switch.adaptive(
                value: hayBlister,
                activeColor: const Color(0xFF34C759),
                onChanged: (v) => setState(() => hayBlister = v),
              ),
            ],
          ),
          if (hayBlister) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMinimalInputCard(
                    'Unidades por Blister',
                    cantidadPresentacionBlisterController,
                    Icons.view_module_rounded,
                    'Ej: 10',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMinimalInputCard(
                    'Precio del Blister',
                    precioBlisterController,
                    Icons.sell_rounded,
                    '0.00',
                    isDecimal: true,
                    prefix: 'S/',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  @override
  void dispose() {
    nombreProductoController.dispose();
    cantidadPresentacionController.dispose();
    cantidadPresentacionBlisterController.dispose();
    stockCajaController.dispose();
    stockUnidadController.dispose();
    precioUnidadController.dispose();
    precioCajaController.dispose();
    precioBlisterController.dispose();
    costoProductoController.dispose();
    stockMinimoController.dispose();
    codigoBarraController.dispose();
    _pageController.dispose();
    for (var controller in _fechaControllers) controller.dispose();
    for (var controller in _cantidadControllers) controller.dispose();
    super.dispose();
  }
}

