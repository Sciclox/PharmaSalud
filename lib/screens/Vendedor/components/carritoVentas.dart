import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/carritoVentas.dart';
import 'package:pharma_salud/repositories/fechaVencimiento.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/screens/Vendedor/components/mensajeGuardado.dart';
import 'package:pharma_salud/screens/Vendedor/ventasHome.dart';

// Clase principal para mostrar el diálogo del carrito
class CartDialog {
  static void showCart(BuildContext context, int userId, String userName,
      String gender, VoidCallback onClose) {
    final CartItemRepository cartItemRepository = CartItemRepository();
    final KardexRepository kardexRepository = KardexRepository();
    final RegistroVentasRepository registroVentasRepository =
        RegistroVentasRepository(); // Instancia de RegistroVentasRepository
    final FechaVencimientoRepository fechaVencimientoRepository =
        FechaVencimientoRepository(); // Instancia de RegistroVentasRepository

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.white, // 👈 Fondo blanco del diálogo
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _CartDialogContent(
              cartItemRepository: cartItemRepository,
              kardexRepository: kardexRepository,
              registroVentasRepository:
                  registroVentasRepository, // Pasar la instancia de ventas
              fechaVencimientoRepository:
                  fechaVencimientoRepository, // Pasar la instancia de ventas
              userId: userId,
              userName: userName,
              gender: gender,
              productoRepository: ProductoRepository(), // Pasar el userId aquí
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
  final KardexRepository kardexRepository;
  final ProductoRepository productoRepository;
  final FechaVencimientoRepository fechaVencimientoRepository;
  final RegistroVentasRepository
      registroVentasRepository; // Nueva propiedad para el repositorio de ventas
  final int userId; // Añadir userId como propiedad
  final String userName;
  final String gender;
  final VoidCallback onClose; // Añadir onClose como propiedad

  const _CartDialogContent({
    required this.cartItemRepository,
    required this.kardexRepository,
    required this.registroVentasRepository, // Requiere el repositorio de ventas
    required this.productoRepository, // Requiere el repositorio de ventas
    required this.fechaVencimientoRepository, // Requiere el repositorio de ventas
    required this.userId,
    required this.userName,
    required this.gender,
    required this.onClose, // Requerir userId
  });

  @override
  _CartDialogContentState createState() => _CartDialogContentState();
}

class _CartDialogContentState extends State<_CartDialogContent> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.cartItemRepository.getCartItems(widget.userId),
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
        CircleAvatar(
          radius: 20, // Tamaño del botón
          backgroundColor: Colors.red, // Fondo rojo
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white), // Ícono blanco
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el diálogo
              widget.onClose(); // Llama al callback
            },
          ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      color: Colors.blueAccent, // Establece el color de fondo del Card a rojo
      child: const Padding(
        padding: EdgeInsets.all(15.0),
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
      color: const Color.fromARGB(255, 255, 255,
          255), // Cambia este color al que desees para el fondo del Card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Row(
          children: [
            // 'Nombre de Producto' ocupa 2 partes del espacio total
            Expanded(
              flex: 2,
              child: Text(
                item['Nombre_Producto'] ?? 'Producto Desconocido',
                style: const TextStyle(
                  fontSize: 14,
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
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  'S/${formatMoney(item['PRECIO_VENTA'] ?? 0.0)}',
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
                  _formatFecha(item['FECHA'] ?? 'Fecha no especificada'),
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
                      await widget.cartItemRepository
                          .removeItemFromCart(item['ID']);
                      setState(() {});
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
  Widget _buildCartSummary(BuildContext context, double total,
      List<Map<String, dynamic>> cartItems) {
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
              'S/${formatMoney(total)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _buildActionButtons(
            context, total, cartItems), // Pasar total y cartItems aquí
      ],
    );
  }

// Construir los botones de acción
  Widget _buildActionButtons(BuildContext context, double total,
      List<Map<String, dynamic>> cartItems) {
    return SizedBox(
      width: double.infinity, // Ocupa todo el ancho disponible
      height: 60, // Altura fija
      child: ElevatedButton.icon(
        onPressed: cartItems.isNotEmpty
            ? () async {
                await _guardarVenta(context, total, cartItems);
              }
            : null, // Deshabilitado si el carrito está vacío
        icon: const Icon(
          Icons.add_shopping_cart,
          color: Colors.white,
          size: 30,
        ),
        label: const Text(
          'Guardar Venta',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, // Botón rojo
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8), // Opcional: bordes redondeados
          ),
        ),
      ),
    );
  }

  Future<void> _guardarVenta(BuildContext context, double total,
      List<Map<String, dynamic>> cartItems) async {
    try {
      // Mostrar el diálogo de carga
      showDialog(
        context: context,
        barrierDismissible:
            false, // Evitar que el usuario cierre el diálogo tocando fuera
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Guardando la venta, por favor espere..."),
              ],
            ),
          );
        },
      );

      // Suponiendo que tienes un método para obtener el ID del usuario actual
      final int usuarioId = widget.userId;

      // Crear un nuevo registro de venta
      final hoy = DateTime.now();
      final fechaIso =
          "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";

      Map<String, dynamic> registroVenta = {
        'FECHA': fechaIso, // Obtener la fecha actual en ISO 8601
        'TOTAL': total,
        'USUARIO_ID': usuarioId,
      };

      // Guardar el registro de venta y obtener el ID
      int registroVentaId = await widget.registroVentasRepository
          .agregarRegistroVenta(registroVenta);

      // Iterar sobre los productos en el carrito y agregar los detalles de venta
      for (var item in cartItems) {
        Map<String, dynamic> detalleVenta = {
          'REGISTRO_VENTA_ID': registroVentaId,
          'PRODUCTO_ID': item['PRODUCTO_ID'],
          'NOMBRE_PRODUCTO': item['Nombre_Producto'] ?? 'Producto Desconocido',
          'USUARIO_ID': usuarioId,
          'FECHA': fechaIso,
          'TIPO_VENTA': item['TIPO_VENTA'] ?? 'Venta por unidad',
          'CANTIDAD': item['CANTIDAD'] ?? 0,
          'PRECIO_VENTA': item['PRECIO_VENTA'] ?? 0.0,
        };

        try {
          int detalleVentaId = await widget.registroVentasRepository
              .agregarDetalleVenta(detalleVenta);

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

          // Obtener stock actual antes de descontar para secuencia cronológica perfecta
          final prodActual = await widget.productoRepository.getProductoById(productoId);
          final int stockAnterior = (prodActual?['Cantidad_Total'] as num?)?.toInt() ?? 0;
          final int stockResultante = stockAnterior - cantidadUnidades;

          // 1. Descontar existencias físicas en BD y lotes
          await widget.productoRepository.descontarCantidadTotal(productoId, cantidadUnidades);
          await widget.fechaVencimientoRepository.restarCantidad(productoId, cantidadUnidades);

          // 2. Registrar asiento oficial en KARDEX vinculado al detalle de venta
          Map<String, dynamic> kardexEntry = {
            'CANTIDAD': cantidadUnidades,
            'TIPO_MOVIMIENTO': item['TIPO_VENTA'] ?? 'Venta por unidad',
            'FECHA_MOVIMIENTO': fechaIso,
            'USUARIO': widget.userName,
            'NOMBRE_PRODUCTO': item['Nombre_Producto'] ?? 'Producto Desconocido',
            'STOCK_ANTERIOR': stockAnterior,
            'STOCK_RESULTANTE': stockResultante,
            'ID_DETALLE_VENTA': detalleVentaId,
          };
          await widget.kardexRepository.insertKardexEntry(kardexEntry);
        } catch (e) {
          print('Error al guardar detalle de venta y kardex: $e');
        }
      }

      // Limpiar el carrito
      await widget.cartItemRepository
          .clearCart(widget.userId); // Necesitas implementar este método

      // Cerrar el diálogo de carga
      Navigator.of(context).pop(); // Cerrar el diálogo de carga

      // Navegar a la pantalla de Vendedor sin animación
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              VendedorScreen(
            userId: usuarioId,
            userName: widget.userName,
            gender: widget.gender,
          ),
          transitionDuration: Duration.zero, // Sin animación
          reverseTransitionDuration: Duration.zero, // Sin animación al volver
        ),
      );

      // Mostrar un diálogo de éxito
      await mostrarDialogoExito(context, cartItems, total, total, 0.0);
    } catch (e) {
      // Cerrar el diálogo de carga si ocurre un error
      Navigator.of(context).pop(); // Cerrar el diálogo de carga
      print('Error al guardar venta: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
              duration: const Duration(milliseconds: 800),
              content: Text('Error: $e')));
    }
  }

  String _formatFecha(String fecha) {
    if (fecha.contains('-')) {
      try {
        DateTime parsed = DateTime.parse(fecha);
        return "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}";
      } catch (e) {
        return fecha;
      }
    }
    return fecha;
  }
}
