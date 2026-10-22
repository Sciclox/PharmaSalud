import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/screens/Admin/usuarios/editar.dart';
import 'registrar.dart'; // Asegúrate de importar la pantalla para agregar usuario

class UsuariosScreen extends StatefulWidget {
  final VoidCallback? onUserUpdated;
  const UsuariosScreen({super.key, this.onUserUpdated});

  @override
  _UsuariosScreenState createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _usuariosFiltrados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
    _searchController.addListener(_filtrarUsuarios);
  }

  Future<void> _loadUsuarios() async {
    setState(() => _isLoading = true);
    final users = await _usuarioRepository.readUsuarios();
    setState(() {
      _usuarios = users;
      _usuariosFiltrados = users;
      _isLoading = false;
    });
  }

  void _filtrarUsuarios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _usuariosFiltrados = _usuarios.where((u) {
        final nombreVendedor =
            u['NOMBRE_VENDEDOR']?.toString().toLowerCase() ?? '';
        final nombreUsuario =
            u['NOMBRE_USUARIO']?.toString().toLowerCase() ?? '';
        final rol = u['ROL']?.toString().toLowerCase() ?? '';

        return nombreVendedor.contains(query) ||
            nombreUsuario.contains(query) ||
            rol.contains(query);
      }).toList();
    });
  }

  Future<void> _confirmDeleteUsuario(int idUsuario) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Destructive Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_remove_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Eliminar Usuario',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Estás seguro de que deseas eliminar este usuario?',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Esta acción es definitiva y revocarás inmediatamente todo acceso al sistema para esta persona.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: const Color(0xFF1D1D1F).withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1D1F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Eliminar Usuario',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await _usuarioRepository.deleteUsuario(idUsuario);
      await _loadUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B30)));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Minimalista y Serio
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
                          'Usuarios',
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
                        'Directorio central de accesos y credenciales',
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
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AddUserScreen(),
                    ).then((value) {
                      if (value == true) {
                        _loadUsuarios();
                        if (widget.onUserUpdated != null)
                          widget.onUserUpdated!();
                      }
                    });
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('REGISTRAR NUEVO',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D1D1F),
                    side: BorderSide(
                        color: const Color(0xFF1D1D1F).withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Barra de Filtros Técnica
            KeyFocusWrapper(
              bindings: {LogicalKeyboardKey.f1: _searchFocusNode},
              actions: {LogicalKeyboardKey.escape: () => _searchController.clear()},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1D1D1F).withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: const Color(0xFF1D1D1F).withOpacity(0.3),
                        size: 20),
                    const SizedBox(width: 8),
                    const F1Badge(label: 'F1'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Filtrar por nombre, rol o credenciales...',
                          hintStyle: TextStyle(
                            color: const Color(0xFF1D1D1F).withOpacity(0.3),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Outfit',
                            color: Color(0xFF1D1D1F)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_usuariosFiltrados.length} RESULTADOS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D1D1F).withOpacity(0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Cabecera de Tabla (Información Técnica)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                      flex: 4, child: Center(child: _tableHeader('IDENTIDAD'))),
                  Expanded(
                      flex: 2,
                      child: Center(child: _tableHeader('ROL / NIVEL'))),
                  Expanded(
                      flex: 2, child: Center(child: _tableHeader('ESTADO'))),
                  Expanded(
                      flex: 2, child: Center(child: _tableHeader('ACCIONES'))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Lista de Usuarios con Diseño Minimalista
            Expanded(
              child: _usuariosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_rounded,
                              size: 64,
                              color: const Color(0xFF1D1D1F).withOpacity(0.1)),
                          const SizedBox(height: 16),
                          const Text(
                            'Sin registros coincidentes',
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
                                color:
                                    const Color(0xFF1D1D1F).withOpacity(0.4)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _usuariosFiltrados.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                      itemBuilder: (context, index) {
                        final usuario = _usuariosFiltrados[index];
                        final bool isAdmin = usuario['ROL'] == 'Administrador';

                        return Material(
                          color: Colors.white,
                          borderRadius:
                              (index == 0 && _usuariosFiltrados.length == 1)
                                  ? BorderRadius.circular(12)
                                  : index == 0
                                      ? const BorderRadius.vertical(
                                          top: Radius.circular(12))
                                      : index == _usuariosFiltrados.length - 1
                                          ? const BorderRadius.vertical(
                                              bottom: Radius.circular(12))
                                          : BorderRadius.zero,
                          child: InkWell(
                            onTap:
                                () {}, // Accion opcional para habilitar hover
                            hoverColor:
                                const Color(0xFFFF3B30).withOpacity(0.08),
                            borderRadius:
                                (index == 0 && _usuariosFiltrados.length == 1)
                                    ? BorderRadius.circular(12)
                                    : index == 0
                                        ? const BorderRadius.vertical(
                                            top: Radius.circular(12))
                                        : index == _usuariosFiltrados.length - 1
                                            ? const BorderRadius.vertical(
                                                bottom: Radius.circular(12))
                                            : BorderRadius.zero,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  // Identidad
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1D1D1F)
                                                .withOpacity(0.03),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              (usuario['NOMBRE_VENDEDOR'] ??
                                                      'U')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1D1D1F),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              usuario['NOMBRE_VENDEDOR'] ??
                                                  'Sin Nombre',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: Color(0xFF1D1D1F),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '@${usuario['NOMBRE_USUARIO']}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        const Color(0xFF1D1D1F)
                                                            .withOpacity(0.5),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'ID: PS-${usuario['ID_USUARIO'].toString().padLeft(3, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        const Color(0xFF1D1D1F)
                                                            .withOpacity(0.3),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Rol
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Text(
                                        usuario['ROL'].toString().toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isAdmin
                                              ? const Color(0xFFFF3B30)
                                              : const Color(0xFF1D1D1F),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Estado
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: usuario['ESTADO'] == 'Activo'
                                                ? const Color(0xFF34C759)
                                                : const Color(0xFF1D1D1F)
                                                    .withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          usuario['ESTADO'] ?? 'Inactivo',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  usuario['ESTADO'] == 'Activo'
                                                      ? const Color(0xFF1D1D1F)
                                                      : const Color(0xFF1D1D1F)
                                                          .withOpacity(0.4)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Acciones
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _actionButton(
                                          icon: Icons.edit_outlined,
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  EditUserScreen(user: usuario),
                                            ).then((value) {
                                              if (value == true) {
                                                _loadUsuarios();
                                                if (widget.onUserUpdated !=
                                                    null) {
                                                  widget.onUserUpdated!();
                                                }
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _actionButton(
                                          icon: Icons.delete_outline_rounded,
                                          onTap: () => _confirmDeleteUsuario(
                                              usuario['ID_USUARIO']),
                                          isDestructive: true,
                                        ),
                                      ],
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

  Widget _tableHeader(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D1D1F).withOpacity(0.3),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon,
      required VoidCallback onTap,
      bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor:
            (isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F))
                .withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: isDestructive
                ? const Color(0xFFFF3B30).withOpacity(0.8)
                : const Color(0xFF1D1D1F).withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
