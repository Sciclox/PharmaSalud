import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/conteo_inventario.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DialogConteoCruzado extends StatefulWidget {
  final String? initialSesionA;
  final String? initialSesionB;
  final VoidCallback? onAjustesAplicados;

  const DialogConteoCruzado({
    super.key,
    this.initialSesionA,
    this.initialSesionB,
    this.onAjustesAplicados,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialSesionA,
    String? initialSesionB,
    VoidCallback? onAjustesAplicados,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DialogConteoCruzado(
        initialSesionA: initialSesionA,
        initialSesionB: initialSesionB,
        onAjustesAplicados: onAjustesAplicados,
      ),
    );
  }

  @override
  State<DialogConteoCruzado> createState() => _DialogConteoCruzadoState();
}

class _DialogConteoCruzadoState extends State<DialogConteoCruzado> {
  final ConteoInventarioRepository _conteoRepo = ConteoInventarioRepository();

  List<Map<String, dynamic>> _sesionesDisponibles = [];
  String? _sesionA;
  String? _sesionB;

  bool _cargandoSesiones = true;
  bool _cargandoComparacion = false;
  Map<String, dynamic>? _comparativaData;

  String _filtroEstado = 'TODOS'; // 'TODOS', 'DISCREPANCIAS', 'COINCIDENTES', 'SOLO_A', 'SOLO_B'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _sesionA = widget.initialSesionA;
    _sesionB = widget.initialSesionB;
    _cargarSesiones();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarSesiones() async {
    setState(() => _cargandoSesiones = true);
    try {
      final lista = await _conteoRepo.obtenerHistorialInventariosPOS(modo: 'TODOS');
      if (mounted) {
        setState(() {
          _sesionesDisponibles = lista;
          _cargandoSesiones = false;
        });

        if (lista.isNotEmpty) {
          if (_sesionA == null && lista.isNotEmpty) {
            _sesionA = lista[0]['CODIGO'];
          }
          if (_sesionB == null && lista.length > 1) {
            _sesionB = lista[1]['CODIGO'];
          } else if (_sesionB == null && lista.isNotEmpty) {
            _sesionB = lista[0]['CODIGO'];
          }

          if (_sesionA != null && _sesionB != null) {
            _ejecutarComparacion();
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoSesiones = false);
    }
  }

  Future<void> _ejecutarComparacion() async {
    if (_sesionA == null || _sesionB == null) return;
    setState(() => _cargandoComparacion = true);
    try {
      final res = await _conteoRepo.compararSesionesInventario(_sesionA!, _sesionB!);
      if (mounted) {
        setState(() {
          _comparativaData = res;
          _cargandoComparacion = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoComparacion = false);
    }
  }

  String _formatearFechaHora(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(fechaStr);
      return DateFormat('dd/MM/yyyy • hh:mm a').format(dt);
    } catch (_) {
      return fechaStr;
    }
  }

  List<Map<String, dynamic>> get _itemsFiltrados {
    if (_comparativaData == null) return [];
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(_comparativaData!['comparativa'] ?? []);

    return items.where((it) {
      final estado = it['ESTADO_COMPARACION'] as String;
      if (_filtroEstado == 'DISCREPANCIAS' && estado != 'DISCREPANCIA') return false;
      if (_filtroEstado == 'COINCIDENTES' && estado != 'COINCIDENTE') return false;
      if (_filtroEstado == 'SOLO_A' && estado != 'SOLO_A') return false;
      if (_filtroEstado == 'SOLO_B' && estado != 'SOLO_B') return false;

      if (_searchQuery.isNotEmpty) {
        final nombre = (it['NOMBRE_PRODUCTO'] ?? '').toString().toLowerCase();
        final barra = (it['CODIGO_BARRA'] ?? '').toString().toLowerCase();
        final id = it['PRODUCTO_ID']?.toString().toLowerCase() ?? '';
        return nombre.contains(_searchQuery) || barra.contains(_searchQuery) || id.contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  Future<void> _aprobarTodosCoincidentes() async {
    if (_comparativaData == null) return;
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(_comparativaData!['comparativa'] ?? []);
    final coincidentes = items.where((it) => it['ESTADO_COMPARACION'] == 'COINCIDENTE').toList();

    if (coincidentes.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Aprobar ${coincidentes.length} productos coincidentes?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ambas sesiones de conteo registraron exactamente la misma cantidad física en estos productos. El stock físico se certificará y aplicará directamente en la base de datos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Sí, aprobar con certeza', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    final prefs = await SharedPreferences.getInstance();
    final adminName = prefs.getString('adminName') ?? 'Administrador';

    final itemsParaAjustar = coincidentes.map((it) {
      return {
        'ID': it['ID_CONTEO_A'],
        'PRODUCTO_ID': it['PRODUCTO_ID'],
        'NOMBRE_PRODUCTO': it['NOMBRE_PRODUCTO'],
        'CONTEO_FISICO': it['CONTEO_A'],
        'FECHA_HORA': it['FECHA_A'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();

    if (!mounted) return;
    setState(() => _cargandoComparacion = true);

    await _conteoRepo.aplicarAjustesAdmin(
      itemsParaAjustar: itemsParaAjustar,
      nombreAdmin: adminName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF16A34A),
          content: Text('${coincidentes.length} productos coincidentes aprobados y ajustados en stock con éxito.'),
          duration: const Duration(seconds: 3),
        ),
      );

      widget.onAjustesAplicados?.call();
      await _ejecutarComparacion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.94).clamp(960.0, 1140.0);
    final dialogHeight = (size.height * 0.90).clamp(560.0, 750.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(),
              _buildSelectoresSesion(),
              if (_comparativaData != null) _buildBannerKPI(),
              Expanded(
                child: _buildTablaComparativa(),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auditoría Comparativa (Conteo Cruzado)',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Contrasta los conteos físicos de dos operadores, turnos o sesiones para detectar discrepancias y certificar existencias',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectoresSesion() {
    if (_cargandoSesiones) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB))),
      );
    }

    if (_sesionesDisponibles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFF8FAFC),
        child: const Center(
          child: Text(
            'No hay sesiones de inventario registradas en el historial para comparar.',
            style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Selector Sesión A
          Expanded(
            child: _cardSelectorSesion(
              label: 'REPORTE 1 (SESIÓN A)',
              color: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFBFDBFE),
              valorSeleccionado: _sesionA,
              onChanged: (val) {
                setState(() => _sesionA = val);
                _ejecutarComparacion();
              },
            ),
          ),

          // Icono VS en el centro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'VS',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),

          // Selector Sesión B
          Expanded(
            child: _cardSelectorSesion(
              label: 'REPORTE 2 (SESIÓN B)',
              color: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF5F3FF),
              borderColor: const Color(0xFFDDD6FE),
              valorSeleccionado: _sesionB,
              onChanged: (val) {
                setState(() => _sesionB = val);
                _ejecutarComparacion();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardSelectorSesion({
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String? valorSeleccionado,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: valorSeleccionado,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: color, size: 20),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              items: _sesionesDisponibles.map((s) {
                final codigo = s['CODIGO'] as String;
                final usuario = s['NOMBRE_USUARIO'] ?? 'Operador';
                final fecha = _formatearFechaHora(s['FECHA_FIN'] ?? s['FECHA_INICIO']);
                final prods = s['TOTAL_PRODUCTOS'] ?? 0;

                return DropdownMenuItem<String>(
                  value: codigo,
                  child: Text(
                    '$usuario • $fecha ($prods prod.)',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerKPI() {
    final tasa = (_comparativaData!['tasaCoincidencia'] as num?)?.toDouble() ?? 0.0;
    final totalCoincidentes = _comparativaData!['totalCoincidentes'] ?? 0;
    final totalDiscrepancias = _comparativaData!['totalDiscrepancias'] ?? 0;
    final totalSoloA = _comparativaData!['totalSoloA'] ?? 0;
    final totalSoloB = _comparativaData!['totalSoloB'] ?? 0;
    final totalAmbas = _comparativaData!['totalAmbas'] ?? 0;

    Color kpiColor;
    Color kpiBg;
    String kpiMsg;

    if (tasa >= 90) {
      kpiColor = const Color(0xFF16A34A);
      kpiBg = const Color(0xFFF0FDF4);
      kpiMsg = 'Excelente concordancia. Muy alta fiabilidad en el conteo.';
    } else if (tasa >= 70) {
      kpiColor = const Color(0xFFD97706);
      kpiBg = const Color(0xFFFFFBEB);
      kpiMsg = 'Concordancia moderada. Se detectaron algunas discrepancias.';
    } else {
      kpiColor = const Color(0xFFDC2626);
      kpiBg = const Color(0xFFFEF2F2);
      kpiMsg = 'Alta discrepancia entre reportes. Se sugiere reconteo físico.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // KPI Principal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kpiBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kpiColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tasa.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kpiColor,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalCoincidentes de $totalAmbas productos coinciden',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kpiColor,
                      ),
                    ),
                    Text(
                      kpiMsg,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10.5,
                        color: kpiColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Buscador rápido
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Filtrar por producto...',
                  hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Filtros tipo chip
          _chipFiltro('TODOS', 'Todos (${_comparativaData!['totalProductos']})'),
          const SizedBox(width: 6),
          _chipFiltro('DISCREPANCIAS', 'Discrepancias ($totalDiscrepancias)', color: const Color(0xFFDC2626)),
          const SizedBox(width: 6),
          _chipFiltro('COINCIDENTES', 'Coincidentes ($totalCoincidentes)', color: const Color(0xFF16A34A)),
          if (totalSoloA > 0) ...[
            const SizedBox(width: 6),
            _chipFiltro('SOLO_A', 'Solo en Sesión 1 ($totalSoloA)', color: const Color(0xFF2563EB)),
          ],
          if (totalSoloB > 0) ...[
            const SizedBox(width: 6),
            _chipFiltro('SOLO_B', 'Solo en Sesión 2 ($totalSoloB)', color: const Color(0xFF7C3AED)),
          ],
        ],
      ),
    );
  }

  Widget _chipFiltro(String id, String label, {Color? color}) {
    final activo = _filtroEstado == id;
    final baseColor = color ?? const Color(0xFF0F172A);

    return InkWell(
      onTap: () => setState(() => _filtroEstado = id),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? baseColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? baseColor : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11.5,
            fontWeight: activo ? FontWeight.bold : FontWeight.w500,
            color: activo ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaComparativa() {
    if (_cargandoComparacion) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
            SizedBox(height: 12),
            Text('Cruzando conteos de ambas sesiones...', style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    final filtrados = _itemsFiltrados;

    if (filtrados.isEmpty) {
      return const Center(
        child: Text(
          'No hay productos en esta categoría de filtro',
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF94A3B8)),
        ),
      );
    }

    final usuarioA = _comparativaData!['usuarioA'] ?? 'Operador 1';
    final usuarioB = _comparativaData!['usuarioB'] ?? 'Operador 2';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Cabecera tabla
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Expanded(
                    flex: 4,
                    child: Text('PRODUCTO', style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '$usuarioA (Sesión 1)',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '$usuarioB (Sesión 2)',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 140,
                    child: Center(
                      child: Text('DIFERENCIA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(
                    width: 110,
                    child: Center(
                      child: Text('STOCK SISTEMA', style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(
                    width: 130,
                    child: Center(
                      child: Text('ESTADO', style: TextStyle(fontFamily: 'Outfit', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Filas
            Expanded(
              child: ListView.separated(
                itemCount: filtrados.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final it = filtrados[index];
                  return _buildFilaComparativa(it, index.isEven);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaComparativa(Map<String, dynamic> it, bool isEven) {
    final nombre = it['NOMBRE_PRODUCTO'] ?? '';
    final prodId = it['PRODUCTO_ID']?.toString() ?? '';
    final estado = it['ESTADO_COMPARACION'] as String;
    final conteoA = it['CONTEO_A'] as int?;
    final conteoB = it['CONTEO_B'] as int?;
    final dif = it['DIFERENCIA_ENTRE_ELLAS'] as int?;
    final stockSistema = (it['STOCK_SISTEMA'] as num?)?.toInt() ?? 0;

    Color badgeBg;
    Color badgeBorder;
    Color badgeColor;
    String badgeTexto;
    IconData badgeIcon;

    if (estado == 'COINCIDENTE') {
      badgeBg = const Color(0xFFF0FDF4);
      badgeBorder = const Color(0xFFBBF7D0);
      badgeColor = const Color(0xFF16A34A);
      badgeTexto = 'Coinciden';
      badgeIcon = Icons.check_circle_rounded;
    } else if (estado == 'DISCREPANCIA') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeBorder = const Color(0xFFFECACA);
      badgeColor = const Color(0xFFDC2626);
      badgeTexto = 'Discrepan';
      badgeIcon = Icons.warning_amber_rounded;
    } else if (estado == 'SOLO_A') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFFBFDBFE);
      badgeColor = const Color(0xFF2563EB);
      badgeTexto = 'Solo en A';
      badgeIcon = Icons.info_outline_rounded;
    } else {
      badgeBg = const Color(0xFFF5F3FF);
      badgeBorder = const Color(0xFFDDD6FE);
      badgeColor = const Color(0xFF7C3AED);
      badgeTexto = 'Solo en B';
      badgeIcon = Icons.info_outline_rounded;
    }

    return Container(
      color: isEven ? Colors.white : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Producto
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'SKU: prd-${prodId.padLeft(4, '0')}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Conteo Sesión 1
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                conteoA != null ? '$conteoA u.' : '—',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: conteoA != null ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          // Conteo Sesión 2
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                conteoB != null ? '$conteoB u.' : '—',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: conteoB != null ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),

          // Diferencia entre ellas
          SizedBox(
            width: 140,
            child: Center(
              child: dif != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dif == 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dif == 0 ? '0 u. (Iguales)' : '${dif.abs()} u. dif.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: dif == 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    )
                  : const Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
          ),

          // Stock Sistema
          SizedBox(
            width: 110,
            child: Center(
              child: Text(
                '$stockSistema u.',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),

          // Estado
          SizedBox(
            width: 130,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      badgeTexto,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final coincidentes = _comparativaData != null ? (_comparativaData!['totalCoincidentes'] ?? 0) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'Doble Conteo a Ciegas: Los productos coincidentes ofrecen máxima certeza para ajuste de inventario.',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const Text('Cerrar', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (coincidentes > 0) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _aprobarTodosCoincidentes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: Text(
                    'Aprobar Coincidentes ($coincidentes)',
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
