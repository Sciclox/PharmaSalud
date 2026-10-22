import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:intl/intl.dart';

class SobranteCajaDialog extends StatefulWidget {
  final int userId;
  final String userName;

  const SobranteCajaDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<SobranteCajaDialog> createState() => _SobranteCajaDialogState();
}

class _SobranteCajaDialogState extends State<SobranteCajaDialog> {
  final _montoController = TextEditingController();
  final _notaController = TextEditingController();
  final _sobranteRepo = SobranteCajaRepository();
  final _montoFocusNode = FocusNode();

  // Datos del vendedor actual (hoy)
  List<Map<String, dynamic>> _misSobrantes = [];
  double _miTotalHoy = 0.0;

  // Historial filtrado
  List<Map<String, dynamic>> _sobrantesFiltrados = [];
  double _totalFiltrado = 0.0;
  List<Map<String, dynamic>> _vendedoresDisponibles = [];

  // Filtros
  DateTime? _filtroFecha;
  int? _filtroVendedorId;
  String _filtroVendedorNombre = 'Todos';

  // Vista: 0 = mis registros, 1 = historial
  int _vistaActual = 0;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _mostrarNota = false;

  String get _fechaHoy {
    final hoy = DateTime.now();
    return "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _montoFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notaController.dispose();
    _montoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    _misSobrantes = await _sobranteRepo.obtenerSobrantesPorUsuarioYFecha(
        widget.userId, _fechaHoy);
    _miTotalHoy = await _sobranteRepo.obtenerTotalSobranteHoy(widget.userId);
    _vendedoresDisponibles =
        await _sobranteRepo.obtenerVendedoresConSobrantes();
    await _aplicarFiltros();
    setState(() => _isLoading = false);
  }

  Future<void> _aplicarFiltros() async {
    final fechaStr = _filtroFecha != null
        ? "${_filtroFecha!.year}-${_filtroFecha!.month.toString().padLeft(2, '0')}-${_filtroFecha!.day.toString().padLeft(2, '0')}"
        : null;
    _sobrantesFiltrados = await _sobranteRepo.obtenerSobrantesFiltrados(
        fecha: fechaStr, usuarioId: _filtroVendedorId);
    _totalFiltrado = 0.0;
    for (final s in _sobrantesFiltrados) {
      _totalFiltrado += (s['MONTO'] as num).toDouble();
    }
    if (mounted) setState(() {});
  }

  Future<void> _registrarSobrante() async {
    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0) {
      _showSnack('Ingrese un monto válido', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _sobranteRepo.registrarSobrante(
        usuarioId: widget.userId,
        monto: monto,
        nota: _notaController.text.trim().isEmpty
            ? null
            : _notaController.text.trim(),
      );
      _montoController.clear();
      _notaController.clear();
      _mostrarNota = false;
      await _cargarDatos();
      if (mounted) _showSnack('S/ ${formatMoney(monto)} registrado');
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
      _montoFocusNode.requestFocus();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 800),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _eliminarSobrante(int id, double monto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFFF3B30), size: 24),
                ),
                const SizedBox(height: 18),
                const Text('Eliminar sobrante',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF1D1D1F))),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                        height: 1.4),
                    children: [
                      const TextSpan(text: 'Se eliminará el registro de '),
                      TextSpan(
                        text: 'S/ ${formatMoney(monto)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D1D1F)),
                      ),
                      const TextSpan(text: '. Esta acción no se puede deshacer.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8E8E93),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E5EA)),
                            ),
                          ),
                          child: const Text('Cancelar',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3B30),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Eliminar',
                              style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
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
    if (confirm == true) {
      await _sobranteRepo.eliminarSobrante(id);
      await _cargarDatos();
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _filtroFecha ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _filtroFecha = picked);
      await _aplicarFiltros();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              _buildTopBar(),
              _buildBigTotal(),
              _buildSegmentedControl(),
              if (_vistaActual == 1) _buildFilterChips(),
              Expanded(
                child: _vistaActual == 0
                    ? _buildMisSobrantes()
                    : _buildHistorial(),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0DB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Color(0xFFE8920B), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sobrante de Caja',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.5)),
                Text(widget.userName,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded,
                color: const Color(0xFF1D1D1F).withOpacity(0.4), size: 20),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  BIG TOTAL DISPLAY
  // ─────────────────────────────────────────────────────────
  Widget _buildBigTotal() {
    final total = _vistaActual == 0 ? _miTotalHoy : _totalFiltrado;
    final label = _vistaActual == 0
        ? 'Mi sobrante hoy'
        : _buildFilterLabelShort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFAEAEB2),
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('S/ ',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFAEAEB2))),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      formatMoney(total),
                      key: ValueKey(total),
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D1D1F),
                          letterSpacing: -1.5,
                          height: 1.1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (_vistaActual == 0 && _misSobrantes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_misSobrantes.length} hoy',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93)),
              ),
            ),
          if (_vistaActual == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_sobrantesFiltrados.length} registros',
                style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8E8E93)),
              ),
            ),
        ],
      ),
    );
  }

  String _buildFilterLabelShort() {
    final parts = <String>[];
    if (_filtroFecha != null) {
      parts.add(DateFormat('dd MMM yyyy').format(_filtroFecha!));
    }
    if (_filtroVendedorId != null) {
      parts.add(_filtroVendedorNombre);
    }
    return parts.isEmpty ? 'Todo el historial' : parts.join(' · ');
  }

  // ─────────────────────────────────────────────────────────
  //  SEGMENTED CONTROL
  // ─────────────────────────────────────────────────────────
  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _segmentBtn(
              index: 0,
              icon: Icons.person_rounded,
              label: 'Mis registros',
              count: _misSobrantes.length,
            ),
            _segmentBtn(
              index: 1,
              icon: Icons.groups_rounded,
              label: 'Historial',
              count: _sobrantesFiltrados.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentBtn({
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _vistaActual == index;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _vistaActual = index),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 1),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected
                      ? const Color(0xFFE8920B)
                      : const Color(0xFF8E8E93)),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1D1D1F)
                          : const Color(0xFF8E8E93))),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8920B).withOpacity(0.12)
                        : const Color(0xFF8E8E93).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFFE8920B)
                              : const Color(0xFF8E8E93))),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  }

  // ─────────────────────────────────────────────────────────
  //  FILTER BAR (solo en historial)
  // ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final hasAnyFilter = _filtroFecha != null || _filtroVendedorId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: hasAnyFilter
                  ? const Color(0xFFE8920B).withOpacity(0.1)
                  : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune_rounded,
                size: 15,
                color: hasAnyFilter
                    ? const Color(0xFFE8920B)
                    : const Color(0xFFAEAEB2)),
          ),
          const SizedBox(width: 10),
          _buildFechaChip(),
          const SizedBox(width: 8),
          Expanded(child: _buildVendedorChip()),
          if (hasAnyFilter) ...[
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _filtroFecha = null;
                    _filtroVendedorId = null;
                    _filtroVendedorNombre = 'Todos';
                  });
                  _aplicarFiltros();
                },
                child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list_off_rounded,
                    size: 15, color: Color(0xFFFF3B30)),
              ),
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildFechaChip() {
    final isActive = _filtroFecha != null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _seleccionarFecha,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1D1D1F) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive
                  ? const Color(0xFF1D1D1F)
                  : const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 13,
                color: isActive ? Colors.white : const Color(0xFFAEAEB2)),
            const SizedBox(width: 6),
            Text(
              isActive
                  ? DateFormat('dd/MM/yyyy').format(_filtroFecha!)
                  : 'Fecha',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? Colors.white : const Color(0xFF8E8E93)),
            ),
            if (isActive) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () {
                  setState(() => _filtroFecha = null);
                  _aplicarFiltros();
                },
                child: const Icon(Icons.close_rounded,
                    size: 13, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  final GlobalKey _vendedorChipKey = GlobalKey();

  Widget _buildVendedorChip() {
    final isActive = _filtroVendedorId != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _mostrarMenuVendedores(),
        hoverColor: isActive
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFE5E5EA),
        splashColor: isActive
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFD1D1D6),
        child: AnimatedContainer(
          key: _vendedorChipKey,
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1D1D1F) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isActive
                    ? const Color(0xFF1D1D1F)
                    : const Color(0xFFE5E5EA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_rounded,
                  size: 12,
                  color: isActive ? Colors.white : const Color(0xFFAEAEB2)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isActive ? _filtroVendedorNombre : 'Vendedor',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isActive ? Colors.white : const Color(0xFF8E8E93)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isActive ? Icons.close_rounded : Icons.expand_more_rounded,
                size: 13,
                color: isActive ? Colors.white70 : const Color(0xFFAEAEB2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarMenuVendedores() async {
    final RenderBox renderBox =
        _vendedorChipKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final result = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      items: [
        PopupMenuItem<int>(
          value: -1,
          height: 44,
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups_rounded,
                  size: 14, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Todos los vendedores',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            if (_filtroVendedorId == null)
              const Icon(Icons.check_rounded,
                  size: 16, color: Color(0xFFE8920B)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        ..._vendedoresDisponibles.map((v) {
          final id = v['ID_USUARIO'] as int;
          final nombre = v['NOMBRE_VENDEDOR'] as String;
          final esYo = id == widget.userId;
          final isSelected = _filtroVendedorId == id;
          final initial =
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
          return PopupMenuItem<int>(
            value: id,
            height: 44,
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: esYo
                      ? const Color(0xFFFFF0DB)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(initial,
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: esYo
                              ? const Color(0xFFE8920B)
                              : const Color(0xFF8E8E93))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nombre,
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500)),
                    if (esYo)
                      const Text('Tu cuenta',
                          style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: Color(0xFFAEAEB2))),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded,
                    size: 16, color: Color(0xFFE8920B)),
            ]),
          );
        }),
      ],
    );

    if (result != null) {
      setState(() {
        if (result == -1) {
          _filtroVendedorId = null;
          _filtroVendedorNombre = 'Todos';
        } else {
          _filtroVendedorId = result;
          final v = _vendedoresDisponibles
              .firstWhere((v) => v['ID_USUARIO'] == result);
          _filtroVendedorNombre = v['NOMBRE_VENDEDOR'] as String;
        }
      });
      _aplicarFiltros();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  MIS SOBRANTES (HOY)
  // ─────────────────────────────────────────────────────────
  Widget _buildMisSobrantes() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE8920B)));
    }
    if (_misSobrantes.isEmpty) {
      return _emptyState('Sin registros hoy', 'Escribe un monto abajo para agregar');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      itemCount: _misSobrantes.length,
      itemBuilder: (context, i) => _buildRow(_misSobrantes[i], canDelete: true),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  HISTORIAL FILTRADO
  // ─────────────────────────────────────────────────────────
  Widget _buildHistorial() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE8920B)));
    }
    if (_sobrantesFiltrados.isEmpty) {
      return _emptyState('Sin resultados', 'Prueba con otros filtros');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      itemCount: _sobrantesFiltrados.length,
      itemBuilder: (context, i) =>
          _buildRow(_sobrantesFiltrados[i], showVendedor: true),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  ROW ITEM — estilo línea de ledger
  // ─────────────────────────────────────────────────────────
  Widget _buildRow(Map<String, dynamic> s,
      {bool canDelete = false, bool showVendedor = false}) {
    final fecha = DateTime.parse(s['FECHA']);
    final fechaStr = DateFormat('dd/MM/yyyy').format(fecha);
    final horaStr = DateFormat('hh:mm a').format(fecha);
    final nota = s['NOTA'] as String? ?? '';
    final vendedor = s['NOMBRE_VENDEDOR'] ?? '';
    final esYo = s['USUARIO_ID'] == widget.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: canDelete
              ? () => _eliminarSobrante(
                  s['ID'] as int, (s['MONTO'] as num).toDouble())
              : null,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFFFFF8ED),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                // Fecha
                SizedBox(
                  width: 84,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fechaStr,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D1D1F))),
                      Text(horaStr,
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              color: Color(0xFFAEAEB2))),
                    ],
                  ),
                ),
                // Separador vertical
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFE5E5EA),
                ),
                // Contenido central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showVendedor)
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: esYo
                                    ? const Color(0xFFE8920B)
                                    : const Color(0xFFD1D1D6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              esYo ? '$vendedor (Tú)' : vendedor,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight:
                                    esYo ? FontWeight.w700 : FontWeight.w500,
                                color: esYo
                                    ? const Color(0xFFE8920B)
                                    : const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      if (nota.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: showVendedor ? 2 : 0),
                          child: Text(nota,
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFAEAEB2)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      if (!showVendedor && nota.isEmpty)
                        const Text('Sobrante registrado',
                            style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                color: Color(0xFFD1D1D6))),
                    ],
                  ),
                ),
                // Monto
                Text('${(s['MONTO'] as num) >= 0 ? "+" : "-"} S/ ${formatMoney(((s['MONTO'] as num).toDouble()).abs())}',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: (s['MONTO'] as num) < 0
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF34C759),
                        letterSpacing: -0.3)),
                // Delete
                if (canDelete)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () => _eliminarSobrante(
                          s['ID'] as int, (s['MONTO'] as num).toDouble()),
                      child: const Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: Color(0xFFD1D1D6)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  INPUT BAR (estilo chat en la parte inferior)
  // ─────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nota (expandible)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _mostrarNota
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _notaController,
                      maxLines: 1,
                      style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F)),
                      decoration: InputDecoration(
                        hintText: 'Escribir nota...',
                        hintStyle: const TextStyle(color: Color(0xFFD1D1D6)),
                        filled: true,
                        fillColor: const Color(0xFFF2F2F7),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Color(0xFF8E8E93)),
                          onPressed: () {
                            _notaController.clear();
                            setState(() => _mostrarNota = false);
                          },
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Input principal
          Row(
            children: [
              // Botón nota
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _mostrarNota = !_mostrarNota),
                  child: Container(
                  width: 42,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _mostrarNota
                        ? const Color(0xFFE8920B).withOpacity(0.1)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.note_add_outlined,
                      size: 20,
                      color: _mostrarNota
                          ? const Color(0xFFE8920B)
                          : const Color(0xFF8E8E93)),
                ),
              ),
            ),
              const SizedBox(width: 10),
              // Input monto
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _montoController,
                    focusNode: _montoFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        if (RegExp(r'^\d*\.?\d{0,2}$')
                            .hasMatch(newValue.text)) return newValue;
                        return oldValue;
                      }),
                    ],
                    onSubmitted: (_) => _registrarSobrante(),
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F)),
                    decoration: const InputDecoration(
                      hintText: 'Monto del sobrante...',
                      hintStyle:
                          TextStyle(color: Color(0xFFD1D1D6), fontSize: 14, fontWeight: FontWeight.w500),
                      prefixText: 'S/  ',
                      prefixStyle: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botón enviar
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _isSaving ? null : _registrarSobrante,
                  child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8920B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 22),
                ),
              ),
            ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────────────────────
  Widget _emptyState(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 36, color: Color(0xFFE5E5EA)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD1D1D6))),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(
                  fontFamily: 'Outfit', fontSize: 12, color: Color(0xFFD1D1D6))),
        ],
      ),
    );
  }
}
