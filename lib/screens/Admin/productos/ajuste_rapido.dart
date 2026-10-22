import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AjusteRapidoModal extends StatefulWidget {
  final Map<String, dynamic> producto;

  const AjusteRapidoModal({super.key, required this.producto});

  @override
  _AjusteRapidoModalState createState() => _AjusteRapidoModalState();
}

class _AjusteRapidoModalState extends State<AjusteRapidoModal> {
  final ProductoRepository _productoRepo = ProductoRepository();
  final KardexRepository _kardexRepo = KardexRepository();

  bool _isAdding = true; 
  final TextEditingController _cajaController = TextEditingController();
  final TextEditingController _unidadController = TextEditingController();

  bool _isLoading = false;
  String _errorMsg = '';

  // Theme Colors Light Version
  final Color bgLight = Colors.white;
  final Color surfaceLight = const Color(0xFFF5F5F7);
  final Color textDark = const Color(0xFF1D1D1F);
  final Color colAdd = const Color(0xFF00C853); // Mint Green
  final Color colRem = const Color(0xFFFF3B30); // Apple-like red

  @override
  void dispose() {
    _cajaController.dispose();
    _unidadController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    int cajas = int.tryParse(_cajaController.text) ?? 0;
    int unidades = int.tryParse(_unidadController.text) ?? 0;

    int pres = widget.producto['Cantidad_Presentacion'] ?? 1;
    String tipo = widget.producto['Tipo_Producto'] ?? 'Unidad';
    String nombre = widget.producto['Nombre_Producto'] ?? 'Producto';
    int productId = widget.producto['ID'] ?? widget.producto['ID_Producto'];

    int diff = (tipo == 'Caja') ? (cajas * pres) + unidades : unidades;

    if (diff <= 0) {
      setState(() => _errorMsg = 'Ingresa una cantidad mayor a 0');
      return;
    }

    int currentTotal = widget.producto['Cantidad_Total'] ?? 0;
    int newTotal = _isAdding ? currentTotal + diff : currentTotal - diff;

    if (newTotal < 0) {
      setState(() => _errorMsg = 'El stock final no puede quedar en negativo');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      if (_isAdding) {
        await _productoRepo.aumentarCantidadTotal(productId, diff);
      } else {
        await _productoRepo.descontarCantidadTotal(productId, diff);
      }

      final hoy = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final adminRealName = prefs.getString('adminName') ?? "Administrador";

      await _kardexRepo.insertKardexEntry({
        'NOMBRE_PRODUCTO': nombre.toUpperCase(),
        'FECHA_MOVIMIENTO': "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')} ${hoy.hour.toString().padLeft(2, '0')}:${hoy.minute.toString().padLeft(2, '0')}:${hoy.second.toString().padLeft(2, '0')}",
        'TIPO_MOVIMIENTO': _isAdding ? 'Ingreso' : 'Salida',
        'CANTIDAD': diff,
        'USUARIO': adminRealName,
        'STOCK_ANTERIOR': currentTotal,
        'STOCK_RESULTANTE': newTotal,
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inventario actualizado', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: colAdd,
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Error al actualizar: $e';
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textDark.withOpacity(0.4),
            letterSpacing: 1,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: textDark,
            fontFamily: 'Outfit',
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 28,
              color: textDark.withOpacity(0.1),
              fontFamily: 'Outfit',
            ),
            filled: true,
            fillColor: surfaceLight,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isAdding ? colAdd : colRem,
                width: 2
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = widget.producto['Cantidad_Total'] ?? 0;
    int pres = widget.producto['Cantidad_Presentacion'] ?? 1;
    final tipo = widget.producto['Tipo_Producto'] ?? 'Unidad';

    int sCaja = (tipo == 'Caja') ? (total / pres).floor() : 0;
    int sUni = (tipo == 'Caja') ? (total % pres) : total;
    
    String strCaja = sCaja == 1 ? 'Caja' : 'Cajas';
    String strUni = sUni == 1 ? 'Unidad' : 'Unidades';
    String stockStr = tipo == 'Caja' ? '$sCaja $strCaja / $sUni $strUni' : '$sUni $strUni';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: bgLight,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: (_isAdding ? colAdd : colRem).withOpacity(0.05),
              blurRadius: 100,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AJUSTE DE STOCK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textDark.withOpacity(0.4),
                            fontFamily: 'Outfit',
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.producto['Nombre_Producto'] ?? '',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textDark),
                    style: IconButton.styleFrom(
                      backgroundColor: surfaceLight,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Current Stock Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: textDark.withOpacity(0.5), size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Disponible actualmente:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textDark.withOpacity(0.5),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        stockStr,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          fontFamily: 'Outfit',
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Custom Tabs
              Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() { _isAdding = true; _errorMsg = ''; }),
                        child: Column(
                          children: [
                            Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _isAdding ? colAdd : textDark.withOpacity(0.3),
                                fontFamily: 'Outfit',
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 3,
                              decoration: BoxDecoration(
                                color: _isAdding ? colAdd : surfaceLight,
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: _isAdding ? [BoxShadow(color: colAdd.withOpacity(0.5), blurRadius: 4)] : [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() { _isAdding = false; _errorMsg = ''; }),
                        child: Column(
                          children: [
                            Text(
                              'QUITAR',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: !_isAdding ? colRem : textDark.withOpacity(0.3),
                                fontFamily: 'Outfit',
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 3,
                              decoration: BoxDecoration(
                                color: !_isAdding ? colRem : surfaceLight,
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: !_isAdding ? [BoxShadow(color: colRem.withOpacity(0.5), blurRadius: 4)] : [],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              if (tipo == 'Caja') ...[
                Row(
                  children: [
                    Expanded(child: _buildTextField('Cajas', _cajaController)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Unidades', _unidadController)),
                  ],
                ),
              ] else ...[
                _buildTextField('Unidades', _unidadController),
              ],

              if (_errorMsg.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colRem.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colRem.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colRem, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMsg,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colRem,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 8),
              
              // Action Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _isAdding 
                      ? [colAdd, const Color(0xFF00B259)] 
                      : [colRem, const Color(0xFFD32F2F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isAdding ? colAdd : colRem).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: _isLoading ? null : _guardar,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                      : Text(
                          _isAdding ? 'APLICAR INGRESO' : 'APLICAR SALIDA',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontFamily: 'Outfit',
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

