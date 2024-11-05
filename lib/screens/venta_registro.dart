import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/registro_ventas_repository.dart';

class DetallesVentaWidget extends StatefulWidget {
  final int userId; // Añadir el parámetro userId

  const DetallesVentaWidget({super.key, required this.userId});
  @override
  _DetallesVentaWidgetState createState() => _DetallesVentaWidgetState();
}

class _DetallesVentaWidgetState extends State<DetallesVentaWidget>
    with SingleTickerProviderStateMixin {
  final RegistroVentasRepository _registroVentasRepository = RegistroVentasRepository();
  late Future<List<ProductoVenta>> _futureProductos; // Declaración de variable
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _futureProductos = _obtenerTodosLosProductos(widget.userId); // Pasar userId aquí

    // Configuración de FadeTransition
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(_fadeController);
  }

Future<List<ProductoVenta>> _obtenerTodosLosProductos(int userId) async {
  // Obtener la fecha actual en el formato deseado (dd/MM/yyyy)
  String fechaHoy = DateFormat('dd/MM/yyyy').format(DateTime.now());

  // Obtener los detalles de venta según el userId desde el repositorio, filtrando por la fecha
  final List<Map<String, dynamic>> maps = await _registroVentasRepository.obtenerDetallesVentasPorUsuarioConFecha(userId, fechaHoy);

  // Convertimos los datos en una lista de objetos ProductoVenta
  return List.generate(maps.length, (i) {
    return ProductoVenta.fromMap(maps[i]);
  });
}



  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: FutureBuilder<List<ProductoVenta>>(
        future: _futureProductos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            _fadeController.forward();
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al cargar los productos'));
          }else if (!snapshot.hasData || snapshot.data!.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.remove_shopping_cart, // Icono que representa vacío
          size: 50, // Tamaño del ícono
          color: Colors.grey, // Color del ícono
        ),
        SizedBox(height: 10), // Espacio entre el icono y el texto
        Text(
          'No hay productos en la venta',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
} else {
            final productos = snapshot.data!;
            final double totalVendido = productos.fold(0, (sum, item) => sum + (item.precioVenta));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con gradiente sutil
              // Encabezado con gradiente sutil ocupando todo el ancho
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFFF0000), const Color.fromARGB(255, 255, 0, 0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,  // Alinea el contenido al centro horizontalmente
                        children: [
                          Text(
                            'Registro de Ventas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Total vendido: S/ ${totalVendido.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: productos.length,
                    padding: const EdgeInsets.all(0),
                    itemBuilder: (context, index) {
                      final producto = productos[index];
                      return GestureDetector(
                        onTap: () {
                          // Puedes añadir interacción aquí
                        },
                        child: Card(
                          color: Colors.white, // Establece el color del Card a blanco
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        producto.nombreProducto,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: const Color.fromARGB(255, 0, 0, 0)),
                                      ),
                                      Text(producto.tipoVenta, style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0),fontSize: 12)),
                                      Text('Cantidad: ${producto.cantidad}', style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0),fontSize: 12)),
                                      Text(producto.fecha, style: TextStyle(color: Colors.grey[600],fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'S/ ${producto.precioVenta.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: const Color.fromARGB(255, 0, 0, 0)),
                                    ),
                                  ],
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
            );
          }
        },
      ),
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

  ProductoVenta({
    required this.id,
    required this.registroVentaId,
    required this.nombreProducto,
    required this.cantidad,
    required this.tipoVenta,
    required this.precioVenta,
    required this.fecha,
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
    );
  }
}

