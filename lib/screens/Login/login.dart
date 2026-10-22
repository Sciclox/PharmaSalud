import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pharma_salud/components/mainLayout.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/repositories/farmacia.dart';
import 'package:pharma_salud/utils/snackbar_manager.dart';
import 'package:pharma_salud/screens/Admin/dashboard/dashMenu.dart';
import 'package:pharma_salud/screens/Vendedor/ventasHome.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _farmaciaNombre = 'Pharma Salud';

  // Professional Pharmacy Palette
  static const Color backgroundLight = Color(0xFFE9ECEF);
  static const Color backgroundDark = Color(0xFFCED4DA);
  static const Color primaryText = Color(0xFF212529);
  static const Color secondaryText = Color(0xFF6C757D);
  static const Color pharmaRed = Color(0xFFFF3B30);

  @override
  void initState() {
    super.initState();
    _loadFarmacia();
  }

  Future<void> _loadFarmacia() async {
    try {
      final repo = FarmaciaRepository();
      final activa = await repo.obtenerActiva();
      if (activa != null && mounted) {
        setState(() {
          _farmaciaNombre = activa['NOMBRE'] ?? 'Pharma Salud';
        });
      }
    } catch (e) {
      debugPrint('Error loading farmacia: $e');
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5)),
                  ),
                  child: const CircularProgressIndicator(color: pharmaRed),
                ),
              ),
            ),
          );
        },
      );

      final userRepository = UsuarioRepository();
      final isAuthenticated = await userRepository.authenticateUser(
        _usernameController.text,
        _passwordController.text,
      );

      Navigator.of(context).pop();

      if (isAuthenticated) {
        final status =
            await userRepository.getUserStatus(_usernameController.text);

        if (status != 'Activo') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'El usuario se encuentra inactivo. Contacte al administrador.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }

        final userRole =
            await userRepository.getUserRole(_usernameController.text);
        final userId = await userRepository.getUserId(_usernameController.text);

        if (userRole == 'Administrador') {
          // Obtener el nombre para guardarlo en preferencias
          final userName = await userRepository.getUserNameById(userId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('adminName', userName);
          await prefs.setInt('adminId', userId);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const DashboardAdminScreen()),
          );
        } else {
          // Obtener nombre y género ANTES de navegar para evitar flicker
          final userName = await userRepository.getUserNameById(userId);
          final gender = await userRepository.getUserGenderById(userId);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => VendedorScreen(
                      userId: userId,
                      userName: userName,
                      gender: gender,
                    )),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Credenciales incorrectas'),
            backgroundColor: pharmaRed,
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundLight, backgroundDark],
          ),
        ),
        child: Stack(
          children: [
            // Subtle Grid Pattern for professional "Technical" feel
            const Positioned.fill(
                child: _TechnicalGrid()),

            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Hero(
                      tag: 'login_card',
                      child: Container(
                        width: 440,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 100,
                              spreadRadius: -10,
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 60, horizontal: 45),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'lib/imagenes/logoPharmaSalud.png',
                                    height: 85,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    _farmaciaNombre,
                                    style: const TextStyle(
                                      color: primaryText,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Portal de Gestión Farmacéutica',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  _InteractiveInputs(
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    onLogin: _login,
                                  ),
                                  const SizedBox(height: 40),
                                  _PrimaryActionButton(onPressed: _login),
                                  const SizedBox(height: 40),
                                  const Divider(
                                      height: 1,
                                      color: Color(0xFFF1F3F5)),
                                  const SizedBox(height: 24),
                                  Text(
                                    '© 2024 Pharma Salud Industrial. Reservado.',
                                    style: TextStyle(
                                      color: secondaryText.withOpacity(0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Reportar un problema de acceso',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _TechnicalGrid extends StatelessWidget {
  const _TechnicalGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.02)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _InteractiveInputs extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;

  const _InteractiveInputs({
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
  });

  @override
  State<_InteractiveInputs> createState() => _InteractiveInputsState();
}

class _InteractiveInputsState extends State<_InteractiveInputs> {
  bool _obscureText = true;
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: widget.usernameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            cursorColor: const Color(0xFFFF3B30),
            style: const TextStyle(
                color: Color(0xFF212529),
                fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Usuario',
              hintStyle: TextStyle(color: Color(0xFFADB5BD)),
              prefixIcon: Icon(Icons.person_outline,
                  color: Color(0xFF6C757D),
                  size: 20),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
          ),
          const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE9ECEF),
              indent: 45),
          TextFormField(
            controller: widget.passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscureText,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => widget.onLogin(),
            cursorColor: const Color(0xFFFF3B30),
            style: const TextStyle(
                color: Color(0xFF212529),
                fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: Color(0xFF6C757D),
                  size: 20),
              suffixIcon: IconButton(
                focusNode: FocusNode(canRequestFocus: false),
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFFADB5BD),
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _PrimaryActionButton({required this.onPressed});

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isHovered ? const Color(0xFFE63229) : const Color(0xFFFF3B30),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFFFF3B30).withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'AUTENTICAR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
