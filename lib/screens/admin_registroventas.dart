import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/registro_ventas_repository.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:pharma_salud/repositories/usuario_repository.dart';

class AdminRegistroVentasWidget extends StatefulWidget {
  @override
  _AdminRegistroVentasWidgetState createState() => _AdminRegistroVentasWidgetState();
}

class _AdminRegistroVentasWidgetState extends State<AdminRegistroVentasWidget> with SingleTickerProviderStateMixin {
  final RegistroVentasRepository _registroVentasRepository = RegistroVentasRepository();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  List<ProductoVenta> _productosFiltrados = []; // Lista para almacenar los productos filtrados

  late AnimationController _fadeController;
  // Controladores para las fechas
  final TextEditingController _fechaInicialController = MaskedTextController(mask: '00/00/0000');
  final TextEditingController _fechaFinalController = MaskedTextController(mask: '00/00/0000');
  List<Map<String, dynamic>> _usuarios = []; // Lista para almacenar usuarios
  String? _usuarioSeleccionado; // Variable para almacenar el usuario seleccionado
  
  @override
  void initState() {
    super.initState();
    _productosFiltrados = []; // Inicializar la lista vacía

    // Configuración de FadeTransition
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _obtenerUsuarios(); // Llama a la función para obtener usuarios
  }

  Future<void> _filtrarVentas() async {
    // Asegúrate de que _usuarioSeleccionado no sea nulo
    if (_usuarioSeleccionado == null) {
      print("Por favor, selecciona un vendedor.");
      return; // Termina la función si no hay usuario seleccionado
    }

    // Obtener el ID del usuario seleccionado
    int idUsuario = int.parse(_usuarioSeleccionado!);

    // Obtener las fechas
    String fechaInicial = _fechaInicialController.text;
    String fechaFinal = _fechaFinalController.text;

    // Obtener los productos filtrados
    final List<Map<String, dynamic>> maps = await _registroVentasRepository.obtenerDetallesVentasPorUsuarioConFechaV02(idUsuario, fechaInicial, fechaFinal);
    
    // Convertir los mapas a una lista de ProductoVenta
    setState(() {
      _productosFiltrados = List.generate(maps.length, (i) {
        return ProductoVenta.fromMap(maps[i]);
      });
    });
  }

  Future<void> _obtenerUsuarios() async {
    final usuarios = await _usuarioRepository.readUsuariosV02(); // Llama a readUsuarios
    setState(() {
      _usuarios = usuarios; // Almacena los usuarios en la variable
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildTableHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center, // Centrar el texto en el encabezado
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          // Encabezado con total vendido
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 0, 0),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Registro de Ventas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  'Total vendido: S/ ${_productosFiltrados.fold(0.0, (sum, item) => sum + item.precioVenta).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          // Contenedor con fondo blanco y elevación
          Container(
            decoration: BoxDecoration(
              color: Colors.white, // Fondo blanco
              borderRadius: BorderRadius.circular(10), // Bordes redondeados
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2), // Color de la sombra
                  spreadRadius: 2, // Radio de expansión
                  blurRadius: 5, // Desenfoque de la sombra
                  offset: Offset(0, 3), // Desplazamiento de la sombra
                ),
              ],
            ),
            padding: const EdgeInsets.all(16), // Espaciado interno
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Centrar los elementos en la fila
                children: [
                  // Columna para la etiqueta y el DropdownButton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Seleccione un vendedor:", style: TextStyle(fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          hint: const Text("Seleccione vendedor", style: TextStyle(color: Colors.grey)), // Estilo del hint
                          value: _usuarioSeleccionado, // Valor seleccionado
                          items: _usuarios.map((usuario) {
                            return DropdownMenuItem<String>(
                              value: usuario['ID_USUARIO'].toString(), // Suponiendo que tienes un campo 'id'
                              child: Center( // Centrar el texto dentro del DropdownMenuItem
                                child: Text(
                                  usuario['NOMBRE_USUARIO'], // Suponiendo que tienes un campo 'nombre'
                                  style: const TextStyle(fontSize: 16), // Estilo del texto
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _usuarioSeleccionado = value; // Actualiza el usuario seleccionado
                            });
                          },
                          // Personalizando el DropdownButton
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.blue), // Icono del dropdown
                          iconSize: 24, // Tamaño del icono
                          underline: Container(
                            height: 2,
                            color: Colors.blue, // Color de la línea de subrayado
                          ),
                          isExpanded: true, // Para que el dropdown ocupe todo el ancho disponible
                          style: TextStyle(
                            color: Colors.black, // Color del texto seleccionado
                            fontSize: 16, // Tamaño del texto
                          ),
                          dropdownColor: Colors.white, // Color de fondo del dropdown
                          elevation: 4, // Elevación del dropdown
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 20), // Espacio entre el DropdownButton y las etiquetas de fecha

                  // Columna para fecha inicial
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center, // Centrar el contenido de la columna
                      mainAxisAlignment: MainAxisAlignment.center, // Centrar el contenido verticalmente
                      children: [
                        Text("Fecha Inicial:", style: TextStyle(fontWeight: FontWeight.bold)),
                        // TextField para la fecha inicial
                        Container(
                          child: TextField(
                            controller: _fechaInicialController, // Asigna el controlador
                            decoration: const InputDecoration(
                              hintText: '01/01/2024', // Indica el formato esperado
            hintStyle: TextStyle(
              color: Color.fromARGB(255, 209, 204, 204), // Cambia el color del hintText
              fontWeight: FontWeight.normal, // Cambia el peso de la fuente del hintText
            ),// Cambia el peso de la fuente del hintText
                              border: OutlineInputBorder(),
                            ),
                            textAlign: TextAlign.center, // Centrar el texto en el TextField
                            keyboardType: TextInputType.number, // Solo permitir números
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 20), // Espacio entre las fechas

                  // Columna para fecha final
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center, // Centrar el contenido de la columna
                      mainAxisAlignment: MainAxisAlignment.center, // Centrar el contenido verticalmente
                      children: [
                        Text("Fecha Final:", style: TextStyle(fontWeight: FontWeight.bold)),
                        // TextField para la fecha final
                        Container(
                          child: TextField(
                            controller: _fechaFinalController, // Asigna el controlador
                            decoration: InputDecoration(
                              hintText: '01/01/2024', // Indica el formato esperado
                                          hintStyle: TextStyle(
              color: Color.fromARGB(255, 209, 204, 204), // Cambia el color del hintText
              fontWeight: FontWeight.normal, // Cambia el peso de la fuente del hintText
            ),
                              border: OutlineInputBorder(),
                            ),
                            textAlign: TextAlign.center, // Centrar el texto en el TextField
                            keyboardType: TextInputType.number, // Solo permitir números
                          ),
                        ),
                      ],
                    ),
                  ),
                       SizedBox(width: 20), // Espacio entre el contenedor y el botón
     
ElevatedButton(
  onPressed: () {
    _filtrarVentas(); // Filtra las ventas al presionar el botón
  },
  style: ElevatedButton.styleFrom(
    foregroundColor: Colors.white, backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30), // Color del texto
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30), // Bordes redondeados
    ),
    elevation: 5, // Sombra
    shadowColor: Colors.black.withOpacity(0.2), // Color de sombra
  ),
  child: const Text(
    "Filtrar Ventas",
    style: TextStyle(
      fontSize: 16, // Tamaño de fuente
      fontWeight: FontWeight.bold, // Negrita
      letterSpacing: 1.2, // Espaciado entre letras
    ),
  ),
),

                ],
              ),
            ),
          ),

          SizedBox(height: 20), // Espacio entre el contenedor y el botón
// Encabezado de la tabla
Container(
  margin: const EdgeInsets.symmetric(vertical: 3),
  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
  decoration: BoxDecoration(
    color: Colors.blueAccent,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _buildTableHeaderCell('Producto', flex: 3),
      _buildTableHeaderCell('Cantidad', flex: 1),
      _buildTableHeaderCell('Tipo Venta', flex: 2),
      _buildTableHeaderCell('Precio', flex: 1),
      _buildTableHeaderCell('Fecha', flex: 2),
    ],
  ),
),

// Lista de productos
Expanded(
  child: ListView.builder(
    itemCount: _productosFiltrados.length,
    itemBuilder: (context, index) {
      final producto = _productosFiltrados[index]; // Cambiar a _productosFiltrados
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3, // Debe coincidir con el encabezado
              child: Text(
                producto.nombreProducto,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              ),
            ),
            Expanded(
              flex: 1, // Debe coincidir con el encabezado
              child: Text(
                producto.cantidad.toString(),
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2, // Debe coincidir con el encabezado
              child: Text(
                producto.tipoVenta,
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 1, // Debe coincidir con el encabezado
              child: Text(
                'S/ ${producto.precioVenta.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2, // Debe coincidir con el encabezado
              child: Text(
                producto.fecha, // Asegúrate de que la clase ProductoVenta tenga un campo 'fecha'
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    },
  ),
),

        ],
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
