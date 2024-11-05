import 'package:flutter/material.dart'; 
import 'package:pharma_salud/repositories/producto_repository.dart';
import 'package:pharma_salud/screens/cart_dialog.dart';
import 'package:pharma_salud/screens/cart_dialog_seleccionado.dart';
import 'package:pharma_salud/screens/login_screen.dart';
import 'package:pharma_salud/screens/venta_registro.dart';

class VendedorScreen extends StatefulWidget {
  final int userId; // ID del usuario
  const VendedorScreen({super.key,required this.userId}); // Ajusta el constructor para aceptar el userId

  @override
  _VendedorScreenState createState() => _VendedorScreenState();
}

class _VendedorScreenState extends State<VendedorScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  final ProductoRepository _productoRepository = ProductoRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // Crear el FocusNode

@override
void initState() {
  super.initState();
  _fetchProductos();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _focusSearchField(); // Solicitar el foco después de que el widget se haya construido
  });
}

  void _focusSearchField() {
    FocusScope.of(context).requestFocus(_searchFocusNode); // Solicitar el foco en el campo de búsqueda
  }

  Future<void> _fetchProductos() async {
    _productos = await _productoRepository.getAllProductos();
    _productosFiltrados = [];
    setState(() {});
  }

  void _filterProductos(String query) {
    if (query.isEmpty) {
      _productosFiltrados = [];
    } else {
      _productosFiltrados = _productos
          .where((producto) =>
              producto['Nombre_Producto']
                  ?.toLowerCase()
                  .contains(query.toLowerCase()) ?? false)
          .toList();
    }
    setState(() {});
  }

  void _logout() {
    // Aquí puedes agregar la lógica de cierre de sesión, como limpiar el estado de la sesión
    // y redirigir a la pantalla de inicio de sesión.
  // Cerrar el diálogo
Navigator.pushReplacement(
  // ignore: use_build_context_synchronously
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
    transitionDuration: Duration.zero, // Sin animación
    reverseTransitionDuration: Duration.zero, // Sin animación al volver
  ),
);  }

    Future<void> _exportEscasosCsv() async {
    await _productoRepository.exportarProductosStockBajoToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Productos exportados a CSV exitosamente.')),
    );
  }
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double paddingValue = screenWidth < 1400 ? 8.0 : 16.0;
    double textScale = screenWidth < 1400 ? 0.8 : 1.0;

return Scaffold(
  appBar: AppBar(
    automaticallyImplyLeading: false, // Esto oculta el botón de "back"
    title: Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centrar el título
      children: [
        // Ícono de cerrar sesión a la izquierda con Tooltip
        Tooltip(
          message: 'Cerrar sesión',
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout, // Acción de cerrar sesión
          ),
        ),
        const Spacer(), // Espacio flexible para centrar el título
        Text(
          'Punto de Venta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18 * textScale,
          ),
        ),
        const Spacer(), // Espacio flexible para mantener el título centrado
        // Ícono del carrito de compras con Tooltip
        Tooltip(
          message: 'Ver carrito',
          child: IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              CartDialog.showCart(context, widget.userId, () {
                // Lógica para refrescar el estado de la página
                _fetchProductos(); // Vuelve a cargar los productos
                _searchController.clear(); // Limpia el texto del buscador
                _focusSearchField(); // Enfocar el campo de búsqueda automáticamente
              });
            },
          ),
        ),
      ],
    ),
    backgroundColor: const Color.fromARGB(255, 255, 0, 0),
  ),
  backgroundColor: Colors.grey[200],
  body: Padding(
    padding: EdgeInsets.all(paddingValue),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(textScale),
              SizedBox(height: paddingValue * 2),
              _buildProductTable(textScale),
            ],
          ),
        ),
        SizedBox(width: paddingValue * 2),
        Flexible(
          flex: 1,
          child: DetallesVentaWidget(userId: widget.userId), // Aquí se pasa el userId
        ),
      ],
    ),
  ),
);

  }

Widget _buildSearchBar(double textScale) {
  return Row(
    children: [
      // Buscador
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode, // Asignar el FocusNode al campo de búsqueda
            onChanged: _filterProductos,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: TextStyle(fontSize: 14 * textScale),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Color.fromARGB(255, 255, 0, 0)),
            ),
          ),
        ),
      ),
      
      // Espacio entre el buscador y el botón
      const SizedBox(width: 8),
      
// Tooltip que envuelve el IconButton
Tooltip(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  message: 'Exportar lista de productos escasos', // Texto que aparece al pasar el cursor o mantener pulsado
  child: IconButton(
    icon: const Icon(Icons.edit_document), // Ícono de descarga
    color: Colors.red, // Color del ícono
    onPressed: () {
      // Acción para el botón
      _exportEscasosCsv();
    },
  ),
),

    ],
  );
}


  Widget _buildProductTable(double textScale) {
    if (_searchController.text.isEmpty) {
      return Container(); // No mostrar nada si no hay búsqueda
    }

if (_productosFiltrados.isEmpty) {
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox, // Puedes usar el icono que prefieras
          size: 100,
          color: Colors.grey, // Color del icono
        ),
        SizedBox(height: 10), // Espacio entre el icono y el texto
        Text(
          "No se encontraron productos.",
          style: TextStyle(fontSize: 18, color: Colors.grey), // Estilo del texto
        ),
      ],
    ),
  );
}

    return Expanded(
      child: ListView.builder(
        itemCount: _productosFiltrados.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTableHeader(textScale);
          }

          final producto = _productosFiltrados[index - 1];
          return _buildProductRow(producto, textScale);
        },
      ),
    );
  }

  Widget _buildTableHeader(double textScale) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 0, 0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Nombre de producto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          Expanded(flex: 1, child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('Stock Caja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('Stock Unidad', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('Precio Caja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('Precio Unidad', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> producto, double textScale) {
    final nombreProducto = producto['Nombre_Producto'] ?? 'Producto Desconocido';
    final tipoProducto = producto['Tipo_Producto'] ?? 'Desconocido';
    final cantidadTotal = producto['Cantidad_Total'] ?? 0;
    final cantidadPresentacion = producto['Cantidad_Presentacion'] ?? 1;
    final preciocaja = producto['Precio_Caja'] ?? 0;
    final preciounidad = producto['Precio_Unidad'] ?? 0;

    final int stockCaja;
    final int stockUnidad;

    if (tipoProducto == 'Caja') {
      stockCaja = (cantidadTotal / cantidadPresentacion).floor();
      stockUnidad = cantidadTotal % cantidadPresentacion;
    } else {
      stockCaja = 0;
      stockUnidad = cantidadTotal;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(nombreProducto, style: TextStyle(fontSize: 14 * textScale))),
          Expanded(flex: 1, child: Text(tipoProducto, style: TextStyle(fontSize: 14 * textScale), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text(stockCaja.toString(), style: TextStyle(fontSize: 14 * textScale), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text(stockUnidad.toString(), style: TextStyle(fontSize: 14 * textScale), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('S/${preciocaja.toStringAsFixed(2)}', style: TextStyle(fontSize: 14 * textScale), textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('S/${preciounidad.toStringAsFixed(2)}', style: TextStyle(fontSize: 14 * textScale), textAlign: TextAlign.center)),
          Expanded(flex: 1, child:           Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color.fromARGB(255, 4, 0, 254),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Añadir'),
                onPressed: () {
                  CartDialogSeleccionado.showCart(context, producto, widget.userId, () {
                    // Lógica para refrescar el estado de la página
                    _fetchProductos(); // Vuelve a cargar los productos
                    _searchController.clear(); // Limpia el texto del buscador
                    _focusSearchField(); // Enfocar el campo de búsqueda automáticamente
                  });
                },
              ),
            ),
          ),),
        ],
      ),
    );
  }
}