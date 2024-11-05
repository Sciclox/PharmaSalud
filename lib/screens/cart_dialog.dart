import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/carrito_ventas_repository.dart';
import 'package:pharma_salud/repositories/fecha_vencimiento_repository.dart';
import 'package:pharma_salud/repositories/producto_repository.dart';
import 'package:pharma_salud/repositories/registro_ventas_repository.dart';
import 'package:pharma_salud/screens/check.dart';
import 'package:pharma_salud/screens/vendedor_screen.dart';
import 'package:intl/intl.dart';
// Clase principal para mostrar el diálogo del carrito
class CartDialog {
  static void showCart(BuildContext context, int userId,VoidCallback onClose) {
    final CartItemRepository cartItemRepository = CartItemRepository();
    final RegistroVentasRepository registroVentasRepository = RegistroVentasRepository(); // Instancia de RegistroVentasRepository
    final FechaVencimientoRepository fechaVencimientoRepository = FechaVencimientoRepository(); // Instancia de RegistroVentasRepository

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _CartDialogContent(
              cartItemRepository: cartItemRepository,
              registroVentasRepository: registroVentasRepository, // Pasar la instancia de ventas
              fechaVencimientoRepository: fechaVencimientoRepository, // Pasar la instancia de ventas
              userId: userId,
              productoRepository: ProductoRepository(),  // Pasar el userId aquí
              onClose: onClose, // Pasar el callback aquí
            ),
          ),
        );
      },
    );
  }
}

// Contenido del diálogo del carrito
class _CartDialogContent extends StatefulWidget {
  final CartItemRepository cartItemRepository;
  final ProductoRepository productoRepository;
  final FechaVencimientoRepository fechaVencimientoRepository;
  final RegistroVentasRepository registroVentasRepository; // Nueva propiedad para el repositorio de ventas
  final int userId; // Añadir userId como propiedad
  final VoidCallback onClose; // Añadir onClose como propiedad

  const _CartDialogContent({
    Key? key,
    required this.cartItemRepository,
    required this.registroVentasRepository, // Requiere el repositorio de ventas
    required this.productoRepository, // Requiere el repositorio de ventas
    required this.fechaVencimientoRepository, // Requiere el repositorio de ventas
    required this.userId,
    required this.onClose,  // Requerir userId
  }) : super(key: key);

  @override
  _CartDialogContentState createState() => _CartDialogContentState();
}

class _CartDialogContentState extends State<_CartDialogContent> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>( 
      future: widget.cartItemRepository.getCartItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar el carrito.'));
        } else {
          final cartItems = snapshot.data!;
          double total = _calculateTotal(cartItems);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const Divider(color: Colors.grey, thickness: 1.0),
              _buildCartHeader(),
              _buildCartItems(cartItems),
              const SizedBox(height: 10),
              const Divider(color: Colors.grey, thickness: 1.0),
              _buildCartSummary(context, total, cartItems),
            ],
          );
        }
      },
    );
  }

  // Construir el encabezado del diálogo
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Carrito de Compras',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Color.fromARGB(255, 255, 0, 0)),
          onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
                widget.onClose(); // Llama al callback para refrescar la pantalla     
           },
        ),
      ],
    );
  }

  // Calcular el total de los elementos en el carrito
  double _calculateTotal(List<Map<String, dynamic>> cartItems) {
    return cartItems.fold(0.0, (sum, item) {
      return sum + (item['PRECIO_VENTA'] ?? 0.0);
    });
  }

Widget _buildCartHeader() {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    color: Colors.red, // Establece el color de fondo del Card a rojo
    child: const Padding(
      padding: EdgeInsets.all(10.0),
      child: Row(
        children: [
          // 'Producto' ocupa 2 partes del espacio total
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Producto',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
          // 'Tipo de Venta', 'Cantidad', 'Precio', 'Fecha de Venta', y 'Acciones' ocupan 1 parte cada uno
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Tipo de Venta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Cantidad',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Precio',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Fecha de Venta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Acciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // Cambia el color del texto a blanco
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


// Construir la lista de productos en el carrito
Widget _buildCartItems(List<Map<String, dynamic>> cartItems) {
  return Expanded(
    child: SingleChildScrollView(
      child: Column(
        children: cartItems.map((item) {
          return _buildCartItem(item);
        }).toList(),
      ),
    ),
  );
}
Widget _buildCartItem(Map<String, dynamic> item) {
  return Card(
    elevation: 3,
    color: const Color.fromARGB(255, 255, 255, 255), // Cambia este color al que desees para el fondo del Card
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(
        color: Color.fromARGB(255, 209, 209, 212), // Cambia este color al que desees para el borde
        width: 1, // Cambia el grosor del borde según sea necesario
      ),
    ),
    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    child: Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          // 'Nombre de Producto' ocupa 2 partes del espacio total
          Expanded(
            flex: 2,
            child: Text(
              item['Nombre_Producto'] ?? 'Producto Desconocido',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          // 'Tipo de Venta', 'Cantidad', 'Precio', y 'Fecha de Venta' ocupan 1 parte cada uno
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                item['TIPO_VENTA'] ?? 'Tipo no especificado',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                '${item['CANTIDAD'] ?? 0}',
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'S/${(item['PRECIO_VENTA'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                item['FECHA'] ?? 'Fecha no especificada',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ),
          ),
          // 'Acciones' (el botón de eliminar) ocupa 1 parte del espacio total
          Expanded(
            flex: 1,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    int cantidadVendida = item['CANTIDAD']; // Obtener la cantidad del producto vendido
                    int productoId = item['PRODUCTO_ID']; // Suponiendo que 'PRODUCTO_ID' es el ID del producto en la tabla
                    if (item['TIPO_VENTA'] == 'Venta por caja') {
                         cantidadVendida = (item['CANTIDAD'] * (item['Cantidad_Presentacion'] ?? 1)).toInt();
                    } else if (item['TIPO_VENTA'] == 'Venta por blister') {
                         cantidadVendida = (item['CANTIDAD'] * (item['Cantidad_Presentacion_blister'] ?? 1)).toInt();
                    }
                    // Primero, aumentar la cantidad total del inventario usando la instancia
                    await widget.productoRepository.aumentarCantidadTotal(productoId, cantidadVendida);
                    await widget.fechaVencimientoRepository.sumarCantidad(productoId, cantidadVendida);

                    // Luego, eliminar el producto del carrito
                    await widget.cartItemRepository.removeItemFromCart(item['ID']);
                            // Refrescar el estado del diálogo
                    Navigator.of(context).pop(); // Cierra el diálogo
                    CartDialog.showCart(context, widget.userId, widget.onClose); // Vuelve a abrir el diálogo
                  },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Construir el resumen del carrito
Widget _buildCartSummary(BuildContext context, double total, List<Map<String, dynamic>> cartItems) {
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Total:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            width: 20, // Especifica el ancho que desees aquí
          ),
          Text(
            'S/${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ],
      ),
      const SizedBox(height: 30),
      _buildActionButtons(context, total, cartItems), // Pasar total y cartItems aquí
    ],
  );
}


// Construir los botones de acción
Widget _buildActionButtons(BuildContext context, double total, List<Map<String, dynamic>> cartItems) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      ElevatedButton.icon(
        onPressed: cartItems.isNotEmpty // Verifica si hay elementos en el carrito
            ? () async {
                await _guardarVenta(context, total, cartItems); // Llamar a la función para guardar la venta
              }
            : null, // Deshabilitar el botón si el carrito está vacío
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text(
          'Guardar Venta',
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 0, 255),
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 30,
          ),
        ),
      ),
    ],
  );
}


// Función para guardar la venta
Future<void> _guardarVenta(BuildContext context, double total, List<Map<String, dynamic>> cartItems) async {
  
  // Suponiendo que tienes un método para obtener el ID del usuario actual
  final int usuarioId = widget.userId;

  // Crear un nuevo registro de venta
  Map<String, dynamic> registroVenta = {
    'FECHA': DateFormat('dd/MM/yyyy').format(DateTime.now()), // Obtener la fecha actual
    'TOTAL': total,
    'USUARIO_ID': usuarioId,
  };

  // Guardar el registro de venta y obtener el ID
  int registroVentaId = await widget.registroVentasRepository.agregarRegistroVenta(registroVenta);
  
for (var item in cartItems) {
  Map<String, dynamic> detalleVenta = {
        'REGISTRO_VENTA_ID': registroVentaId,
        'PRODUCTO_ID': item['PRODUCTO_ID'] ?? 'ID no especificado', // Manejo de errores
        'NOMBRE_PRODUCTO': item['Nombre_Producto'] ?? 'Producto Desconocido', // Manejo de errores
        'USUARIO_ID': usuarioId,
        'FECHA': item['FECHA'],
        'TIPO_VENTA': item['TIPO_VENTA'] ?? 0, // Manejo de errores
        'CANTIDAD': item['CANTIDAD'] ?? 0, // Manejo de errores
        'PRECIO_VENTA': item['PRECIO_VENTA'] ?? 0.0, // Manejo de errores
  };

  try {
    await widget.registroVentasRepository.agregarDetalleVenta(detalleVenta);
  } catch (e) {
    // Manejo de error, tal vez mostrar un mensaje al usuario
    print('Error al guardar detalle de venta: $e');
  }
}
  // Opcional: Limpiar el carrito después de guardar la venta
  await widget.cartItemRepository.clearCart(); // Necesitas implementar este método

  // Cerrar el diálogo
Navigator.pushReplacement(
  // ignore: use_build_context_synchronously
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => VendedorScreen(userId: usuarioId,),
    transitionDuration: Duration.zero, // Sin animación
    reverseTransitionDuration: Duration.zero, // Sin animación al volver
  ),
);
  // Mostrar un diálogo de éxito
  // Ejemplo de cómo llamar a la función para mostrar el diálogo:
  mostrarDialogoExito(context, cartItems, total);
}

}
