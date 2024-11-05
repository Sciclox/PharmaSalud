import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/producto_repository.dart';
import 'package:pharma_salud/screens/producto_editeform.dart';
import 'package:pharma_salud/screens/producto_form.dart';

class ProductoScreen extends StatefulWidget {
  const ProductoScreen({super.key});

  @override
  _ProductoScreenState createState() => _ProductoScreenState();
}

class _ProductoScreenState extends State<ProductoScreen> {
  final ProductoRepository _productoRepository = ProductoRepository();
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }


  Future<void> _loadProductos() async {
    _productos = await _productoRepository.getAllProductos();
    _productosFiltrados = List.from(_productos);
    setState(() {});
  }

  void _filterProductos(String query) {
    _productosFiltrados = _productos
        .where((producto) =>
            producto['Nombre_Producto']
                ?.toLowerCase()
                .contains(query.toLowerCase()) ?? false)
        .toList();
    setState(() {});
  }

  Future<void> _exportCsv() async {
    await _productoRepository.exportProductosToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Productos exportados a CSV exitosamente.')),
    );
  }

    Future<void> _exportEscasosCsv() async {
    await _productoRepository.exportarProductosStockBajoToCSV();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Productos exportados a CSV exitosamente.')),
    );
  }

  Future<void> _importCsv() async {
    _showLoadingDialog('Importando productos...');
    await _productoRepository.importProductosFromCSV();
    Navigator.of(context).pop(); // Cerrar el diálogo de carga
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Productos importados desde CSV exitosamente.')),
    );
    await _loadProductos();
  }

  Future<void> _deleteProducto(int id) async {
    await _productoRepository.deleteProducto(id);
    await _loadProductos();
  }

  Future<void> _deleteAllProductos() async {
    _showLoadingDialog('Eliminando productos...');
    await _productoRepository.deleteAllProductos();
    Navigator.of(context).pop(); // Cerrar el diálogo de carga
    await _loadProductos();
  }


  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Por favor, espere un momento',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    // Reemplazar el AppBar por un Container
    body: Column(
      children: [
        // Container reemplazando el AppBar
        Container(
          height: 56, // Altura del Container similar al AppBar
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          color: const Color.fromARGB(255, 255, 0, 0), // Color de fondo
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text(
                  'Productos',
                  style: TextStyle(
                    color: Colors.white, // Color del texto
                    fontSize: 20, // Tamaño de la fuente
                    fontWeight: FontWeight.bold, // Texto en negrita
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.my_library_add, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FormularioProducto()),
                  ).then((_) {
                    _loadProductos();
                    _searchController.clear(); // Limpiar el campo de búsqueda aquí
                  });
                },
                tooltip: 'Agregar Producto',
                iconSize: 30.0,
                padding: const EdgeInsets.all(10.0),
              ),
            ],
          ),
        ),
        _buildSearchField(),
        _buildActionButtons(),
        _buildProductTable(),
      ],
    ),
  );
}

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          labelText: 'Buscar productos',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: _filterProductos,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.import_export, color: Colors.white),
            label: const Text("Importar", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: _importCsv,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.document_scanner, color: Colors.white),
            label: const Text("Exportar", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: _exportCsv,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.document_scanner, color: Colors.white),
            label: const Text("Lista productos escasos", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: _exportEscasosCsv,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text("Eliminar todos", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final shouldDeleteAll = await _showDeleteAllConfirmationDialog(context);
              if (shouldDeleteAll) {
                _deleteAllProductos();
              }
            },
          ),
        ],
      ),
    );
  }

Widget _buildProductTable() {
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
          return _buildTableHeader();
        }

        final producto = _productosFiltrados[index - 1];
        return _buildProductRow(producto);
      },
    ),
  );
}

Widget _buildTableHeader() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.blueAccent,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Expanded(flex: 2, child: Text('Nombre de producto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
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

Widget _buildProductRow(Map<String, dynamic> producto) {
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
        Expanded(flex: 2, child: Text(nombreProducto, style: TextStyle(fontSize: 14))),
        Expanded(flex: 1, child: Text(tipoProducto, style: TextStyle(fontSize: 14 ), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text(stockCaja.toString(), style: TextStyle(fontSize: 14 ), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text(stockUnidad.toString(), style: TextStyle(fontSize: 14 ), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text('S/${preciocaja.toStringAsFixed(2)}', style: TextStyle(fontSize: 14 ), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Text('S/${preciounidad.toStringAsFixed(2)}', style: TextStyle(fontSize: 14 ), textAlign: TextAlign.center)),
        Expanded(flex: 1, child: Center(child: _buildProductActions(producto),),),      
      ],
    ),
  );
}


  Widget _buildProductActions(Map<String, dynamic> producto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Color.fromARGB(255, 55, 0, 255)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProductoEditForm(productId: producto['ID'])),
            ).then((_) => _loadProductos());
            _searchController.clear(); // Limpiar el campo de búsqueda aquí
          },
          tooltip: 'Editar Producto',
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () async {
            final shouldDelete = await _showDeleteConfirmationDialog(context);
            if (shouldDelete) {
              _deleteProducto(producto['ID']);
            }
          },
          tooltip: 'Eliminar Producto',
        ),
      ],
    );
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Producto'),
          content: Text('¿Estás seguro de que deseas eliminar este producto?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Future<bool> _showDeleteAllConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Eliminar Todos los Productos'),
          content: Text('¿Estás seguro de que deseas eliminar todos los productos?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Eliminar Todo'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }
}
