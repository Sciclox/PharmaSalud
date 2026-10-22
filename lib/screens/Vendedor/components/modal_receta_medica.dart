import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecetaMedicaModal extends StatefulWidget {
  final Map<String, dynamic> producto;

  const RecetaMedicaModal({super.key, required this.producto});

  /// Muestra el modal de advertencia de medicamento con receta médica.
  /// Retorna `true` si la técnica confirma que tiene receta y desea proceder con la venta.
  /// Retorna `false` si se cancela.
  static Future<bool> show(
      BuildContext context, Map<String, dynamic> producto) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecetaMedicaModal(producto: producto),
    );
    return result ?? false;
  }

  @override
  State<RecetaMedicaModal> createState() => _RecetaMedicaModalState();
}

class _RecetaMedicaModalState extends State<RecetaMedicaModal> {
  final FocusNode _confirmFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confirmFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop(false);
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreProducto =
        widget.producto['Nombre_Producto']?.toString() ?? 'Producto';
    final tipoProducto =
        widget.producto['Tipo_Producto']?.toString() ?? 'Unidad';
    final prodId = widget.producto['ID']?.toString().padLeft(4, '0') ?? '0000';

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono e Identificador Superior
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Color(0xFFD97706),
                        size: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock_rounded,
                              size: 13, color: Color(0xFFD97706)),
                          SizedBox(width: 5),
                          Text(
                            'CONTROLADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                              letterSpacing: 0.8,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Título y Subtítulo
                const Text(
                  'Medicamento con Receta Médica',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D1D1F),
                    letterSpacing: -0.4,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Este producto está sujeto a fiscalización y requiere verificación obligatoria de prescripción médica.',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                    height: 1.4,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 18),

                // Tarjeta de Detalle del Producto
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1D1D1F).withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreProducto,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D1D1F),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'REF: PS-$prodId • Presentación: $tipoProducto',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF1D1D1F).withValues(alpha: 0.45),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Cuadro de Advertencia
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFDE68A),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verifique que la receta médica esté vigente, firmada y sellada por el profesional de salud correspondiente antes de concretar la venta.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF92400E),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Acciones
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1D1D1F),
                          side: BorderSide(
                              color: const Color(0xFF1D1D1F).withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        focusNode: _confirmFocusNode,
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 18, color: Colors.white),
                        label: const Text(
                          'TIENE RECETA / PROCEDER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
