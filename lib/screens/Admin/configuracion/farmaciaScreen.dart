import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/farmacia.dart';
import 'package:pharma_salud/repositories/usuarios.dart';

class FarmaciaConfigScreen extends StatefulWidget {
  final VoidCallback? onFarmaciaCambiada;

  const FarmaciaConfigScreen({super.key, this.onFarmaciaCambiada});

  @override
  State<FarmaciaConfigScreen> createState() => _FarmaciaConfigScreenState();
}

class _FarmaciaConfigScreenState extends State<FarmaciaConfigScreen> {
  final FarmaciaRepository _repo = FarmaciaRepository();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();
  List<Map<String, dynamic>> _farmacias = [];
  bool _loading = true;
  int _currentTab = 0; // 0 = Farmacias, 1 = Seguridad y PIN Discreto
  String _currentPin = '1234';
  bool _showPin = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarPin();
  }

  Future<void> _cargarPin() async {
    final pin = await _usuarioRepo.getPinModoOculto();
    if (mounted) {
      setState(() {
        _currentPin = pin;
      });
    }
  }

  Future<void> _cargar() async {
    final data = await _repo.obtenerTodas();
    setState(() {
      _farmacias = data;
      _loading = false;
    });
  }

  Future<void> _cargarYNotificar() async {
    await _cargar();
    widget.onFarmaciaCambiada?.call();
  }

  Future<void> _agregar() async {
    final nombre = await _mostrarDialogoNombre('Nueva Farmacia', '');
    if (nombre != null && nombre.isNotEmpty) {
      await _repo.crear(nombre: nombre);
      await _cargarYNotificar();
    }
  }

  Future<void> _editar(Map<String, dynamic> farmacia) async {
    final nombre = await _mostrarDialogoNombre('Editar Farmacia', farmacia['NOMBRE'] ?? '');
    if (nombre != null && nombre.isNotEmpty) {
      await _repo.actualizar(id: farmacia['ID'], nombre: nombre);
      await _cargarYNotificar();
    }
  }

  Future<String?> _mostrarDialogoNombre(String titulo, String valorInicial) {
    final controller = TextEditingController(text: valorInicial);
    final isEditing = valorInicial.trim().isNotEmpty;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFFFF3B30),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEditing
                                  ? 'Modifica el nombre de la sucursal'
                                  : 'Registra una nueva sucursal o botica',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOMBRE DEL ESTABLECIMIENTO',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 50,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                        onSubmitted: (val) {
                          final text = val.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx, text);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Ej: Pharma Salud - Sucursal Centro',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                            fontFamily: 'Outfit',
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          prefixIcon: Icon(
                            Icons.store_outlined,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: const Color(0xFF1D1D1F).withOpacity(0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF3B30),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6C757D),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx, text);
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          isEditing ? 'Guardar Cambios' : 'Crear Farmacia',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _establecerActiva(int id) async {
    await _repo.establecerActiva(id);
    await _cargarYNotificar();
  }

  Future<void> _eliminar(Map<String, dynamic> farmacia) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFFF3B30),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Eliminar Farmacia',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Estás seguro de que deseas eliminar "${farmacia['NOMBRE']}"?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C757D),
                    fontFamily: 'Outfit',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Esta acción no se puede deshacer.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6C757D),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      final activaEliminada = farmacia['ACTIVA'] == 1;
      await _repo.eliminar(farmacia['ID']);
      if (activaEliminada) {
        final restantes = await _repo.obtenerTodas();
        if (restantes.isNotEmpty) {
          await _repo.establecerActiva(restantes.first['ID']);
        }
      }
      await _cargarYNotificar();
    }
  }

  Future<void> _cambiarPinDialog() async {
    final nuevoPinController = TextEditingController();
    final confirmarPinController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF5856D6)),
              SizedBox(width: 10),
              Text(
                'Cambiar PIN Maestro',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text(
                'Este PIN se utilizará para desbloquear la visualización de productos ocultos en el POS del vendedor.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6C757D), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nuevoPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nuevo PIN',
                  hintText: 'Ej: 1234',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5856D6), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmarPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Confirmar PIN',
                  hintText: 'Repita el nuevo PIN',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5856D6), width: 1.5),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C757D)),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final p1 = nuevoPinController.text.trim();
                final p2 = confirmarPinController.text.trim();
                if (p1.isEmpty) {
                  setDialogState(() => error = 'El PIN no puede estar vacío.');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => error = 'Los PINs no coinciden.');
                  return;
                }
                await _usuarioRepo.setPinModoOculto(p1);
                Navigator.pop(ctx);
                await _cargarPin();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('PIN Maestro actualizado correctamente'),
                      backgroundColor: const Color(0xFF34C759),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5856D6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Guardar PIN', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentTab == 0 ? 'Farmacias' : 'Seguridad y Modo Discreto',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentTab == 0
                          ? 'Administra las sucursales y selecciona la activa'
                          : 'Configuración de PIN de seguridad y productos ocultos en el POS',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                if (_currentTab == 0)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _agregar,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            child: Row(
                              children: [
                                Icon(Icons.add_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('AGREGAR',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.8)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Pestañas de configuración
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tabButton(0, 'Sucursales / Farmacias', Icons.store_rounded),
                  const SizedBox(width: 4),
                  _tabButton(1, 'Seguridad y Modo Discreto', Icons.shield_rounded),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _currentTab == 0 ? _buildFarmaciasTab() : _buildSeguridadTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF1D1D1F) : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF1D1D1F) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmaciasTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _farmacias.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No hay farmacias registradas',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Presiona "AGREGAR" para crear una',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _farmacias.length,
                itemBuilder: (_, i) {
                  final f = _farmacias[i];
                  final activa = f['ACTIVA'] == 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: activa
                                ? const Color(0xFF34C759).withOpacity(0.5)
                                : Colors.grey.shade200,
                            width: activa ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: activa
                                  ? const Color(0xFF34C759).withOpacity(0.08)
                                  : Colors.black.withOpacity(0.03),
                              blurRadius: activa ? 16 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _establecerActiva(f['ID']),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: activa
                                          ? const Color(0xFF34C759)
                                              .withOpacity(0.1)
                                          : Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      activa
                                          ? Icons.check_circle_rounded
                                          : Icons.store_rounded,
                                      color: activa
                                          ? const Color(0xFF34C759)
                                          : Colors.grey.shade400,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          f['NOMBRE'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            fontFamily: 'Outfit',
                                            color: Color(0xFF1D1D1F),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                          decoration: BoxDecoration(
                                            color: activa
                                                ? const Color(0xFF34C759)
                                                    .withOpacity(0.1)
                                                : Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            activa
                                                ? 'Farmacia activa'
                                                : 'Inactiva',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                              color: activa
                                                  ? const Color(
                                                      0xFF34C759)
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!activa)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34C759)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF34C759),
                                        ),
                                        iconSize: 22,
                                        visualDensity:
                                            VisualDensity.compact,
                                        tooltip: 'Activar',
                                        onPressed: () =>
                                            _establecerActiva(f['ID']),
                                      ),
                                    ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.edit_outlined),
                                      iconSize: 20,
                                      visualDensity:
                                          VisualDensity.compact,
                                      color: const Color(0xFF1D1D1F)
                                          .withOpacity(0.5),
                                      tooltip: 'Editar',
                                      onPressed: () => _editar(f),
                                    ),
                                  ),
                                  if (_farmacias.length > 1)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(left: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF3B30)
                                            .withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFFF3B30),
                                        ),
                                        iconSize: 20,
                                        visualDensity:
                                            VisualDensity.compact,
                                        tooltip: 'Eliminar',
                                        onPressed: () =>
                                            _eliminar(f),
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
                },
              );
  }

  Widget _buildSeguridadTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5856D6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shield_rounded, size: 28, color: Color(0xFF5856D6)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PIN Maestro del Modo Discreto',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Outfit',
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Este PIN permite desbloquear la visualización y venta de productos ocultos en el POS del vendedor al pulsar la tecla F8 o la combinación secreta (Ctrl+Shift+H).',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontFamily: 'Outfit',
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.04)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key_rounded, size: 20, color: Color(0xFF8E8E93)),
                          const SizedBox(width: 12),
                          const Text(
                            'PIN Actual: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                          Text(
                            _showPin ? _currentPin : '•' * _currentPin.length,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Outfit',
                              letterSpacing: 3,
                              color: Color(0xFF5856D6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _showPin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            tooltip: _showPin ? 'Ocultar' : 'Ver PIN',
                            onPressed: () => setState(() => _showPin = !_showPin),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _cambiarPinDialog,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text(
                          'CAMBIAR PIN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5856D6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tarjeta Informativa
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF1D1D1F)),
                    SizedBox(width: 10),
                    Text(
                      'Instrucciones de Uso del Modo Discreto',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _instructionItem(
                  icon: Icons.keyboard_rounded,
                  title: 'Atajos de teclado en el POS',
                  description: 'Presione la tecla F8 (o la combinación Ctrl + Shift + H / O) para abrir la ventana de seguridad.',
                ),
                const SizedBox(height: 14),
                _instructionItem(
                  icon: Icons.lock_open_rounded,
                  title: 'Doble método de acceso',
                  description: 'El modal acepta tanto el PIN Maestro configurado aquí como la contraseña de cualquier Administrador.',
                ),
                const SizedBox(height: 14),
                _instructionItem(
                  icon: Icons.flash_on_rounded,
                  title: 'Ocultamiento inmediato ante clientes',
                  description: 'Para bloquear y ocultar inmediatamente todos los productos sensibles, vuelva a presionar F8, Ctrl + Shift + H o el botón BLOQUEAR DISCRETO.',
                ),
                const SizedBox(height: 14),
                _instructionItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Marcar productos como discretos',
                  description: 'En Administración > Productos (Registrar o Editar), active la opción "Producto Oculto / Discreto".',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D1F).withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF1D1D1F)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Outfit',
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'Outfit',
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
