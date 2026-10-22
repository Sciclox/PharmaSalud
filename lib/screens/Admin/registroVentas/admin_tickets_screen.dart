import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/utils/ticket_printer.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/utils/app_date_picker.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  _AdminTicketsScreenState createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
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
    _fetchTickets();
  }

  @override
  void dispose() {
    _productoController.dispose();
    super.dispose();
  }

  Future<void> _loadVendedores() async {
    final vendedores = await _usuarioRepository.readUsuariosV02();
    setState(() {
      _vendedores = vendedores;
    });
  }

  Future<void> _fetchTickets() async {
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
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text('Error al cargar tickets: $e')),
      );
      setState(() => _isLoading = false);
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
              onPrimary: Colors.white,
              onSurface: Color(0xFF1D1D1F),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildFilterBar(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : _tickets.isEmpty
                      ? _buildEmptyState()
                      : _buildTicketsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                  'Consulta de Tickets',
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
                'Búsqueda avanzada de comprobantes por horario y vendedor',
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
        OutlinedButton.icon(
          onPressed: _fetchTickets,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('REFRESCAR LISTA',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1D1D1F),
            side: BorderSide(color: const Color(0xFF1D1D1F).withOpacity(0.2)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila 1: Filtros de Fecha, Horarios, Vendedor y Estado
          Row(
            children: [
              // Filtro de Fecha
              _buildFilterItem(
                label: 'Fecha',
                child: InkWell(
                  onTap: () => _selectDate(context),
                  mouseCursor: SystemMouseCursors.click,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style:
                              const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Filtro Hora Inicio
              _buildFilterItem(
                label: 'Desde',
                child: InkWell(
                  onTap: () => _selectTime(context, true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 16, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 10),
                        Text(
                          _startTime.format(context),
                          style:
                              const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Filtro Hora Fin
              _buildFilterItem(
                label: 'Hasta',
                child: InkWell(
                  onTap: () => _selectTime(context, false),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 16, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 10),
                        Text(
                          _endTime.format(context),
                          style:
                              const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Filtro Vendedor
              Expanded(
                child: _buildFilterItem(
                  label: 'Vendedor',
                  child: SizedBox(
                    height: 44,
                    child: CustomDropdown<String>(
                      hintText: 'Todos los vendedores',
                      items: [
                        'Todos los vendedores',
                        ..._vendedores.map((v) => v['NOMBRE_USUARIO'] as String)
                      ],
                      initialItem: _selectedVendedorId == null
                          ? 'Todos los vendedores'
                          : _vendedores.firstWhere(
                              (v) => v['ID_USUARIO'] == _selectedVendedorId,
                              orElse: () => {'NOMBRE_USUARIO': 'Todos los vendedores'})['NOMBRE_USUARIO'],
                      onChanged: (val) {
                        setState(() {
                          if (val == 'Todos los vendedores' || val == null) {
                            _selectedVendedorId = null;
                          } else {
                            final user = _vendedores.firstWhere(
                                (v) => v['NOMBRE_USUARIO'] == val);
                            _selectedVendedorId = user['ID_USUARIO'];
                          }
                        });
                        _fetchTickets();
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
              const SizedBox(width: 20),
              _buildFilterItem(
                label: 'ESTADO',
                child: GestureDetector(
                  onTap: () {
                    setState(() => _soloDevolucion = !_soloDevolucion);
                    _fetchTickets();
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
            ],
          ),
          const SizedBox(height: 16),
          // Fila 2: Buscar Producto
          Row(
            children: [
              Expanded(
                child: _buildFilterItem(
                  label: 'BUSCAR PRODUCTO EN TICKET',
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1D1D1F).withOpacity(0.05)),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF1D1D1F).withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
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
      itemCount: _tickets.length,
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final fechaObj = DateTime.parse(ticket['FECHA']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_rounded,
                  color: Color(0xFFFF3B30), size: 20),
            ),
            title: Row(
              children: [
                Text(
                  'Ticket #${ticket['ID']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Outfit',
                      fontSize: 16),
                ),
                if (ticket['TIENE_DEVOLUCION'] == 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
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
                const Spacer(),
                Text(
                  'S/ ${formatMoney(ticket['TOTAL'])}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF3B30),
                      fontSize: 18,
                      fontFamily: 'Outfit'),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14,
                      color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    ticket['NOMBRE_USUARIO'],
                    style: TextStyle(
                        color: const Color(0xFF1D1D1F).withOpacity(0.6),
                        fontSize: 13,
                        fontFamily: 'Outfit'),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time_rounded,
                      size: 14,
                      color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('hh:mm a').format(fechaObj),
                    style: TextStyle(
                        color: const Color(0xFF1D1D1F).withOpacity(0.6),
                        fontSize: 13,
                        fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ),
            onTap: () => _showTicketDetails(ticket),
          ),
        );
      },
    );
  }

  Future<void> _showTicketDetails(Map<String, dynamic> ticket) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TicketDetailsSheet(ticket: ticket),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron tickets',
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
                color: const Color(0xFF1D1D1F).withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _TicketDetailsSheet({required this.ticket});

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  final repository = RegistroVentasRepository();
  List<Map<String, dynamic>>? _detalles;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadDetalles();
  }

  Future<void> _loadDetalles() async {
    final detalles =
        await repository.obtenerDetallesDeTicket(widget.ticket['ID']);
    if (mounted) {
      setState(() {
        _detalles = detalles;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de Ticket #${widget.ticket['ID']}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded,
                            size: 14, color: Color(0xFFFF3B30)),
                        const SizedBox(width: 6),
                        Text(
                          'Atendido por: ${widget.ticket['NOMBRE_USUARIO']}',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
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
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    duration: const Duration(milliseconds: 800),
                                    content: Text('Error al imprimir: $e')),
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
                                strokeWidth: 2, color: Color(0xFFFF3B30)))
                        : const Icon(Icons.print_rounded,
                            color: Color(0xFFFF3B30)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1),
                    ),
                    tooltip: 'Imprimir Ticket',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 32, color: Colors.grey.shade300),
          Expanded(
            child: _detalles == null
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
                : _detalles!.isEmpty
                    ? const Center(
                        child: Text('No hay detalles para este ticket.'))
                    : ListView.builder(
                        itemCount: _detalles!.length,
                        itemBuilder: (context, index) {
                          final d = _detalles![index];
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['NOMBRE_PRODUCTO'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            fontFamily: 'Outfit'),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${d['TIPO_VENTA']}  •  S/ ${formatMoney((d['PRECIO_VENTA'] as num) / (d['CANTIDAD'] as num))} x ${d['CANTIDAD']}',
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                                fontFamily: 'Outfit'),
                                          ),
                                          if (d['DEVOLUCION'] == 'Si') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                  'S/ ${formatMoney(d['PRECIO_VENTA'])}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      fontFamily: 'Outfit'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D1F).withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL TICKET',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1,
                          color: Color(0xFFFF3B30)),
                    ),
                    Text(
                      'S/ ${formatMoney(widget.ticket['TOTAL'])}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: Color(0xFFFF3B30),
                          fontFamily: 'Outfit'),
                    ),
                  ],
                ),
                Divider(height: 24, color: Colors.grey.shade300),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MÉTODO DE PAGO',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                    ),
                    Text(
                      '${(widget.ticket['METODO_PAGO'] == 'Física' || widget.ticket['METODO_PAGO'] == null) ? 'Efectivo' : widget.ticket['METODO_PAGO']}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: (widget.ticket['METODO_PAGO'] == 'Yape')
                              ? const Color(0xFF7D52F4)
                              : (widget.ticket['METODO_PAGO'] == 'Tarjeta')
                                  ? const Color(0xFF007AFF)
                                  : const Color(0xFF34C759),
                          fontFamily: 'Outfit'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PAGÓ CON',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                    ),
                    Text(
                      'S/ ${formatMoney(widget.ticket['PAGO_CON'] ?? 0.0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VUELTO',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: const Color(0xFF1D1D1F).withOpacity(0.4)),
                    ),
                    Text(
                      'S/ ${formatMoney(widget.ticket['VUELTO'] ?? 0.0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF34C759),
                          fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
