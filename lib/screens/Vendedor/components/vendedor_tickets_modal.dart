import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/utils/ticket_printer.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class VendedorTicketsModal extends StatefulWidget {
  final int userId;
  final String userName;

  const VendedorTicketsModal({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  _VendedorTicketsModalState createState() => _VendedorTicketsModalState();
}

class _VendedorTicketsModalState extends State<VendedorTicketsModal> {
  final RegistroVentasRepository _repository = RegistroVentasRepository();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _vendedores = [];
  bool _isLoading = false;

  // Filtros
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  int? _selectedVendedorId;
  bool _soloDevolucion = false;
  final TextEditingController _productoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVendedores();
  }

  @override
  void dispose() {
    _productoController.dispose();
    super.dispose();
  }

  Color _getTipoVentaColor(String tipoVenta) {
    final tipo = tipoVenta.toLowerCase();
    if (tipo.contains('caja')) {
      return const Color(0xFFEA580C); // Naranja para Caja
    } else if (tipo.contains('blister')) {
      return const Color(0xFF7C3AED); // Violeta/Morado para Blíster
    } else {
      return const Color(0xFF059669); // Verde Esmeralda para Unidad
    }
  }

  Color _getMetodoPagoColor(String? metodo) {
    final mp = (metodo == 'Física' || metodo == null || metodo.isEmpty) ? 'Efectivo' : metodo;
    if (mp.toLowerCase().contains('yape')) {
      return const Color(0xFF7D52F4); // Morado Yape
    } else if (mp.toLowerCase().contains('tarjeta')) {
      return const Color(0xFF007AFF); // Azul Tarjeta
    } else {
      return const Color(0xFF34C759); // Verde Efectivo
    }
  }

  Future<void> _loadVendedores() async {
    final vendedores = await _usuarioRepository.readUsuariosV02();
    if (mounted) {
      setState(() {
        _vendedores = vendedores;
        if (_vendedores.any((v) => v['ID_USUARIO'] == widget.userId)) {
          _selectedVendedorId = widget.userId;
        }
      });
      _fetchTickets();
    }
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startStr =
        "$dateStr ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00";
    final endStr =
        "$dateStr ${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:59";

    try {
      final tickets = await _repository.obtenerTicketsConFiltros(
        fechaInicio: startStr,
        fechaFin: endStr,
        usuarioId: _selectedVendedorId,
        soloConDevolucion: _soloDevolucion,
        productoBuscar: _productoController.text,
      );
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
                    duration: const Duration(milliseconds: 800),
                    content: Text('Error al cargar tickets: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchTickets();
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF3B30),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
      _fetchTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 700, // Ancho optimizado para panel lateral
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(10, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterBar(),
              Expanded(
                child: ClipRect(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFF3B30), strokeWidth: 3))
                      : _tickets.isEmpty
                          ? _buildEmptyState()
                          : _buildTicketsList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topRight: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.confirmation_number_rounded,
                    color: Color(0xFFFF3B30), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tickets de Venta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Outfit',
                      color: Color(0xFF1D1D1F),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Historial y gestión de recibos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Outfit',
                      color: const Color(0xFF1D1D1F).withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _fetchTickets,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F7),
                  foregroundColor: const Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F7),
                  foregroundColor: const Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1),
        ),
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
          _buildFilterItem(
            label: 'VENDEDOR RESPONSABLE',
            child: SizedBox(
              height: 44,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: CustomDropdown<String>(
                hintText: 'Todos los vendedores',
                items: [
                  'Todos los vendedores',
                  ..._vendedores.map((v) => v['NOMBRE_VENDEDOR'] as String)
                ],
                initialItem: _selectedVendedorId == null
                    ? 'Todos los vendedores'
                    : _vendedores.firstWhere(
                        (v) => v['ID_USUARIO'] == _selectedVendedorId,
                        orElse: () => {'NOMBRE_VENDEDOR': 'Todos los vendedores'})['NOMBRE_VENDEDOR'],
                onChanged: (val) {
                  setState(() {
                    if (val == 'Todos los vendedores' || val == null) {
                      _selectedVendedorId = null;
                    } else {
                      final user = _vendedores.firstWhere(
                          (v) => v['NOMBRE_VENDEDOR'] == val);
                      _selectedVendedorId = user['ID_USUARIO'];
                    }
                  });
                  _fetchTickets();
                },
                decoration: CustomDropdownDecoration(
                  closedFillColor: const Color(0xFFF5F5F7),
                  expandedFillColor: Colors.white,
                  closedBorder: Border.all(color: const Color(0xFFE5E5EA)),
                  closedBorderRadius: BorderRadius.circular(10),
                  expandedBorderRadius: BorderRadius.circular(10),
                  hintStyle: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: const Color(0xFF1D1D1F).withOpacity(0.5),
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
          ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFilterItem(
                  label: 'FECHA',
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 14, color: Color(0xFFFF3B30)),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterItem(
                  label: 'HORARIO',
                  child: Row(
                    children: [
                      _buildTimePickerButton(true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('-',
                            style: TextStyle(
                                color: Color(0xFF8E8E93), fontSize: 14)),
                      ),
                      _buildTimePickerButton(false),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildFilterItem(
                label: 'ESTADO',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _soloDevolucion = !_soloDevolucion);
                      _fetchTickets();
                    },
                    child: Container(
                    height: 44,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _soloDevolucion
                          ? const Color(0xFFFF9500).withOpacity(0.1)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _soloDevolucion
                            ? const Color(0xFFFF9500).withOpacity(0.3)
                            : const Color(0xFFE5E5EA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _soloDevolucion
                              ? Icons.filter_alt_rounded
                              : Icons.filter_alt_outlined,
                          size: 16,
                          color: _soloDevolucion
                              ? const Color(0xFFFF9500)
                              : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _soloDevolucion ? 'DEVUELTOS' : 'TODOS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Outfit',
                            color: _soloDevolucion
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
          const SizedBox(height: 16),
          _buildFilterItem(
            label: 'BUSCAR PRODUCTO EN TICKET',
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: const Color(0xFF1D1D1F).withOpacity(0.3),
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _productoController,
                      decoration: InputDecoration(
                        hintText: 'Escribe el nombre del producto...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF1D1D1F).withOpacity(0.3),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Outfit',
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Outfit',
                          color: Color(0xFF1D1D1F)),
                      onChanged: (val) => _fetchTickets(),
                    ),
                  ),
                  if (_productoController.text.isNotEmpty)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _productoController.clear();
                        _fetchTickets();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerButton(bool isStart) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () => _selectTime(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        width: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Text(
          isStart ? _startTime.format(context) : _endTime.format(context),
          style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D1D1F)),
        ),
      ),
    );
  }

  Widget _buildFilterItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8E8E93),
            letterSpacing: 0.8,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTicketsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final fechaObj = DateTime.parse(ticket['FECHA']);
        final String totalStr =
            formatMoney(ticket['TOTAL'] as num? ?? 0.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: InkWell(
            onTap: () => _showTicketDetails(ticket),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF1D1D1F), size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Comprobante #${ticket['ID']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final rawMp = ticket['METODO_PAGO'] as String?;
                                final mp = (rawMp == 'Física' || rawMp == null || rawMp.isEmpty) ? 'Efectivo' : rawMp;
                                final colorMp = _getMetodoPagoColor(mp);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorMp.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mp.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: colorMp,
                                      letterSpacing: 0.5,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (ticket['TIENE_DEVOLUCION'] == 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9500).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DEVUELTO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF9500),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 14,
                                color:
                                    const Color(0xFF1D1D1F).withOpacity(0.4)),
                            const SizedBox(width: 4),
                            Text(
                              ticket['NOMBRE_USUARIO'] ?? 'Vendedor',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.schedule_rounded,
                                size: 14,
                                color:
                                    const Color(0xFF1D1D1F).withOpacity(0.4)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('hh:mm a').format(fechaObj),
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF1D1D1F).withOpacity(0.5),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'S/ $totalStr',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF3B30),
                          fontSize: 22,
                          fontFamily: 'Outfit',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Color(0xFFE5E5EA)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DetailsSheet(ticket: ticket),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03), blurRadius: 20),
              ],
            ),
            child: Icon(Icons.receipt_long_outlined,
                size: 64, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin registros encontrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay tickets que coincidan con los filtros seleccionados',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Outfit',
              color: const Color(0xFF1D1D1F).withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSheet extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _DetailsSheet({required this.ticket});

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  final repository = RegistroVentasRepository();
  List<Map<String, dynamic>>? _detalles;
  bool _isPrinting = false;

  Color _getTipoVentaColor(String tipoVenta) {
    final tipo = tipoVenta.toLowerCase();
    if (tipo.contains('caja')) {
      return const Color(0xFFEA580C);
    } else if (tipo.contains('blister')) {
      return const Color(0xFF7C3AED);
    } else {
      return const Color(0xFF059669);
    }
  }

  Color _getMetodoPagoColor(String? metodo) {
    final mp = (metodo == 'Física' || metodo == null || metodo.isEmpty) ? 'Efectivo' : metodo;
    if (mp.toLowerCase().contains('yape')) {
      return const Color(0xFF7D52F4);
    } else if (mp.toLowerCase().contains('tarjeta')) {
      return const Color(0xFF007AFF);
    } else {
      return const Color(0xFF34C759);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDetalles();
  }

  Future<void> _loadDetalles() async {
    final detalles =
        await repository.obtenerDetallesDeTicket(widget.ticket['ID']);
    if (mounted) setState(() => _detalles = detalles);
  }

  @override
  Widget build(BuildContext context) {
    final String fechaStr = DateFormat('dd MMM yyyy, hh:mm a')
        .format(DateTime.parse(widget.ticket['FECHA']));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2.5)),
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // Digital Receipt Header
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            final rawMp = widget.ticket['METODO_PAGO'] as String?;
                            final mp = (rawMp == 'Física' || rawMp == null || rawMp.isEmpty) ? 'Efectivo' : rawMp;
                            final colorMp = _getMetodoPagoColor(mp);
                            final iconMp = mp.toLowerCase().contains('yape')
                                ? Icons.qr_code_scanner_rounded
                                : mp.toLowerCase().contains('tarjeta')
                                    ? Icons.credit_card_rounded
                                    : Icons.payments_rounded;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorMp.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconMp, color: colorMp, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PAGADO CON ${mp.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: colorMp,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'S/ ${formatMoney(widget.ticket['TOTAL'] as num? ?? 0.0)}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Outfit',
                            letterSpacing: -1,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ticket #${widget.ticket['ID']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E8E93),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFF2F2F7)),
                        const SizedBox(height: 20),
                        _receiptInfoRow('Vendedor',
                            widget.ticket['NOMBRE_USUARIO'] ?? 'N/A'),
                        const SizedBox(height: 12),
                        _receiptInfoRow('Fecha y Hora', fechaStr),
                        const SizedBox(height: 12),
                        _receiptInfoRow('Método de Pago', (widget.ticket['METODO_PAGO'] == 'Física' || widget.ticket['METODO_PAGO'] == null) ? 'Efectivo' : widget.ticket['METODO_PAGO']),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Items Summary
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'RESUMEN DE PRODUCTOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8E8E93),
                        letterSpacing: 1.2,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _detalles == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFF3B30)))
                      : Column(
                          children: _detalles!.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE5E5EA)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item['CANTIDAD']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['NOMBRE_PRODUCTO'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              fontFamily: 'Outfit'),
                                        ),
                                        Row(
                                          children: [
                                            Builder(
                                              builder: (context) {
                                                final colorTipo = _getTipoVentaColor('${item['TIPO_VENTA']}');
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: colorTipo.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${item['TIPO_VENTA']}'.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: colorTipo,
                                                      fontFamily: 'Outfit'),
                                                  ),
                                                );
                                              },
                                            ),
                                            if (item['DEVOLUCION'] == 'Si') ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF9500)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'DEVUELTO',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFFFF9500),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'S/ ${formatMoney(item['PRECIO_VENTA'] as num? ?? 0.0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('CERRAR',
                        style: TextStyle(
                            fontFamily: 'Outfit', fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1D1D1F),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFFE5E5EA)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_detalles == null || _isPrinting)
                        ? null
                        : () async {
                            setState(() => _isPrinting = true);
                            try {
                              await TicketPrinter.imprimirTicket(
                                detalles: _detalles!,
                                total: widget.ticket['TOTAL'].toDouble(),
                                pagoCon: (widget.ticket['PAGO_CON'] ?? 0.0)
                                    .toDouble(),
                                vuelto:
                                    (widget.ticket['VUELTO'] ?? 0.0).toDouble(),
                                ticketId: widget.ticket['ID'].toString(),
                                vendedor: widget.ticket['NOMBRE_USUARIO'],
                                fecha: widget.ticket['FECHA'],
                                metodoPago: (widget.ticket['METODO_PAGO'] == 'Física' || widget.ticket['METODO_PAGO'] == null)
                                    ? 'Efectivo'
                                    : widget.ticket['METODO_PAGO'],
                              );
                            } finally {
                              if (mounted) setState(() => _isPrinting = false);
                            }
                          },
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print_rounded, size: 20),
                    label: const Text('REIMPRIMIR TICKET',
                        style: TextStyle(
                            fontFamily: 'Outfit', fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      enabledMouseCursor: SystemMouseCursors.click,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF1D1D1F).withOpacity(0.5),
            fontFamily: 'Outfit',
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }
}
