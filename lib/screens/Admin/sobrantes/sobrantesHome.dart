import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/repositories/campana_inventario.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SobrantesAdminHome extends StatefulWidget {
  const SobrantesAdminHome({super.key});

  @override
  State<SobrantesAdminHome> createState() => _SobrantesAdminHomeState();
}

class _SobrantesAdminHomeState extends State<SobrantesAdminHome> {
  final SobranteCajaRepository _sobranteRepo = SobranteCajaRepository();
  final UsuarioRepository _userRepo = UsuarioRepository();
  final CampanaInventarioRepository _campanaRepo = CampanaInventarioRepository();

  final TextEditingController _fechaInicioController = TextEditingController();
  final FocusNode _fechaInicioFocusNode = FocusNode();
  final TextEditingController _fechaFinController = TextEditingController();
  final FocusNode _fechaFinFocusNode = FocusNode();
  bool _isLoading = true;

  // Campañas
  Map<String, dynamic>? _campanaActiva;
  List<Map<String, dynamic>> _campanasDisponibles = [];
  final Map<String, Map<String, dynamic>> _campanaMap = {};
  int? _filtroCampanaId;
  String _filtroCampanaNombre = 'Todas / Histórico';
  List<String> _opcionesCampana = ['Todas / Histórico'];

  // Filtros
  DateTime? _filtroFechaInicio;
  DateTime? _filtroFechaFin;
  int? _filtroVendedorId;
  String _filtroVendedorNombre = 'Todos';
  String _filtroTipo = 'Todos';

  List<Map<String, dynamic>> _registros = [];
  double _totalFiltrado = 0.0;
  List<Map<String, dynamic>> _vendedoresDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    // Purgar residuos de ajustes de inventario y reinicios ficticios de la caja física
    await _sobranteRepo.purgarAjustesInventarioDeCaja();
    await _sobranteRepo.purgarReiniciosDeCaja();

    _vendedoresDisponibles = await _sobranteRepo.obtenerVendedoresConSobrantes();

    // Cargar campañas de inventario
    _campanaActiva = await _campanaRepo.obtenerActiva();
    _campanasDisponibles = await _campanaRepo.obtenerTodas();

    _campanaMap.clear();
    List<String> nuevasOpciones = [];
    String seleccionada = 'Todas / Histórico';
    int? campanaId;

    if (_campanaActiva != null) {
      final nombreActiva = 'En Curso: ${_campanaActiva!['NOMBRE']}';
      nuevasOpciones.add(nombreActiva);
      _campanaMap[nombreActiva] = _campanaActiva!;
      seleccionada = nombreActiva;
      campanaId = _campanaActiva!['ID'] as int;

      try {
        final inicioStr = _campanaActiva!['FECHA_INICIO'] as String;
        _filtroFechaInicio = DateTime.parse(inicioStr.replaceAll(' ', 'T'));
        _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(_filtroFechaInicio!);
      } catch (_) {}
      _filtroFechaFin = null;
      _fechaFinController.clear();
    }

    for (var c in _campanasDisponibles) {
      if (c['ESTADO'] != 'ACTIVO') {
        final nombre = (c['NOMBRE'] ?? 'Campaña').toString().trim();
        String label = nombre;
        int duplicateCount = 1;
        while (nuevasOpciones.contains(label) || label == 'Todas / Histórico') {
          duplicateCount++;
          label = '$nombre ($duplicateCount)';
        }
        nuevasOpciones.add(label);
        _campanaMap[label] = c;
      }
    }
    nuevasOpciones.add('Todas / Histórico');

    _opcionesCampana = nuevasOpciones;
    _filtroCampanaNombre = seleccionada;
    _filtroCampanaId = campanaId;

    await _aplicarFiltros();
    setState(() => _isLoading = false);
  }

  void _onCampanaChanged(String? value) {
    if (value == null) return;
    setState(() {
      _filtroCampanaNombre = value;
      if (value == 'Todas / Histórico') {
        _filtroCampanaId = null;
        _filtroFechaInicio = null;
        _filtroFechaFin = null;
        _fechaInicioController.clear();
        _fechaFinController.clear();
      } else if (_campanaMap.containsKey(value)) {
        final campana = _campanaMap[value]!;
        _filtroCampanaId = campana['ID'] as int;
        try {
          final inicioStr = campana['FECHA_INICIO'] as String;
          _filtroFechaInicio = DateTime.parse(inicioStr.replaceAll(' ', 'T'));
          _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(_filtroFechaInicio!);
        } catch (_) {}
        try {
          final finStr = campana['FECHA_FIN'] as String?;
          if (finStr != null) {
            _filtroFechaFin = DateTime.parse(finStr.replaceAll(' ', 'T'));
            _fechaFinController.text = DateFormat('dd/MM/yyyy').format(_filtroFechaFin!);
          } else {
            _filtroFechaFin = null;
            _fechaFinController.clear();
          }
        } catch (_) {}
      }
    });
    _aplicarFiltros();
  }

  Future<void> _aplicarFiltros() async {
    final fechaInicioStr = _filtroFechaInicio != null
        ? "${_filtroFechaInicio!.year}-${_filtroFechaInicio!.month.toString().padLeft(2, '0')}-${_filtroFechaInicio!.day.toString().padLeft(2, '0')}"
        : null;
    final fechaFinStr = _filtroFechaFin != null
        ? "${_filtroFechaFin!.year}-${_filtroFechaFin!.month.toString().padLeft(2, '0')}-${_filtroFechaFin!.day.toString().padLeft(2, '0')}"
        : null;

    String? tipoDb;
    if (_filtroTipo == 'Sobrante Vendedor') tipoDb = 'SOBRANTE';
    else if (_filtroTipo == 'Sobrante Admin') tipoDb = 'SOBRANTE_MANUAL';

    _registros = await _sobranteRepo.obtenerSobrantesFiltrados(
      fechaInicio: fechaInicioStr,
      fechaFin: fechaFinStr,
      usuarioId: _filtroVendedorId,
      tipo: tipoDb,
    );

    _totalFiltrado = 0.0;
    for (final s in _registros) {
      _totalFiltrado += (s['MONTO'] as num).toDouble();
    }
    if (mounted) setState(() {});
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
            _buildStandardHeader(),
            const SizedBox(height: 32),
            _buildStandardFilterBar(),
            const SizedBox(height: 24),
            _buildStandardTableHeaders(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
                : _buildListadoRecords(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardHeader() {
    return Row(
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
                  'Sobrantes de Caja',
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
                'Auditoría técnica de excedentes monetarios por turno',
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
        Row(
          children: [
            _toolButton(
              icon: Icons.add_circle_outline_rounded,
              label: 'AGREGAR REGISTRO',
              onTap: _mostrarDialogoAgregarRegistro,
              isActive: false,
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, 
                      size: 18, color: Color(0xFF34C759)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _filtroCampanaId != null ? 'TOTAL CAMPAÑA' : 'TOTAL ACUMULADO', 
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.4), letterSpacing: 0.5)),
                      Text('+ S/ ${formatMoney(_totalFiltrado)}', 
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF34C759), fontFamily: 'Outfit')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardFilterBar() {
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Selector de Campaña
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Campaña',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: CustomDropdown<String>(
                    hintText: 'Seleccionar...',
                    items: _opcionesCampana,
                    initialItem: _filtroCampanaNombre,
                    onChanged: _onCampanaChanged,
                    decoration: CustomDropdownDecoration(
                      closedFillColor: const Color(0xFFF5F5F7),
                      expandedFillColor: Colors.white,
                      closedBorder: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                      closedBorderRadius: BorderRadius.circular(10),
                      expandedBorderRadius: BorderRadius.circular(10),
                      hintStyle: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: const Color(0xFF1D1D1F).withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      headerStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                        fontWeight: FontWeight.w500,
                      ),
                      listItemStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. Selector de Vendedor
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vendedor',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: CustomDropdown<String>(
                    hintText: 'Seleccionar...',
                    items: ['Todos', ..._vendedoresDisponibles.map((u) => u['NOMBRE_VENDEDOR'] as String)],
                    initialItem: _filtroVendedorId == null ? 'Todos' : _filtroVendedorNombre,
                    onChanged: (value) {
                      setState(() {
                        if (value == 'Todos') {
                          _filtroVendedorId = null;
                          _filtroVendedorNombre = 'Todos';
                        } else {
                          final user = _vendedoresDisponibles.firstWhere((u) => u['NOMBRE_VENDEDOR'] == value);
                          _filtroVendedorId = user['ID_USUARIO'];
                          _filtroVendedorNombre = user['NOMBRE_VENDEDOR'];
                        }
                      });
                      _aplicarFiltros();
                    },
                    decoration: CustomDropdownDecoration(
                      closedFillColor: const Color(0xFFF5F5F7),
                      expandedFillColor: Colors.white,
                      closedBorder: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                      closedBorderRadius: BorderRadius.circular(10),
                      expandedBorderRadius: BorderRadius.circular(10),
                      hintStyle: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: const Color(0xFF1D1D1F).withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      headerStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                        fontWeight: FontWeight.w500,
                      ),
                      listItemStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Input Fecha Inicio
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fecha Inicio',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: KeyFocusWrapper(
                    bindings: {LogicalKeyboardKey.f1: _fechaInicioFocusNode},
                    actions: {
                      LogicalKeyboardKey.escape: () {
                        _fechaInicioController.clear();
                        setState(() => _filtroFechaInicio = null);
                        _aplicarFiltros();
                      }
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextField(
                        controller: _fechaInicioController,
                        focusNode: _fechaInicioFocusNode,
                        readOnly: true,
                        mouseCursor: SystemMouseCursors.click,
                        onTap: _seleccionarFechaInicio,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Desde',
                          hintStyle: TextStyle(
                            color: const Color(0xFF1D1D1F).withOpacity(0.4),
                            fontFamily: 'Outfit',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          prefixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const F1Badge(label: 'F1'),
                              const SizedBox(width: 6),
                            ],
                          ),
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                        ),
                        style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFF1D1D1F)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 4. Input Fecha Fin
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fecha Fin',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: KeyFocusWrapper(
                    bindings: {LogicalKeyboardKey.f2: _fechaFinFocusNode},
                    actions: {
                      LogicalKeyboardKey.escape: () {
                        _fechaFinController.clear();
                        setState(() => _filtroFechaFin = null);
                        _aplicarFiltros();
                      }
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextField(
                        controller: _fechaFinController,
                        focusNode: _fechaFinFocusNode,
                        readOnly: true,
                        mouseCursor: SystemMouseCursors.click,
                        onTap: _seleccionarFechaFin,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Hasta',
                          hintStyle: TextStyle(
                            color: const Color(0xFF1D1D1F).withOpacity(0.4),
                            fontFamily: 'Outfit',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          prefixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const F1Badge(label: 'F2'),
                              const SizedBox(width: 6),
                            ],
                          ),
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                        ),
                        style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: Color(0xFF1D1D1F)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 5. Tipo Registro (Dropdown)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tipo Registro',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: CustomDropdown<String>(
                    hintText: 'Seleccionar...',
                    items: const [
                      'Todos',
                      'Sobrante Vendedor',
                      'Sobrante Admin',
                    ],
                    initialItem: _filtroTipo,
                    onChanged: (value) {
                      setState(() {
                        _filtroTipo = value ?? 'Todos';
                      });
                      _aplicarFiltros();
                    },
                    decoration: CustomDropdownDecoration(
                      closedFillColor: const Color(0xFFF5F5F7),
                      expandedFillColor: Colors.white,
                      closedBorder: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                      closedBorderRadius: BorderRadius.circular(10),
                      expandedBorderRadius: BorderRadius.circular(10),
                      hintStyle: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: const Color(0xFF1D1D1F).withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      headerStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                        fontWeight: FontWeight.w500,
                      ),
                      listItemStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 6. Botón Limpiar
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  if (_campanaActiva != null) {
                    _filtroCampanaId = _campanaActiva!['ID'] as int;
                    _filtroCampanaNombre = 'En Curso: ${_campanaActiva!['NOMBRE']}';
                    try {
                      final inicioStr = _campanaActiva!['FECHA_INICIO'] as String;
                      _filtroFechaInicio = DateTime.parse(inicioStr.replaceAll(' ', 'T'));
                      _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(_filtroFechaInicio!);
                    } catch (_) {}
                    _filtroFechaFin = null;
                    _fechaFinController.clear();
                  } else {
                    _filtroCampanaId = null;
                    _filtroCampanaNombre = 'Todas / Histórico';
                    _filtroFechaInicio = null;
                    _filtroFechaFin = null;
                    _fechaInicioController.clear();
                    _fechaFinController.clear();
                  }
                  _filtroVendedorId = null;
                  _filtroVendedorNombre = 'Todos';
                  _filtroTipo = 'Todos';
                });
                _aplicarFiltros();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Restablecer a campaña actual',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardTableHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: _tableHeader('FECHA')),
          Expanded(flex: 3, child: _tableHeader('VENDEDOR')),
          Expanded(flex: 5, child: _tableHeader('EXPLICACIÓN / NOTA')),
          Expanded(flex: 2, child: Center(child: _tableHeader('MONTO'))),
          SizedBox(width: 48, child: Center(child: _tableHeader('ACCIONES'))),
        ],
      ),
    );
  }

  Widget _buildListadoRecords() {
    if (_registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('Sin registros técnicos',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _registros.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final r = _registros[index];
        final fecha = DateTime.parse(r['FECHA']);
        
        return Material(
          color: Colors.white,
          borderRadius: index == 0 
            ? const BorderRadius.vertical(top: Radius.circular(12))
            : index == _registros.length - 1 
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Fecha
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd / MM / yyyy').format(fecha), 
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F))),
                      Text(DateFormat('hh:mm a').format(fecha), 
                        style: TextStyle(fontSize: 10, color: const Color(0xFF1D1D1F).withOpacity(0.4))),
                    ],
                  ),
                ),
                // Vendedor
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _circleAvatar(r['NOMBRE_VENDEDOR'] ?? '?'),
                      const SizedBox(width: 12),
                      Text(r['NOMBRE_VENDEDOR'] ?? 'N/A', 
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                 // Nota
                 Expanded(
                   flex: 5,
                   child: Builder(
                     builder: (context) {
                       final String notaExplicacion = r['NOTA'] ?? '';
                       final String tipo = r['TIPO'] ?? 'SOBRANTE';
                       Widget? badge;

                       if (tipo == 'REINICIO') {
                         badge = _buildBadge('REINICIO A 0', const Color(0xFF5856D6)); // Indigo/Purple
                       } else if (tipo == 'AJUSTE') {
                         badge = _buildBadge('AJUSTE INVENTARIO', const Color(0xFFFF9500)); // Orange
                       } else if (tipo == 'SOBRANTE_MANUAL') {
                         badge = _buildBadge('SOBRANTE ADMIN', const Color(0xFF34C759)); // Green
                       } else if (tipo == 'SOBRANTE') {
                         badge = _buildBadge('SOBRANTE VENDEDOR', const Color(0xFF007AFF)); // Blue
                       }

                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           if (badge != null) ...[
                             badge,
                             const SizedBox(height: 4),
                           ],
                           Text(
                             notaExplicacion.isNotEmpty ? notaExplicacion : '--',
                             style: TextStyle(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w700,
                                 color: const Color(0xFF1D1D1F).withOpacity(0.6),
                                 height: 1.3),
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                         ],
                       );
                     }
                   ),
                 ),
                // Monto
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      '${(r['MONTO'] as num) < 0 ? "-" : "+"} S/ ${formatMoney((r['MONTO'] as num).abs())}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: (r['MONTO'] as num) < 0
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF34C759),
                      ),
                    ),
                  ),
                ),
                // Acciones (Eliminar)
                SizedBox(
                  width: 48,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF3B30)),
                    tooltip: 'Eliminar registro',
                    onPressed: () => _confirmarEliminarSobrante(r),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarEliminarSobrante(Map<String, dynamic> registro) async {
    final int id = registro['ID'];
    final double monto = (registro['MONTO'] as num).toDouble();
    final String vendedor = registro['NOMBRE_VENDEDOR'] ?? 'Vendedor';

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30)),
              SizedBox(width: 8),
              Text(
                'Eliminar Sobrante',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Está seguro de eliminar este registro de sobrante?',
                style: TextStyle(fontSize: 14, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vendedor: $vendedor',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                    const SizedBox(height: 4),
                    Text('Monto: S/ ${formatMoney(monto.abs())}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Outfit', color: Color(0xFFFF3B30))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Eliminar', style: TextStyle(fontFamily: 'Outfit')),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        await _sobranteRepo.eliminarSobrante(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro eliminado correctamente'),
              backgroundColor: Color(0xFF34C759),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _cargarDatos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar registro: $e'),
              backgroundColor: const Color(0xFFFF3B30),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _circleAvatar(String name) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', 
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.4)))),
    );
  }

  Widget _tableHeader(String text) {
    return Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1D1D1F).withOpacity(0.3), letterSpacing: 1.2));
  }

  Widget _toolButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isActive = false,
      bool isDestructive = false}) {
    final color =
        isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.05) : Colors.white,
            border: Border.all(
                color:
                    isActive ? color.withOpacity(0.2) : color.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16, color: color.withOpacity(isActive ? 1.0 : 0.6)),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(isActive ? 1.0 : 0.6),
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFechaInicio() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _filtroFechaInicio ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _filtroFechaInicio = picked;
        _fechaInicioController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _aplicarFiltros();
    }
  }

  Future<void> _seleccionarFechaFin() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _filtroFechaFin ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _filtroFechaFin = picked;
        _fechaFinController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _aplicarFiltros();
    }
  }

  Future<void> _mostrarDialogoAgregarRegistro() async {
    final montoController = TextEditingController();
    final notaController = TextEditingController();
    final formKeyDialog = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: formKeyDialog,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: Color(0xFF34C759),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REGISTRO MANUAL',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8E8E93),
                                    letterSpacing: 1.2,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Agregar Sobrante',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D1D1F),
                                    fontFamily: 'Outfit',
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
                            splashRadius: 20,
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Label Monto
                      const Text(
                        'MONTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6E6E73),
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 14, right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'S/',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF34C759),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1D1D1F),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF3B30),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF3B30),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingrese el monto.';
                          }
                          final double? m = double.tryParse(value);
                          if (m == null) {
                            return 'Monto inválido.';
                          }
                          if (m <= 0) {
                            return 'El monto debe ser mayor a 0.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Label Explicación / Nota
                      const Text(
                        'EXPLICACIÓN / MOTIVO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6E6E73),
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: notaController,
                        minLines: 3,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ingrese el motivo detallado del sobrante...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1D1D1F),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF3B30),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF3B30),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingrese una explicación.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 26),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6E6E73),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (formKeyDialog.currentState!.validate()) {
                                    try {
                                      final double monto = double.parse(montoController.text);
                                      final prefs = await SharedPreferences.getInstance();
                                      final int adminId = prefs.getInt('adminId') ?? 1;

                                      await _sobranteRepo.registrarSobrante(
                                        usuarioId: adminId,
                                        monto: monto,
                                        nota: notaController.text.trim(),
                                        tipo: 'SOBRANTE_MANUAL',
                                      );

                                      if (!context.mounted) return;
                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Registro de sobrante guardado con éxito',
                                            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                          ),
                                          backgroundColor: const Color(0xFF34C759),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );

                                      _cargarDatos();
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error al guardar: $e'),
                                          backgroundColor: const Color(0xFFFF3B30),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text(
                                  'Guardar Registro',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D1D1F),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          fontFamily: 'Outfit',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
