import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/conteo_inventario.dart';
import 'package:pharma_salud/screens/Admin/ajusteInventario/dialog_conteo_cruzado.dart';
import 'package:pharma_salud/utils/ticket_printer.dart';

class ModalHistorialInventariosPOS extends StatefulWidget {
  final int? userId;
  final String userName;
  final bool esAdmin;

  const ModalHistorialInventariosPOS({
    super.key,
    this.userId,
    required this.userName,
    this.esAdmin = false,
  });

  static Future<void> show(
    BuildContext context, {
    int? userId,
    required String userName,
    bool esAdmin = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ModalHistorialInventariosPOS(
        userId: userId,
        userName: userName,
        esAdmin: esAdmin,
      ),
    );
  }

  @override
  State<ModalHistorialInventariosPOS> createState() => _ModalHistorialInventariosPOSState();
}

class _ModalHistorialInventariosPOSState extends State<ModalHistorialInventariosPOS> {
  final ConteoInventarioRepository _conteoRepo = ConteoInventarioRepository();

  // Filtros
  String _filtroModo = 'TODOS'; // 'TODOS', 'GLOBAL', 'INDIVIDUAL'
  String _filtroTipoDetalle = 'TODOS'; // 'TODOS', 'CONFORME', 'SOBRANTE', 'FALTANTE'
  final TextEditingController _busquedaDetalleController = TextEditingController();
  String _busquedaDetalleTexto = '';

  // Datos
  List<Map<String, dynamic>> _sesiones = [];
  Map<String, dynamic>? _sesionSeleccionada;
  List<Map<String, dynamic>> _detalleProductos = [];

  bool _cargandoSesiones = true;
  bool _cargandoDetalle = false;
  bool _imprimiendo = false;

  @override
  void initState() {
    super.initState();
    _cargarSesiones();
    _busquedaDetalleController.addListener(() {
      setState(() {
        _busquedaDetalleTexto = _busquedaDetalleController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _busquedaDetalleController.dispose();
    super.dispose();
  }

  Future<void> _cargarSesiones({String? codigoParaSeleccionar}) async {
    setState(() => _cargandoSesiones = true);
    try {
      final lista = await _conteoRepo.obtenerHistorialInventariosPOS(
        usuarioId: widget.esAdmin ? null : widget.userId,
        modo: _filtroModo,
      );

      if (mounted) {
        setState(() {
          _sesiones = lista;
          _cargandoSesiones = false;
        });

        if (lista.isNotEmpty) {
          Map<String, dynamic>? encontrada;
          if (codigoParaSeleccionar != null) {
            encontrada = lista.firstWhere(
              (s) => s['CODIGO'] == codigoParaSeleccionar,
              orElse: () => lista.first,
            );
          } else if (_sesionSeleccionada != null) {
            encontrada = lista.firstWhere(
              (s) => s['CODIGO'] == _sesionSeleccionada!['CODIGO'],
              orElse: () => lista.first,
            );
          } else {
            encontrada = lista.first;
          }
          _seleccionarSesion(encontrada);
        } else {
          setState(() {
            _sesionSeleccionada = null;
            _detalleProductos = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoSesiones = false);
      }
    }
  }

  Future<void> _seleccionarSesion(Map<String, dynamic> sesion) async {
    setState(() {
      _sesionSeleccionada = sesion;
      _cargandoDetalle = true;
      _filtroTipoDetalle = 'TODOS';
      _busquedaDetalleController.clear();
      _busquedaDetalleTexto = '';
    });

    try {
      final codigo = sesion['CODIGO'] as String;
      final detalle = await _conteoRepo.obtenerDetalleSesionInventario(codigo);
      if (mounted) {
        setState(() {
          _detalleProductos = detalle;
          _cargandoDetalle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoDetalle = false);
      }
    }
  }

  Future<void> _imprimirTicketSesion() async {
    if (_sesionSeleccionada == null || _detalleProductos.isEmpty || _imprimiendo) return;

    setState(() => _imprimiendo = true);
    try {
      final sesion = _sesionSeleccionada!;
      final codigo = sesion['CODIGO']?.toString() ?? 'INV';
      final usuario = sesion['NOMBRE_USUARIO']?.toString() ?? widget.userName;
      final modo = sesion['MODO']?.toString() ?? 'GLOBAL';
      final fecha = _formatearFecha(sesion['FECHA_FIN']?.toString() ?? sesion['FECHA_INICIO']?.toString());
      final totalConf = (sesion['TOTAL_CONFORMES'] as num?)?.toInt() ?? 0;
      final totalSob = (sesion['TOTAL_SOBRANTES'] as num?)?.toInt() ?? 0;
      final totalFal = (sesion['TOTAL_FALTANTES'] as num?)?.toInt() ?? 0;

      await TicketPrinter.imprimirTicketInventario(
        sesionCodigo: codigo,
        vendedor: usuario,
        modo: modo == 'GLOBAL' ? 'Hoja Compartida' : 'Individual',
        fechaHora: fecha,
        items: _detalleProductos,
        totalConformes: totalConf,
        totalSobrantes: totalSob,
        totalFaltantes: totalFal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF34C759),
            content: Text('Comprobante de inventario impreso con éxito.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF3B30),
            content: Text('Error al imprimir ticket: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _imprimiendo = false);
      }
    }
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(fechaStr);
      return DateFormat('dd/MM/yyyy hh:mm a').format(dt);
    } catch (_) {
      return fechaStr;
    }
  }

  List<Map<String, dynamic>> get _itemsDetalleFiltrados {
    return _detalleProductos.where((item) {
      // Filtro tipo
      final dif = (item['DIFERENCIA'] as num?)?.toInt() ?? 0;
      if (_filtroTipoDetalle == 'CONFORME' && dif != 0) return false;
      if (_filtroTipoDetalle == 'SOBRANTE' && dif <= 0) return false;
      if (_filtroTipoDetalle == 'FALTANTE' && dif >= 0) return false;

      // Filtro texto
      if (_busquedaDetalleTexto.isNotEmpty) {
        final nombre = (item['NOMBRE_PRODUCTO'] ?? '').toString().toLowerCase();
        final barra = (item['CODIGO_BARRA'] ?? '').toString().toLowerCase();
        final id = item['PRODUCTO_ID']?.toString().toLowerCase() ?? '';
        final nota = (item['NOTA'] ?? '').toString().toLowerCase();

        return nombre.contains(_busquedaDetalleTexto) ||
            barra.contains(_busquedaDetalleTexto) ||
            id.contains(_busquedaDetalleTexto) ||
            nota.contains(_busquedaDetalleTexto);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.90).clamp(900.0, 1140.0);
    final dialogHeight = (size.height * 0.88).clamp(600.0, 750.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Row(
                  children: [
                    // Columna izquierda: Lista de Sesiones
                    SizedBox(
                      width: 380,
                      child: _buildPanelSesiones(),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Color(0xFFE5E7EB),
                    ),
                    // Columna derecha: Detalle de Productos
                    Expanded(
                      child: _buildPanelDetalle(),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF007AFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.esAdmin
                        ? 'Historial de Conteos del POS (Auditoría)'
                        : 'Historial de Conteos de Inventario',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  Text(
                    widget.esAdmin
                        ? 'Auditoría histórica de todos los reportes de conteo físico registrados por las encargadas'
                        : 'Auditoría física de reportes enviados y resoluciones aprobadas por el Administrador',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (widget.esAdmin && _sesiones.length >= 2) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    DialogConteoCruzado.show(
                      context,
                      initialSesionA: _sesionSeleccionada?['CODIGO'],
                    );
                  },
                  icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                  label: const Text(
                    'Comparar Conteos',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelSesiones() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Column(
        children: [
          // Selector de modalidad
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _filtroModoBtn('TODOS', 'Todos'),
                  _filtroModoBtn('GLOBAL', 'Compartida'),
                  _filtroModoBtn('INDIVIDUAL', widget.esAdmin ? 'Por Turno' : 'Mi Turno'),
                ],
              ),
            ),
          ),

          // Contador de sesiones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_sesiones.length} sesiones registradas',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                InkWell(
                  onTap: () => _cargarSesiones(),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF007AFF)),
                        SizedBox(width: 4),
                        Text(
                          'Actualizar',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Lista de Sesiones
          Expanded(
            child: _cargandoSesiones
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF007AFF),
                    ),
                  )
                : _sesiones.isEmpty
                    ? _buildEstadoVacioSesiones()
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sesiones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sesion = _sesiones[index];
                          final isSelected = _sesionSeleccionada != null &&
                              _sesionSeleccionada!['CODIGO'] == sesion['CODIGO'];
                          return _buildSesionCard(sesion, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filtroModoBtn(String valor, String label) {
    final activo = _filtroModo == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_filtroModo != valor) {
            setState(() => _filtroModo = valor);
            _cargarSesiones();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              color: activo ? const Color(0xFF1D1D1F) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSesionCard(Map<String, dynamic> sesion, bool isSelected) {
    final codigo = sesion['CODIGO']?.toString() ?? 'INV';
    final modo = sesion['MODO']?.toString() ?? 'GLOBAL';
    final estado = sesion['ESTADO_SESION']?.toString() ?? 'ENVIADO';
    final isAplicado = estado == 'APLICADO';
    final usuario = sesion['NOMBRE_USUARIO']?.toString() ?? 'Operador';
    final fecha = _formatearFecha(sesion['FECHA_FIN']?.toString() ?? sesion['FECHA_INICIO']?.toString());

    final totalProd = (sesion['TOTAL_PRODUCTOS'] as num?)?.toInt() ?? 0;
    final conf = (sesion['TOTAL_CONFORMES'] as num?)?.toInt() ?? 0;
    final sob = (sesion['TOTAL_SOBRANTES'] as num?)?.toInt() ?? 0;
    final fal = (sesion['TOTAL_FALTANTES'] as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _seleccionarSesion(sesion),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Código de sesión y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        modo == 'GLOBAL' ? Icons.groups_outlined : Icons.person_outline_rounded,
                        size: 15,
                        color: const Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        codigo,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1D1D1F),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAplicado ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAplicado ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAplicado ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          size: 12,
                          color: isAplicado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAplicado ? 'Aplicado Admin' : 'Pendiente',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isAplicado ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Fila 2: Fecha y Operador
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    fecha,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    usuario,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Fila 3: Badges de conteo (Conformes, Sobrantes, Faltantes)
              Row(
                children: [
                  _badgeConteo(
                    label: '$totalProd prod.',
                    color: const Color(0xFF6B7280),
                    bgColor: const Color(0xFFF3F4F6),
                  ),
                  const SizedBox(width: 4),
                  _badgeConteo(
                    label: '$conf ok',
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  if (sob > 0) ...[
                    const SizedBox(width: 4),
                    _badgeConteo(
                      label: '+$sob sob.',
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                  ],
                  if (fal > 0) ...[
                    const SizedBox(width: 4),
                    _badgeConteo(
                      label: '-$fal falt.',
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeConteo({
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEstadoVacioSesiones() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 32,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin reportes en esta categoría',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Los inventarios enviados desde el POS aparecerán registrados aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelDetalle() {
    if (_sesionSeleccionada == null) {
      return const Center(
        child: Text(
          'Selecciona un inventario para ver los productos auditados',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    final sesion = _sesionSeleccionada!;
    final codigo = sesion['CODIGO']?.toString() ?? 'INV';
    final estado = sesion['ESTADO_SESION']?.toString() ?? 'ENVIADO';
    final isAplicado = estado == 'APLICADO';
    final modo = sesion['MODO']?.toString() ?? 'GLOBAL';
    final usuario = sesion['NOMBRE_USUARIO']?.toString() ?? 'Operador';
    final fecha = _formatearFecha(sesion['FECHA_FIN']?.toString() ?? sesion['FECHA_INICIO']?.toString());

    final totalProd = (sesion['TOTAL_PRODUCTOS'] as num?)?.toInt() ?? 0;
    final conf = (sesion['TOTAL_CONFORMES'] as num?)?.toInt() ?? 0;
    final sob = (sesion['TOTAL_SOBRANTES'] as num?)?.toInt() ?? 0;
    final fal = (sesion['TOTAL_FALTANTES'] as num?)?.toInt() ?? 0;

    final filtrados = _itemsDetalleFiltrados;

    return Column(
      children: [
        // Barra superior de detalle
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            codigo,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAplicado ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isAplicado ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAplicado ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                                  size: 13,
                                  color: isAplicado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isAplicado ? 'Ajuste Aplicado en Stock' : 'Pendiente de Ajuste Admin',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isAplicado ? const Color(0xFF166534) : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Modo: ${modo == 'GLOBAL' ? 'Hoja Compartida' : 'Individual'} • Realizado por: $usuario • Fecha: $fecha',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),

                  // Botón Imprimir Ticket
                  ElevatedButton.icon(
                    onPressed: _imprimiendo ? null : _imprimirTicketSesion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D1D1F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _imprimiendo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 17),
                    label: Text(
                      _imprimiendo ? 'Imprimiendo...' : 'Imprimir Ticket',
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Métricas de la sesión seleccionada
              Row(
                children: [
                  _resumenCard('Total Verificados', '$totalProd', const Color(0xFF4B5563), const Color(0xFFF3F4F6)),
                  const SizedBox(width: 10),
                  _resumenCard('Conformes (OK)', '$conf', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
                  const SizedBox(width: 10),
                  _resumenCard('Sobrantes (+)', '$sob', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                  const SizedBox(width: 10),
                  _resumenCard('Faltantes (-)', '$fal', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                ],
              ),
            ],
          ),
        ),

        // Filtro y buscador dentro del detalle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _busquedaDetalleController,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar en productos contados por nombre, código...',
                      hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _filtroDetalleChip('TODOS', 'Todos ($totalProd)'),
              const SizedBox(width: 6),
              _filtroDetalleChip('CONFORME', 'Conformes ($conf)'),
              const SizedBox(width: 6),
              _filtroDetalleChip('SOBRANTE', 'Sobrantes ($sob)'),
              const SizedBox(width: 6),
              _filtroDetalleChip('FALTANTE', 'Faltantes ($fal)'),
            ],
          ),
        ),

        // Tabla de productos contados
        Expanded(
          child: _cargandoDetalle
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF007AFF)),
                )
              : filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos que coincidan con el filtro',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF9CA3AF)),
                      ),
                    )
                  : ListView(
                      children: [
                        _buildTableHeader(),
                        ...filtrados.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildTableRow(item, index);
                        }),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _resumenCard(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtroDetalleChip(String valor, String label) {
    final activo = _filtroTipoDetalle == valor;
    return InkWell(
      onTap: () {
        setState(() => _filtroTipoDetalle = valor);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1D1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? const Color(0xFF1D1D1F) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11.5,
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
            color: activo ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'DESCRIPCIÓN DEL PRODUCTO',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'STOCK SIST.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'FÍSICO',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'DIFERENCIA',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'ESTADO',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'OBSERVACIÓN / NOTA',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> item, int index) {
    final nombre = item['NOMBRE_PRODUCTO'] ?? 'Producto #${item['PRODUCTO_ID']}';
    final prodId = item['PRODUCTO_ID']?.toString() ?? '';
    final codigoBarra = item['CODIGO_BARRA']?.toString() ?? '';
    final stockSistema = (item['STOCK_SISTEMA'] as num?)?.toInt() ?? 0;
    final conteoFisico = (item['CONTEO_FISICO'] as num?)?.toInt() ?? 0;
    final dif = (item['DIFERENCIA'] as num?)?.toInt() ?? (conteoFisico - stockSistema);
    final nota = item['NOTA']?.toString() ?? '';

    Color difColor;
    String difText;
    Color difBg;

    if (dif == 0) {
      difColor = const Color(0xFF16A34A);
      difBg = const Color(0xFFF0FDF4);
      difText = '0';
    } else if (dif > 0) {
      difColor = const Color(0xFF2563EB);
      difBg = const Color(0xFFEFF6FF);
      difText = '+$dif';
    } else {
      difColor = const Color(0xFFDC2626);
      difBg = const Color(0xFFFEF2F2);
      difText = '$dif';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // Producto
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                Text(
                  'SKU: prd-${prodId.padLeft(4, '0')} ${codigoBarra.isNotEmpty ? '• Barra: $codigoBarra' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),

          // Stock Sistema
          SizedBox(
            width: 90,
            child: Text(
              '$stockSistema',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
          ),

          // Conteo Físico
          SizedBox(
            width: 90,
            child: Text(
              '$conteoFisico',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D1D1F),
              ),
            ),
          ),

          // Diferencia
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: difBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  difText,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: difColor,
                  ),
                ),
              ),
            ),
          ),

          // Estado
          SizedBox(
            width: 110,
            child: Center(
              child: Text(
                dif == 0 ? 'Conforme' : (dif > 0 ? 'Sobrante' : 'Faltante'),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: difColor,
                ),
              ),
            ),
          ),

          // Nota
          Expanded(
            flex: 3,
            child: Text(
              nota.isNotEmpty ? nota : '—',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11.5,
                color: nota.isNotEmpty ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                fontStyle: nota.isNotEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                widget.esAdmin
                    ? 'Vista de Auditoría General de Inventarios • Administrador: ${widget.userName}'
                    : 'Sesiones agrupadas por fecha y turno de conteo. Operador actual: ${widget.userName}',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Cerrar Historial',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
