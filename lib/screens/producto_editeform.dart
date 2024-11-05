import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:pharma_salud/repositories/fecha_vencimiento_repository.dart';
import 'package:pharma_salud/repositories/producto_repository.dart'; // Asegúrate de importar tu repositorio

class ProductoEditForm extends StatefulWidget {
  final int productId; // Cambiado a entero
  const ProductoEditForm({Key? key, required this.productId}) : super(key: key);

  @override
  _ProductoEditFormState createState() => _ProductoEditFormState();
  
}

class _ProductoEditFormState extends State<ProductoEditForm> {
  String tipoProducto = 'Unidad'; // Opción seleccionada por defecto
  bool hayBlister = false; // Checkbox para indicar si hay blister
  final _formKey = GlobalKey<FormState>();

    // Lista de fechas de vencimiento y sus cantidades
  List<Map<String, dynamic>> fechasVencimiento = [];
    // Controladores para los campos de fecha y cantidad
  final List<TextEditingController> _fechaControllers = [];
  final List<TextEditingController> _cantidadControllers = [];

  final ProductoRepository _productoRepository = ProductoRepository(); // Instancia del repositorio
  final FechaVencimientoRepository _fechaVencimientoRepository = FechaVencimientoRepository();

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

bool isLoading = true;

  void _agregarFechaVencimiento() {
    setState(() {
      fechasVencimiento.add({'fecha': '', 'cantidad': ''});
      _fechaControllers.add(MaskedTextController(mask: '00/00/0000'));
      _cantidadControllers.add(TextEditingController());
    });
  }

  void _eliminarFechaVencimiento(int index) {
    setState(() {
      fechasVencimiento.removeAt(index);
      _fechaControllers[index].dispose();
      _cantidadControllers[index].dispose();
      _fechaControllers.removeAt(index);
      _cantidadControllers.removeAt(index);
    });
  }

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
      // Inicializa los controladores con los datos del producto
      nombreProductoController.text = producto['Nombre_Producto'] ?? '';
      cantidadPresentacionController.text = producto['Cantidad_Presentacion']?.toString() ?? '1';

      final tipoProducto01 = producto['Tipo_Producto'];
      final cantidadTotal = producto['Cantidad_Total'] ?? 0;
      final cantidadPresentacion = producto['Cantidad_Presentacion'] ?? 1;

      // Calcular stock en cajas y unidades
      final stockCaja = (tipoProducto01 == 'Caja') ? (cantidadTotal / cantidadPresentacion).floor() : 0;
      final stockUnidad = (tipoProducto01 == 'Caja') ? cantidadTotal % cantidadPresentacion : cantidadTotal;

      // Asigna los valores calculados a los controladores de texto
      stockCajaController.text = stockCaja.toString();
      stockUnidadController.text = stockUnidad.toString();
      precioUnidadController.text = producto['Precio_Unidad']?.toString() ?? '0';
      precioCajaController.text = producto['Precio_Caja']?.toString() ?? '0';
if (producto['Tipo_Producto'] == 'Caja') {
  costoProductoController.text = producto['Costo_Caja']?.toString() ?? '0';
} else {
  costoProductoController.text = producto['Costo_Unidad']?.toString() ?? '0';
}
      stockMinimoController.text = producto['Stock_Minimo']?.toString() ?? '0';
      cantidadPresentacionBlisterController.text = producto['Cantidad_Presentacion_blister']?.toString() ?? '0';
      precioBlisterController.text = producto['Precio_Blister']?.toString() ?? '0';
      hayBlister = producto['Blister_SiNo'] == 1;

      // Establecer el tipo de producto
      tipoProducto = tipoProducto01;
    }
  } catch (e) {
    // Manejar el error
    print("Error al cargar el producto: $e");
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

Future<void> _loadFechasVencimiento() async {
  try {
    // Obtener las fechas de vencimiento desde la base de datos
    final fechas = await _fechaVencimientoRepository.getFechasVencimientoByProductoId(widget.productId);

    if (fechas.isNotEmpty) {
      // Asignar las fechas obtenidas a la lista de fechas de vencimiento
      fechasVencimiento = fechas.map((fecha) {
        return {
          'fecha': fecha['Fecha_Vencimiento'],
          'cantidad': fecha['Cantidad']
        };
      }).toList();

      // Limpiar los controladores previos para evitar inconsistencias
      _fechaControllers.clear();
      _cantidadControllers.clear();

      // Crear nuevos controladores para cada fecha obtenida
      for (var fecha in fechasVencimiento) {
        _fechaControllers.add(MaskedTextController(mask: '00/00/0000')..text = fecha['fecha']);
        _cantidadControllers.add(TextEditingController()..text = fecha['cantidad'].toString());
      }
    }
  } catch (e) {
    print("Error al cargar las fechas de vencimiento: $e");
  } finally {
    setState(() {});
  }
}


  @override
  Widget build(BuildContext context) {
return Scaffold(
  body: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 255, 4, 0), // Color rojo más claro
              const Color.fromARGB(255, 174, 0, 0), // Color rojo oscuro
            ],
            begin: Alignment.topCenter, // Comienza en el centro superior
            end: Alignment.bottomCenter, // Termina en el centro inferior
      ),
    ),
    child: Center(
      child: isLoading
          ? CircularProgressIndicator() // Mostrar el indicador de carga si los datos aún se están cargando
          : Container(
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
                          'Editar Producto',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
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
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Unidad',
                                  style: TextStyle(fontSize: 14)),
                              value: 'Unidad',
                              groupValue: tipoProducto,
                              onChanged: (value) {
                                _confirmChangeTipoProducto(value!);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Caja',
                                  style: TextStyle(fontSize: 14)),
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
              onPressed: _agregarFechaVencimiento,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        Column(
          children: List.generate(fechasVencimiento.length, (index) {
            final fechaController = _fechaControllers[index];
            final cantidadController = _cantidadControllers[index];

            fechaController.text = fechasVencimiento[index]['fecha'] ?? '';
            cantidadController.text = fechasVencimiento[index]['cantidad'].toString();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: fechaController,
                      decoration: InputDecoration(
                        labelText: 'Día/Mes/Año',
                        hintText: '01/01/2025',
                            hintStyle: const TextStyle(
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
    controller: cantidadController,
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
        // Actualiza la cantidad en la lista de fechasVencimiento
                          fechasVencimiento[index]['cantidad'] = value.isEmpty
                              ? ''
                              : int.tryParse(value) ?? 0;
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
                    onPressed: () => _eliminarFechaVencimiento(index),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white, // Esto establece el color del texto a blanco
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _saveProduct();
                            }
                          },
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

  void _confirmChangeTipoProducto(String value) {
    setState(() {
      tipoProducto = value;
    });
  }

Future<void> _saveProduct() async {
  final cantidadPresentacion = tipoProducto == 'Caja' ? int.tryParse(cantidadPresentacionController.text) ?? 1 : 1;
  final stockCaja = int.tryParse(stockCajaController.text) ?? 0;
  final stockUnidad = int.tryParse(stockUnidadController.text) ?? 0;
  final costoCaja = double.tryParse(costoProductoController.text) ?? 0.0;

  // Validar que los campos necesarios tengan valores válidos
  if (!_validarCamposObligatorios()) {
    return;
  }

  final productoActualizado = _crearProductoActualizado(
    cantidadPresentacion: cantidadPresentacion,
    stockCaja: stockCaja,
    stockUnidad: stockUnidad,
    costoCaja: costoCaja,
  );

  try {
    // Actualizar el producto en el repositorio
    await _productoRepository.updateProducto(productoActualizado);

    // 5. Eliminar las fechas de vencimiento antiguas
    await _fechaVencimientoRepository.deleteFechaVencimientoPorProductoId(widget.productId);

      // Agregar las fechas de vencimiento de la variable local
      for (final fecha in fechasVencimiento) {
        await _fechaVencimientoRepository.insertFechaVencimiento(widget.productId, fecha['fecha'], fecha['cantidad']);
      }

      // Limpiar los controladores solo si todo fue exitoso
      _limpiarControladores();

    // Regresar a la pantalla anterior
    Navigator.pop(context);
  } catch (e) {
    // Manejo de errores
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al actualizar el producto: $e')),
    );
  }
}

bool _validarCamposObligatorios() {
  if (nombreProductoController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('El nombre del producto es obligatorio.')),
    );
    return false;
  }
  // Añadir más validaciones si hay otros campos obligatorios.
  return true;
}

Map<String, dynamic> _crearProductoActualizado({
  required int cantidadPresentacion,
  required int stockCaja,
  required int stockUnidad,
  required double costoCaja,
}) {
  return {
    'ID': widget.productId,
    'Nombre_Producto': nombreProductoController.text,
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
}

void _limpiarControladores() {
  nombreProductoController.clear();
  cantidadPresentacionController.clear();
  cantidadPresentacionBlisterController.clear();
  stockCajaController.clear();
  stockUnidadController.clear();
  precioUnidadController.clear();
  precioCajaController.clear();
  precioBlisterController.clear();
  costoProductoController.clear();
  stockMinimoController.clear();
  fechasVencimiento.clear();
}

  // Métodos auxiliares para construir campos de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      validator: validator,
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

  @override
void dispose() {
  // Limpiar todos los controladores para asegurarse de que estén vacíos al retroceder
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
  // Liberar los recursos utilizados por los controladores
  for (var controller in _fechaControllers) {
      controller.dispose();
  }
  for (var controller in _cantidadControllers) {
      controller.dispose();
  }
  super.dispose();
}
}