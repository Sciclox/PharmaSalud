import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/carrito_ventas_repository.dart';
import 'package:pharma_salud/repositories/fecha_vencimiento_repository.dart';
import 'package:pharma_salud/repositories/producto_repository.dart';
import 'package:intl/intl.dart';

class CartDialogSeleccionado {
  static void showCart(BuildContext context, Map<String, dynamic> producto, int userId, VoidCallback onClose) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CartDialogWidget(
        producto: producto,
        userId: userId,
      ),
    ).then((_) {
      // Llama al callback después de que se cierra el diálogo
      onClose();
    });
  }
}


class CartDialogWidget extends StatefulWidget {
  final Map<String, dynamic> producto;
  final int userId;

  const CartDialogWidget({
    Key? key,
    required this.producto,
    required this.userId,
  }) : super(key: key);

  @override
  _CartDialogWidgetState createState() => _CartDialogWidgetState();
}

class _CartDialogWidgetState extends State<CartDialogWidget> {
  String? _selectedVentaType;
  int _cantidad = 1;
  late int _stock;
  late double _precioUnidad;
  late double _precioCaja;
  late double _precioBlister;
  late double _total;

  final CartItemRepository _cartItemRepository = CartItemRepository();
  final ProductoRepository _productoRepository = ProductoRepository();
  final FechaVencimientoRepository _fechaVencimientoRepository = FechaVencimientoRepository();
  List<Map<String, dynamic>> _fechasVencimiento = [];

  @override
  void initState() {
    super.initState();
    _initializeValues();
    _loadFechasVencimiento(); // Cargar fechas de vencimiento
  }

// Cargar fechas de vencimiento desde la base de datos
void _loadFechasVencimiento() async {
  int productoId = widget.producto['ID'];
  _fechasVencimiento = await _fechaVencimientoRepository.getFechasVencimientoByProductoId(productoId);
  setState(() {}); // Actualizar la UI después de obtener las fechas
}

  void _initializeValues() {
    _selectedVentaType = 'Venta por unidad';
    _stock = widget.producto['Cantidad_Total'] ?? 0;
    _precioUnidad = widget.producto['Precio_Unidad'] ?? 0.0;
    _precioCaja = widget.producto['Precio_Caja'] ?? 0.0;
    _precioBlister = widget.producto['Precio_Blister'] ?? 0.0;
    _updateTotal();
  }

  void _updateTotal() {
    setState(() {
      switch (_selectedVentaType) {
        case 'Venta por caja':
          _stock = (widget.producto['Cantidad_Total'] / (widget.producto['Cantidad_Presentacion'] ?? 1)).floor();
          _total = _precioCaja * _cantidad;
          break;
        case 'Venta por blister':
          _stock = (widget.producto['Cantidad_Total'] / (widget.producto['Cantidad_Presentacion_blister'] ?? 1)).floor();
          _total = _precioBlister * _cantidad;
          break;
        case 'Venta por unidad':
        default:
          _stock = widget.producto['Cantidad_Total'] ?? 0;
          _total = _precioUnidad * _cantidad;
      }
    });
  }

  void _incrementCantidad() {
    if (_cantidad < _stock) {
      setState(() {
        _cantidad++;
        _updateTotal();
      });
    }
  }

  void _decrementCantidad() {
    if (_cantidad > 1) {
      setState(() {
        _cantidad--;
        _updateTotal();
      });
    }
  }

  Future<void> _addToCart() async {
    try {
      await _cartItemRepository.addItemToCart({
        'REGISTRO_VENTA_ID': 1, // Cambiar según tu lógica
        'PRODUCTO_ID': widget.producto['ID'],
        'CANTIDAD': _cantidad,
        'PRECIO_VENTA': _total,
        'FECHA': DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now()),
        'TIPO_VENTA': _selectedVentaType,
      });

      int cantidadADescontar = _calculateQuantityToDeduct();
          // Restar cantidad de la tabla de fechas de vencimiento
      await _fechaVencimientoRepository.restarCantidad(widget.producto['ID'], cantidadADescontar);
      await _productoRepository.descontarCantidadTotal(widget.producto['ID'], cantidadADescontar);
      
      Navigator.of(context).pop();
    } catch (e) {
      // Manejo de errores, por ejemplo, mostrando un mensaje
      print('Error al agregar al carrito: $e');
    }
  }

  int _calculateQuantityToDeduct() {
    switch (_selectedVentaType) {
      case 'Venta por caja':
        return (_cantidad * (widget.producto['Cantidad_Presentacion'] ?? 1)).toInt();
      case 'Venta por blister':
        return (_cantidad * (widget.producto['Cantidad_Presentacion_blister'] ?? 1)).toInt();
      default:
        return _cantidad;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> ventaTypes = ['Venta por unidad', 'Venta por caja'];
    if (widget.producto['Blister_SiNo'] == 1) {
      ventaTypes.add('Venta por blister');
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.white,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProductTitle(),
              const SizedBox(height: 20),
              _buildVentaTypeDropdown(ventaTypes),
              const SizedBox(height: 20),
              _buildStockInfo(),
              const SizedBox(height: 20),
              _buildQuantitySelector(),
              const SizedBox(height: 20),
              _buildFechasVencimiento(), // Muestra las fechas de vencimiento aquí
              const SizedBox(height: 20),
              _buildTotalInfo(),
              const SizedBox(height: 30),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductTitle() {
    return Text(
      widget.producto['Nombre_Producto'] ?? 'Producto',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 24,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildVentaTypeDropdown(List<String> ventaTypes) {
    if (widget.producto['Tipo_Producto'] == 'Unidad') return SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueGrey, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButton<String>(
        value: _selectedVentaType,
        underline: const SizedBox(),
        isExpanded: true,
        items: ventaTypes.map((value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedVentaType = value;
            _cantidad = 1;
            _updateTotal();
          });
        },
      ),
    );
  }

  Widget _buildStockInfo() {
    return Text(
      'Stock disponible: $_stock',
      style: TextStyle(
        fontSize: 18,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.blueGrey, width: 1.5),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.redAccent),
            onPressed: _decrementCantidad,
          ),
          Text(
            'Cantidad: $_cantidad',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: _incrementCantidad,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalInfo() {
    return Text(
      'Total: S/${_total.toStringAsFixed(2)}',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 0, 0, 0),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.shopping_cart, color: Colors.white),
          label: const Text(
            'Añadir al carrito',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          onPressed: _stock > 0 ? _addToCart : null,
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

Widget _buildFechasVencimiento() {
  if (_fechasVencimiento.isEmpty) {
    return const Text(
      'No hay fechas de vencimiento disponibles',
      style: TextStyle(fontSize: 16, color: Colors.grey),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Fechas de vencimiento:',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      ListView.builder(
        shrinkWrap: true, // Para que se ajuste a su contenido
        itemCount: _fechasVencimiento.length,
        itemBuilder: (context, index) {
          final fecha = _fechasVencimiento[index];

          // Usamos DateFormat para convertir la fecha en formato DD/MM/YYYY
          final formato = DateFormat('dd/MM/yyyy');
          final fechaVencimiento = formato.parse(fecha['Fecha_Vencimiento']);
          
          // Calcular los días restantes
          final ahora = DateTime.now();
          final diferencia = fechaVencimiento.difference(ahora).inDays;

          // Determinar el mensaje según la diferencia de días
          final diasRestantes = diferencia > 0
              ? '$diferencia días restantes'
              : '¡Producto vencido!';

          return ListTile(
            title: Text('Fecha: ${fecha['Fecha_Vencimiento']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cantidad: ${fecha['Cantidad']}'),
                Text(diasRestantes, style: TextStyle(color: diferencia <= 0 ? Colors.red : Colors.black)),
              ],
            ),
          );
        },
      ),
    ],
  );
}

}
