import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/kardex.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:intl/intl.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});

  @override
  _KardexScreenState createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  List<Map<String, dynamic>> _kardexList = [];
  bool _isLoading = false;

  final KardexRepository _repository = KardexRepository();

  final List<String> _movementTypes = [
    'Todos',
    'Registro',
    'Ingreso',
    'Salida',
    'Venta por unidad',
    'Venta por blister',
    'Venta por caja',
    'Devuelto',
    'Devolución',
    'Ajuste de Inventario',
    'Eliminado'
  ];

  String? _selectedMovementType = 'Todos';

  @override
  void initState() {
    super.initState();

    final hoy = DateTime.now();
    _dateController.text =
        "${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year}";

    _nameController.addListener(_handleFilterChange);
    _dateController.addListener(_handleFilterChange);

    _searchKardex();
  }

  void _handleFilterChange() {
    _searchKardex();
  }

  Future<void> _searchKardex() async {
    final nameQuery = _nameController.text.trim();
    final dateQuery = _dateController.text.trim();
    final typeQuery =
        (_selectedMovementType == 'Todos') ? null : _selectedMovementType;

    setState(() => _isLoading = true);

    String dateIso = "";
    if (dateQuery.length == 10) {
      List<String> parts = dateQuery.split('/');
      dateIso = "${parts[2]}-${parts[1]}-${parts[0]}";
    }

    try {
      _kardexList = await _repository.getKardexByFilters(
        productName: nameQuery.isNotEmpty ? nameQuery : null,
        date: dateIso.isNotEmpty ? dateIso : null,
        movementType: (typeQuery != null &&
                typeQuery != 'Devuelto' &&
                typeQuery != 'Devolución' &&
                typeQuery != 'Ajuste de Inventario')
            ? typeQuery
            : null,
        soloDevueltos: typeQuery == 'Devuelto' || typeQuery == 'Devolución',
        soloAjustes: typeQuery == 'Ajuste de Inventario',
      );
    } catch (e) {
      print('Error al buscar en KARDEX: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Minimalista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Kardex General',
                          style: TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'Historial completo de movimientos de inventario',
                        style: TextStyle(
                          color: const Color(0xFF1D1D1F).withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
                // Badge Total Movimientos
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'MOVIMIENTOS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF3B30).withOpacity(0.8),
                          letterSpacing: 1.1,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      Text(
                        '${_kardexList.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF3B30),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Barra Unificada de Filtros
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 1. Buscador por Nombre (Expanded)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Producto',
                              style: TextStyle(
                                color: const Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: KeyFocusWrapper(
                                bindings: {LogicalKeyboardKey.f1: _nameFocusNode},
                                actions: {LogicalKeyboardKey.escape: () => _nameController.clear()},
                                child: TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar por nombre...',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.4),
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: const Color(0xFF1D1D1F)
                                              .withOpacity(0.05)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: const Color(0xFF1D1D1F)
                                              .withOpacity(0.05)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 0),
                                    prefixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 12),
                                        Icon(Icons.search_rounded,
                                            size: 18,
                                            color: const Color(0xFF1D1D1F)
                                                .withOpacity(0.4)),
                                        const SizedBox(width: 6),
                                        const F1Badge(label: 'F1'),
                                      ],
                                    ),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1D1D1F)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 2. Filtro Fecha (Fixed)
                      SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Fecha',
                              style: TextStyle(
                                color: const Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _dateController,
                                readOnly: true,
                                mouseCursor: SystemMouseCursors.click,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'dd/mm/aaaa',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF1D1D1F)
                                        .withOpacity(0.4),
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F5F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.05)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: const Color(0xFF1D1D1F)
                                            .withOpacity(0.05)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  suffixIcon: Icon(Icons.calendar_month_rounded,
                                      size: 16,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                                ),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1D1D1F)),
                                onTap: () async {
                                  final date = await showAppDatePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    _dateController.text = DateFormat('dd/MM/yyyy').format(date);
                                    _searchKardex();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 3. Dropdown Tipo Movimiento (Flexible)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tipo Movimiento',
                              style: TextStyle(
                                color: const Color(0xFF1D1D1F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: CustomDropdown<String>(
                                hintText: 'Todos',
                                items: _movementTypes,
                                initialItem: _selectedMovementType,
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedMovementType = newValue;
                                  });
                                  _handleFilterChange();
                                },
                                decoration: CustomDropdownDecoration(
                                  closedFillColor: const Color(0xFFF5F5F7),
                                  expandedFillColor: Colors.white,
                                  closedBorder: Border.all(
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.05)),
                                  closedBorderRadius: BorderRadius.circular(10),
                                  expandedBorderRadius: BorderRadius.circular(10),
                                  hintStyle: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  headerStyle: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: Color(0xFF1D1D1F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  listItemStyle: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: Color(0xFF1D1D1F),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 4. Botón Limpiar
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D1F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () {
                            _nameController.clear();
                            _dateController.clear();
                            setState(() {
                              _selectedMovementType = 'Todos';
                            });
                            _handleFilterChange();
                          },
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                          tooltip: 'Limpiar filtros',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cabecera Tabla
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 6,
                      child: _tableHeader('PRODUCTO', align: TextAlign.start)),
                  Expanded(
                      flex: 4, child: Center(child: _tableHeader('FECHA'))),
                  Expanded(flex: 7, child: Center(child: _tableHeader('TIPO'))),
                  Expanded(
                      flex: 3, child: Center(child: _tableHeader('STOCK ANT.'))),
                  Expanded(
                      flex: 3, child: Center(child: _tableHeader('CANTIDAD'))),
                  Expanded(
                      flex: 3, child: Center(child: _tableHeader('STOCK FINAL'))),
                  Expanded(
                      flex: 4, child: Center(child: _tableHeader('USUARIO'))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista y Resultados
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : _kardexList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.filter_list_off_rounded,
                                  size: 64,
                                  color:
                                      const Color(0xFF1D1D1F).withOpacity(0.1)),
                              const SizedBox(height: 16),
                              const Text(
                                'Sin movimientos encontrados',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D1D1F)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Prueba ajustando los filtros de búsqueda',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    color: const Color(0xFF1D1D1F)
                                        .withOpacity(0.4)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: _kardexList.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          itemBuilder: (context, index) {
                            final item = _kardexList[index];
                            final int? stockAnt = item['STOCK_ANTERIOR'] ?? item['STOCK_SISTEMA'];
                            final int? stockFin = item['STOCK_RESULTANTE'] ?? 
                                ((item['CONTEO_FISICO'] != null && item['CONTEO_FISICO'] > 0) ? item['CONTEO_FISICO'] : null);
                            return Material(
                              color: Colors.white,
                              borderRadius:
                                  (index == 0 && _kardexList.length == 1)
                                      ? BorderRadius.circular(12)
                                      : index == 0
                                          ? const BorderRadius.vertical(
                                              top: Radius.circular(12))
                                          : index == _kardexList.length - 1
                                              ? const BorderRadius.vertical(
                                                  bottom: Radius.circular(12))
                                              : BorderRadius.zero,
                              child: InkWell(
                                onTap: () {},
                                hoverColor:
                                    const Color(0xFFFF3B30).withOpacity(0.08),
                                borderRadius:
                                    (index == 0 && _kardexList.length == 1)
                                        ? BorderRadius.circular(12)
                                        : index == 0
                                            ? const BorderRadius.vertical(
                                                top: Radius.circular(12))
                                            : index == _kardexList.length - 1
                                                ? const BorderRadius.vertical(
                                                    bottom: Radius.circular(12))
                                                : BorderRadius.zero,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Row(
                                    children: [
                                      // Producto
                                      Expanded(
                                        flex: 6,
                                        child: Text(
                                          item['NOMBRE_PRODUCTO'] ??
                                              'Sin nombre',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF1D1D1F),
                                              fontFamily: 'Outfit'),
                                        ),
                                      ),
                                      // Fecha
                                      Expanded(
                                        flex: 4,
                                        child: Center(
                                          child: Text(
                                            _formatFecha(
                                                item['FECHA_MOVIMIENTO'] ?? ''),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: const Color(0xFF1D1D1F)
                                                    .withOpacity(0.7),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      // Tipo
                                      Expanded(
                                        flex: 7,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getColorForType(
                                                      item['TIPO_MOVIMIENTO'] ??
                                                          '')
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item['TIPO_MOVIMIENTO'] ??
                                                        'Sin tipo',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _getColorForType(
                                                            item['TIPO_MOVIMIENTO'] ??
                                                                ''),
                                                        fontFamily: 'Outfit'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Stock Anterior
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            _getFormattedStock(stockAnt, item),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1D1D1F)
                                                    .withOpacity(0.6),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      // Cantidad
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            _getFormattedQuantity(item),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D1D1F),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      // Stock Final
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: Text(
                                            _getFormattedStock(stockFin, item),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF007AFF),
                                                fontFamily: 'Outfit'),
                                          ),
                                        ),
                                      ),
                                      // Usuario
                                      Expanded(
                                        flex: 4,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person_outline_rounded,
                                                  size: 14,
                                                  color: const Color(0xFF1D1D1F)
                                                      .withOpacity(0.4)),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  item['USUARIO'] ??
                                                      'Desconocido',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: const Color(
                                                              0xFF1D1D1F)
                                                          .withOpacity(0.6),
                                                      fontFamily: 'Outfit'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
        ),
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.center}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D1D1F).withOpacity(0.3),
        letterSpacing: 1.2,
        fontFamily: 'Outfit',
      ),
    );
  }

  Color _getColorForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('devolución') || lower.contains('devolucion') || lower == 'devuelto') {
      return const Color(0xFF34C759);
    }
    switch (lower) {
      case 'registro':
        return const Color(0xFF007AFF);
      case 'ingreso':
        return const Color(0xFF34C759);
      case 'salida':
      case 'eliminado':
        return const Color(0xFFFF3B30);
      case 'venta por unidad':
        return const Color(0xFF5856D6);
      case 'venta por caja':
        return const Color(0xFFAF52DE);
      case 'venta por blister':
        return const Color(0xFFFF9500);
      case 'ajuste inventario (+)':
      case 'ajuste inventario (-)':
      case 'ajuste de inventario':
        return const Color(0xFF8E8E93);
      case 'ajuste inventario (conforme)':
      case 'conforme':
        return const Color(0xFF34C759);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String _formatFecha(String fecha) {
    if (fecha.contains('-')) {
      try {
        DateTime parsed = DateTime.parse(fecha);
        String fechaStr = "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}";
        if (parsed.hour > 0 || parsed.minute > 0 || parsed.second > 0) {
          int hour12 = parsed.hour % 12;
          if (hour12 == 0) hour12 = 12;
          String amPm = parsed.hour >= 12 ? 'PM' : 'AM';
          fechaStr += '\n${hour12.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')} $amPm';
        }
        return fechaStr;
      } catch (e) {
        return fecha;
      }
    }
    return fecha;
  }

  String _getFormattedQuantity(Map<String, dynamic> item) {
    int cantidadTotal = item['CANTIDAD'] ?? 0;
    String tipo = (item['TIPO_MOVIMIENTO'] ?? '').toString();
    int unitsPerBox = item['Cantidad_Presentacion'] ?? 1;
    int unitsPerBlister = item['Cantidad_Presentacion_blister'] ?? 1;

    String tipoLower = tipo.toLowerCase();

    if (tipoLower.contains('caja')) {
      int units = unitsPerBox > 0 ? unitsPerBox : 1;
      int boxes = (cantidadTotal / units).floor();
      return '$boxes ${boxes == 1 ? "Caja" : "Cajas"}';
    }

    if (tipoLower.contains('blister')) {
      int units = unitsPerBlister > 0 ? unitsPerBlister : 1;
      int blisters = (cantidadTotal / units).floor();
      return '$blisters ${blisters == 1 ? "Blíster" : "Blísters"}';
    }

    if (tipoLower.contains('unidad')) {
      return '$cantidadTotal ${cantidadTotal == 1 ? "Unidad" : "Unidades"}';
    }

    if (unitsPerBox > 1) {
      int boxes = (cantidadTotal / unitsPerBox).floor();
      int units = cantidadTotal % unitsPerBox;

      if (boxes > 0 && units > 0) {
        return '$boxes ${boxes == 1 ? "Caja" : "Cajas"} y $units ${units == 1 ? "Unid." : "Unid."}';
      } else if (boxes > 0) {
        return '$boxes ${boxes == 1 ? "Caja" : "Cajas"}';
      } else {
        return '$units ${units == 1 ? "Unidad" : "Unidades"}';
      }
    }

    return '$cantidadTotal ${cantidadTotal == 1 ? "Unidad" : "Unidades"}';
  }

  String _getFormattedStock(int? stockValue, Map<String, dynamic> item) {
    if (stockValue == null) return '--';
    int unitsPerBox = item['Cantidad_Presentacion'] ?? 1;
    if (unitsPerBox > 1) {
      int boxes = (stockValue / unitsPerBox).floor();
      int units = stockValue % unitsPerBox;
      if (boxes > 0 && units > 0) {
        return '$boxes cj $units un';
      } else if (boxes > 0) {
        return '$boxes ${boxes == 1 ? "Caja" : "Cajas"}';
      } else {
        return '$units ${units == 1 ? "Unid." : "Unid."}';
      }
    }
    return '$stockValue ${stockValue == 1 ? "Unid." : "Unid."}';
  }
}
