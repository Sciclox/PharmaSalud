import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:pharma_salud/repositories/fecha_vencimiento_repository.dart';
import 'package:pharma_salud/repositories/producto_repository.dart'; // Asegúrate de importar tu repositorio

class FormularioProducto extends StatefulWidget {
  @override
  _FormularioProductoState createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  String tipoProducto = 'Unidad'; // Opción seleccionada por defecto
  bool hayBlister = false; // Checkbox para indicar si hay blister
  final _formKey = GlobalKey<FormState>();
  
    // Lista de fechas de vencimiento y sus cantidades
  List<Map<String, dynamic>> fechasVencimiento = [];

  final ProductoRepository _productoRepository = ProductoRepository(); // Instancia del repositorio

  // Controladores de texto
  TextEditingController nombreProductoController = TextEditingController();
  TextEditingController cantidadPresentacionController = TextEditingController();
  TextEditingController cantidadPresentacionBlisterController = TextEditingController();
  TextEditingController stockCajaController = TextEditingController();
  TextEditingController stockUnidadController = TextEditingController();
  TextEditingController precioUnidadController = TextEditingController();
  TextEditingController precioCajaController = TextEditingController();
  TextEditingController precioBlisterController = TextEditingController();
  TextEditingController costoProductoController = TextEditingController(); // Campo para costo del producto
  TextEditingController stockMinimoController = TextEditingController();

  // Imagen del producto
  String? imagenProducto;


Future<void> _guardarProducto() async {
  if (_formKey.currentState!.validate()) {
    // Recopilar datos del formulario
    final cantidadPresentacion = tipoProducto == 'Caja' ? int.parse(cantidadPresentacionController.text) : 1;
    final stockCaja = int.tryParse(stockCajaController.text) ?? 0;
    final stockUnidad = int.tryParse(stockUnidadController.text) ?? 0;
    final costoCaja = double.tryParse(costoProductoController.text) ?? 0.0;

    // Crear un mapa con los datos del producto
    final producto = {
      'Nombre_Producto': nombreProductoController.text,
      'Fecha_Creacion': DateTime.now().toIso8601String(),
      'Cantidad_Presentacion': cantidadPresentacion,
      'Tipo_Producto': tipoProducto,
      'Precio_Unidad': double.tryParse(precioUnidadController.text) ?? 0.0,
      'Precio_Caja': double.tryParse(precioCajaController.text) ?? 0.0,
      'Costo_Caja': tipoProducto == 'Caja' ? costoCaja : 0.0,
      'Costo_Unidad': tipoProducto == 'Caja'
          ? (costoCaja / (cantidadPresentacion > 0 ? cantidadPresentacion : 1))
          : (double.tryParse(costoProductoController.text) ?? 0.0),
      'Cantidad_Total': tipoProducto == 'Caja'
          ? (stockCaja * cantidadPresentacion) + stockUnidad
          : stockUnidad,
      'Stock_Minimo': int.tryParse(stockMinimoController.text) ?? 0,
      'Cantidad_Presentacion_blister': int.tryParse(cantidadPresentacionBlisterController.text) ?? 0,
      'Precio_Blister': double.tryParse(precioBlisterController.text) ?? 0.0,
      'Blister_SiNo': hayBlister ? 1 : 0,
    };

    // Crear el producto en la base de datos y obtener el ID
    final productoId = await _productoRepository.createProducto(producto);

    if (productoId! > 0) { // Verifica que el ID sea válido
      // Guardar fechas de vencimiento
      for (var fecha in fechasVencimiento) {
        await _insertFechaVencimiento(productoId, fecha['fecha'], fecha['cantidad']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto y fechas de vencimiento guardados exitosamente')),
      );

      // Reiniciar el formulario y limpiar campos
      _formKey.currentState!.reset();
      nombreProductoController.clear();
      cantidadPresentacionController.clear();
      stockCajaController.clear();
      stockUnidadController.clear();
      precioUnidadController.clear();
      precioCajaController.clear();
      costoProductoController.clear();
      stockMinimoController.clear();
      cantidadPresentacionBlisterController.clear();
      precioBlisterController.clear();
      fechasVencimiento.clear();

      // Volver a la pantalla anterior
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear el producto')),
      );
    }
  }
}



Future<void> _insertFechaVencimiento(int productoId, String fechaVencimiento, int cantidad) async {
  // Verifica si los datos de entrada son válidos
  if (productoId <= 0 || cantidad <= 0 || fechaVencimiento.isEmpty) {
    throw Exception('Datos inválidos para la fecha de vencimiento');
  }

  try {
    // Llama al repositorio para insertar la fecha de vencimiento
    FechaVencimientoRepository repository = FechaVencimientoRepository();
    await repository.insertFechaVencimiento(productoId, fechaVencimiento, cantidad);

    print("Fecha de vencimiento insertada correctamente");
  } catch (e) {
    // Manejo de errores
    print("Error al insertar la fecha de vencimiento: $e");
  }
}

  @override
  Widget build(BuildContext context) {
return Scaffold(
  body: Container(
    // Este contenedor ocupa todo el cuerpo del Scaffold
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
              const Color.fromARGB(255, 255, 4, 0), // Color rojo más claro
              const Color.fromARGB(255, 174, 0, 0), // Color rojo oscuro
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Center(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 5.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                // Título del formulario
                Center(
                  child: const Text(
                    'Registro de Producto',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // Nombre del producto
                _buildTextField(
                  controller: nombreProductoController,
                  label: 'Nombre del Producto',
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Por favor ingresa el nombre del producto'
                      : null,
                  onChanged: (value) {
                    nombreProductoController.value = TextEditingValue(
                      text: value.toUpperCase(),
                      selection: nombreProductoController.selection,
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Selección entre Unidad o Caja
                const Text('Tipo de Producto',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Unidad', style: TextStyle(fontSize: 14)),
                        value: 'Unidad',
                        groupValue: tipoProducto,
                        onChanged: (value) {
                          _confirmChangeTipoProducto(value!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Caja', style: TextStyle(fontSize: 14)),
                        value: 'Caja',
                        groupValue: tipoProducto,
                        onChanged: (value) {
                          _confirmChangeTipoProducto(value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Mostrar campos dependiendo del tipo de producto
                if (tipoProducto == 'Caja') ...[
                  _buildNumberTextField(
                    controller: cantidadPresentacionController,
                    label: 'Cantidad de presentación de caja',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa la cantidad por caja'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _buildNumberTextField(
                    controller: stockCajaController,
                    label: 'Stock Caja',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa el stock en cajas'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _buildNumberTextField(
                    controller: stockUnidadController,
                    label: 'Stock Unidad',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa la cantidad por unidad'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _buildDecimalTextField(
                    controller: precioCajaController,
                    label: 'Precio Caja',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa el precio de la caja'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _buildDecimalTextField(
                    controller: precioUnidadController,
                    label: 'Precio Unidad',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa el precio de la unidad'
                        : null,
                  ),
                ] else ...[
                  _buildNumberTextField(
                    controller: stockUnidadController,
                    label: 'Stock Unidad',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa el stock en unidades'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _buildDecimalTextField(
                    controller: precioUnidadController,
                    label: 'Precio Unidad',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Por favor ingresa el precio de la unidad'
                        : null,
                  ),
                ],
                const SizedBox(height: 10),
                _buildDecimalTextField(
                  controller: costoProductoController,
                  label: 'Costo Producto',
                  validator: (value) => value == null || value.isEmpty
                      ? 'Por favor ingresa el costo del producto'
                      : null,
                ),
                const SizedBox(height: 10),
                _buildNumberTextField(
                  controller: stockMinimoController,
                  label: 'Stock Mínimo',
                ),
                const SizedBox(height: 10),
                // Checkbox para indicar si hay blister
if (tipoProducto == 'Caja') ...[
  Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(4.0),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Activelo si vendera por blister',
          style: TextStyle(fontSize: 16),
        ),
        Switch(
          value: hayBlister,
          onChanged: (value) {
            setState(() {
              hayBlister = value;
              if (hayBlister) {
                cantidadPresentacionBlisterController.clear();
                precioBlisterController.clear();
              }
            });
          },
        ),
      ],
    ),
  ),
  const SizedBox(height: 10),
  if (hayBlister) ...[
    _buildNumberTextField(
      controller: cantidadPresentacionBlisterController,
      label: 'Cantidad Presentación Blister',
      validator: (value) => value == null || value.isEmpty
          ? 'Por favor ingresa la cantidad de presentación por blister'
          : null,
    ),
    const SizedBox(height: 10),
    _buildDecimalTextField(
      controller: precioBlisterController,
      label: 'Precio Blister',
            validator: (value) => value == null || value.isEmpty
          ? 'Por favor ingresa el precio por blister'
          : null,
    ),
  ],
],

// Campos para registrar fechas de vencimiento y cantidades
// Fila para el texto y el icono de agregar
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fechas de Vencimiento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: const BorderSide(color: Colors.red),
                ),
                padding: const EdgeInsets.all(0),
              ),
              onPressed: () {
                setState(() {
                  fechasVencimiento.add({'fecha': '', 'cantidad': 0});
                });
              },
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        Column(
          children: fechasVencimiento.map((fecha) {
            int index = fechasVencimiento.indexOf(fecha);

            // Controlador para el campo de fecha
            final _fechaController = MaskedTextController(mask: '00/00/0000');

            // Inicializa el controlador con la fecha actual
            if (fecha['fecha'].isNotEmpty) {
              _fechaController.text = fecha['fecha'];
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fechaController,
                      decoration: InputDecoration(
                        labelText: 'Día/Mes/Año',
                        hintText: '01/01/2025',
                            hintStyle: TextStyle(
      color: Colors.grey, // Puedes cambiar el color si lo deseas
      fontWeight: FontWeight.normal, // Asegúrate de que sea normal
    ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          fechasVencimiento[index]['fecha'] = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty || !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value)) {
                          return 'Por favor ingresa una fecha válida (dd/mm/yyyy)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
Expanded(
  child: TextFormField(
    decoration: InputDecoration(
      labelText: 'Cantidad',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4.0),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
    ),
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly, // Permitir solo dígitos
    ],
    onChanged: (value) {
      setState(() {
        fechasVencimiento[index]['cantidad'] = int.tryParse(value) ?? 0;
      });
    },
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Por favor ingresa la cantidad';
      }
      return null;
    },
  ),
),

                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        fechasVencimiento.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        ),

const SizedBox(height: 20),

                // Botón de guardar
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _guardarProducto,
                    child: const Text('Guardar Producto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

  }

  // Método para confirmar el cambio de tipo de producto
  void _confirmChangeTipoProducto(String value) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Seguro de cambiar el tipo de producto'),
          content: const Text('Se borraran los campos'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  tipoProducto = value;
                  Navigator.of(context).pop();
                });
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Métodos para crear los campos del formulario
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
      ),
      validator: validator,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
    );
  }

  Widget _buildNumberTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
    );
  }

  Widget _buildDecimalTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      validator: validator,
    );
  }

}
