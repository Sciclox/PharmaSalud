import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserScreen({super.key, required this.user});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  late TextEditingController _nombreUsuarioController;
  late TextEditingController _nombreVendedorController;
  late TextEditingController _claveController;
  final FocusNode _nombreVendedorFocusNode = FocusNode();
  late String _selectedRol;
  late String _selectedGenero;
  late String _selectedEstado;
  bool _isPasswordVisible = false;

  final List<String> _roles = ['Administrador', 'Vendedor'];
  final List<String> _generos = ['Masculino', 'Femenino'];
  final List<String> _estados = ['Activo', 'Inactivo'];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nombreUsuarioController =
        TextEditingController(text: widget.user['NOMBRE_USUARIO']);
    _nombreVendedorController =
        TextEditingController(text: widget.user['NOMBRE_VENDEDOR'] ?? '');
    _claveController = TextEditingController(text: widget.user['CLAVE']);
    _selectedRol =
        _roles.contains(widget.user['ROL']) ? widget.user['ROL'] : 'Vendedor';
    _selectedGenero = _generos.contains(widget.user['GENERO'])
        ? widget.user['GENERO']
        : 'Masculino';
    _selectedEstado = _estados.contains(widget.user['ESTADO'])
        ? widget.user['ESTADO']
        : 'Activo';
  }

  Future<void> _updateUsuario() async {
    if (_formKey.currentState!.validate()) {
      try {
        final idUsuario = widget.user['ID_USUARIO'];
        final nuevoNombre = _nombreVendedorController.text;

        await _usuarioRepository.updateUsuario({
          'ID_USUARIO': idUsuario,
          'NOMBRE_USUARIO': _nombreUsuarioController.text,
          'NOMBRE_VENDEDOR': nuevoNombre,
          'CLAVE': _claveController.text,
          'ROL': _selectedRol,
          'GENERO': _selectedGenero,
          'ESTADO': _selectedEstado,
        });

        // Si el usuario que se está editando es el administrador actual, actualizar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final adminId = prefs.getInt('adminId');
        if (adminId == idUsuario) {
          await prefs.setString('adminName', nuevoNombre);
        }

        _showStatusSnackBar('Usuario actualizado correctamente.',
            isError: false);
        Navigator.pop(context, true);
      } catch (e) {
        _showStatusSnackBar('Error detallado: $e', isError: true);
      }
    }
  }

  void _showStatusSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Editar Perfil',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1D1D1F),
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF1D1D1F)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Modifica las credenciales o el estado del colaborador seleccionado.',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1D1D1F).withOpacity(0.5),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _buildFieldLabel('NOMBRE COMPLETO'),
                    const SizedBox(width: 8),
                    const F1Badge(label: 'F1'),
                  ],
                ),
                KeyFocusWrapper(
                  bindings: {LogicalKeyboardKey.f1: _nombreVendedorFocusNode},
                  actions: {LogicalKeyboardKey.escape: () => _nombreVendedorController.clear()},
                  child: TextFormField(
                    controller: _nombreVendedorController,
                    focusNode: _nombreVendedorFocusNode,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      if (value.isEmpty) return;
                      final List<String> words = value.split(' ');
                      final List<String> capitalizedWords = words.map((word) {
                        if (word.isEmpty) return '';
                        return word[0].toUpperCase() + word.substring(1);
                      }).toList();
                      final String result = capitalizedWords.join(' ');
                      if (result != value) {
                        final selection = _nombreVendedorController.selection;
                        _nombreVendedorController.value =
                            _nombreVendedorController.value.copyWith(
                          text: result,
                          selection: selection,
                        );
                      }
                    },
                    decoration: _inputDecoration(
                        'Ej: Juan García Pérez', Icons.badge_outlined),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Campo requerido'
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('NOMBRE DE ACCESO'),
                          TextFormField(
                            controller: _nombreUsuarioController,
                            decoration: _inputDecoration(
                                'Ej: jgarcia', Icons.person_outline_rounded),
                            style: const TextStyle(
                                fontFamily: 'Outfit', fontSize: 14),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Campo requerido'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('ESTADO'),
                          SizedBox(
                            height: 44,
                            child: CustomDropdown<String>(
                              hintText: 'Seleccionar...',
                              items: _estados,
                              initialItem: _selectedEstado,
                              onChanged: (v) =>
                                  setState(() => _selectedEstado = v!),
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
                  ],
                ),
                const SizedBox(height: 24),
                _buildFieldLabel('CONTRASEÑA DE SEGURIDAD'),
                TextFormField(
                  controller: _claveController,
                  obscureText: !_isPasswordVisible,
                  decoration:
                      _inputDecoration('••••••••', Icons.lock_outline_rounded)
                          .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 20),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                  validator: (value) => (value != null && value.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('ROL / PERMISO'),
                          SizedBox(
                            height: 44,
                            child: CustomDropdown<String>(
                              hintText: 'Seleccionar...',
                              items: _roles,
                              initialItem: _selectedRol,
                              onChanged: (v) => setState(() => _selectedRol = v!),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('GÉNERO'),
                          SizedBox(
                            height: 44,
                            child: CustomDropdown<String>(
                              hintText: 'Seleccionar...',
                              items: _generos,
                              initialItem: _selectedGenero,
                              onChanged: (v) =>
                                  setState(() => _selectedGenero = v!),
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
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updateUsuario,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D1D1F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ACTUALIZAR INFORMACIÓN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1D1D1F).withOpacity(0.4),
          letterSpacing: 1.2,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon,
              size: 20, color: const Color(0xFF1D1D1F).withOpacity(0.4))
          : null,
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _nombreVendedorController.dispose();
    _claveController.dispose();
    super.dispose();
  }
}
