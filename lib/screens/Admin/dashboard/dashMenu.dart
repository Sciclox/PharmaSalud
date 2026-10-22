import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pharma_salud/components/mainLayout.dart';
import 'package:pharma_salud/screens/Admin/analisis/producto_analysis_screen.dart';
import 'package:pharma_salud/screens/Admin/dashboard/components/cerrarSesionDialog.dart';
import 'package:pharma_salud/screens/Admin/registroVentas/registroVentas.dart';
import 'package:pharma_salud/screens/Admin/registroVentas/admin_tickets_screen.dart';
import 'package:pharma_salud/screens/Admin/dashboard/dashGraficos.dart';
import 'package:pharma_salud/screens/Admin/kardex/kardex.dart';
import 'package:pharma_salud/screens/Admin/productos/productosHome.dart';
import 'package:pharma_salud/screens/Admin/usuarios/usuariosHome.dart';
import 'package:pharma_salud/screens/Admin/ajusteInventario/ajusteInventario.dart';
import 'package:pharma_salud/screens/Admin/sobrantes/sobrantesHome.dart';
import 'package:pharma_salud/repositories/usuarios.dart';
import 'package:pharma_salud/repositories/farmacia.dart';
import 'package:pharma_salud/screens/Admin/configuracion/farmaciaScreen.dart';

// Constantes de diseño para asegurar alineación perfecta
const double kMenuItemHeight = 52.0;
const double kPillHeight = 44.0;

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  _DashboardAdminScreenState createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  Widget _currentScreen = const DashboardInicialScreen();
  int _selectedIndex = 0;
  String _adminName = 'Administrador';
  String _farmaciaNombre = 'PHARMA SALUD';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _loadFarmacia();
  }

  Future<void> _loadAdminName() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('adminName');
    int? id = prefs.getInt('adminId');

    // Si el nombre existe pero no el ID (sesión antigua), intentamos recuperarlo
    if (name != null && id == null) {
      try {
        final repo = UsuarioRepository();
        final users = await repo.readUsuarios();
        // Buscamos el usuario administrador que coincida con el nombre actual
        final currentUser = users.firstWhere(
            (u) => u['NOMBRE_VENDEDOR'] == name && u['ROL'] == 'Administrador');
        id = currentUser['ID_USUARIO'];
        await prefs.setInt('adminId', id!);
      } catch (e) {
        debugPrint("No se pudo sincronizar el adminId: $e");
      }
    }

    if (mounted) {
      setState(() {
        _adminName = name ?? 'Administrador';
      });
    }
  }

  Future<void> _loadFarmacia() async {
    try {
      final repo = FarmaciaRepository();
      final activa = await repo.obtenerActiva();
      if (activa != null && mounted) {
        setState(() {
          _farmaciaNombre = activa['NOMBRE'] ?? 'PHARMA SALUD';
        });
      }
    } catch (e) {
      debugPrint('Error loading farmacia: $e');
    }
  }

  void _selectScreen(int index, Widget screen, String title) {
    if (_selectedIndex == index) return;
    _loadFarmacia();
    setState(() {
      _currentScreen = screen;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9ECEF), Color(0xFFCED4DA)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                  child: _TechnicalGrid(
                isDarkMode: false,
              )),
              Row(
                children: [
                  ModernSideBar(
                    selectedIndex: _selectedIndex,
                    onSelectScreen: _selectScreen,
                    adminName: _adminName,
                    onRefreshName: _loadAdminName,
                    farmaciaNombre: _farmaciaNombre,
                    onRefreshFarmacia: _loadFarmacia,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutQuart,
                        switchOutCurve: Curves.easeInQuart,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.02, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: _currentScreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModernSideBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int, Widget, String) onSelectScreen;
  final String adminName;
  final VoidCallback onRefreshName;
  final String farmaciaNombre;
  final VoidCallback onRefreshFarmacia;

  const ModernSideBar({
    super.key,
    required this.selectedIndex,
    required this.onSelectScreen,
    required this.adminName,
    required this.onRefreshName,
    this.farmaciaNombre = 'PHARMA SALUD',
    required this.onRefreshFarmacia,
  });

  @override
  State<ModernSideBar> createState() => _ModernSideBarState();
}

class _ModernSideBarState extends State<ModernSideBar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    const Color sidebarBg = Colors.white;
    const Color textColor = Color(0xFF1D1D1F); // Apple Gray

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutQuart,
      width: _isCollapsed ? 100 : 280,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            _SidebarHeader(isCollapsed: _isCollapsed, textColor: textColor, farmaciaNombre: widget.farmaciaNombre),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                physics: const BouncingScrollPhysics(),
                child: Stack(
                  children: [
                    _MenuSlidingIndicator(
                      selectedIndex: widget.selectedIndex,
                      isCollapsed: _isCollapsed,
                    ),
                    Column(
                      children: [
                        _MenuItem(
                          icon: Icons.grid_view_rounded,
                          label: 'Dashboard',
                          isSelected: widget.selectedIndex == 0,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              0, const DashboardInicialScreen(), 'Dashboard'),
                        ),
                        _MenuItem(
                          icon: Icons.inventory_2_rounded,
                          label: 'Productos',
                          isSelected: widget.selectedIndex == 2,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              2, const ProductoScreen(), 'Productos'),
                        ),
                        _MenuItem(
                          icon: Icons.receipt_rounded,
                          label: 'Ventas',
                          isSelected: widget.selectedIndex == 3,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              3, const AdminRegistroVentasWidget(), 'Ventas'),
                        ),
                        _MenuItem(
                          icon: Icons.analytics_rounded,
                          label: 'Análisis',
                          isSelected: widget.selectedIndex == 5,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              5, const ProductoAnalysisScreen(), 'Análisis'),
                        ),
                        _MenuItem(
                          icon: Icons.group_rounded,
                          label: 'Usuarios',
                          isSelected: widget.selectedIndex == 1,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              1,
                              UsuariosScreen(
                                  onUserUpdated: widget.onRefreshName),
                              'Usuarios'),
                        ),
                        _MenuItem(
                          icon: Icons.confirmation_number_rounded,
                          label: 'Tickets',
                          isSelected: widget.selectedIndex == 6,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              6, const AdminTicketsScreen(), 'Tickets'),
                        ),
                        _MenuItem(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Kardex',
                          isSelected: widget.selectedIndex == 4,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              4, const KardexScreen(), 'Kardex'),
                        ),
                        _MenuItem(
                          icon: Icons.assignment_rounded,
                          label: 'Ajuste Inventario',
                          isSelected: widget.selectedIndex == 7,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              7,
                              const AjusteInventarioScreen(),
                              'Ajuste Inventario'),
                        ),
                        _MenuItem(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Sobrantes',
                          isSelected: widget.selectedIndex == 8,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              8,
                              const SobrantesAdminHome(),
                              'Sobrantes'),
                        ),
                        _MenuItem(
                          icon: Icons.settings_rounded,
                          label: 'Configuración',
                          isSelected: widget.selectedIndex == 9,
                          isCollapsed: _isCollapsed,
                          onTap: () => widget.onSelectScreen(
                              9,
                              FarmaciaConfigScreen(onFarmaciaCambiada: widget.onRefreshFarmacia),
                              'Configuración'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _SidebarFooter(
              isCollapsed: _isCollapsed,
              adminName: widget.adminName,
              onCollapse: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool isCollapsed;
  final Color textColor;
  final String farmaciaNombre;
  const _SidebarHeader({required this.isCollapsed, required this.textColor, this.farmaciaNombre = 'PHARMA SALUD'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Center(
                child: Image.asset('lib/imagenes/logoPharmaSalud.png',
                    height: 32)),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 16),
            Text(
              farmaciaNombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'Outfit'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool isCollapsed;
  final String adminName;
  final VoidCallback onCollapse;

  const _SidebarFooter({
    required this.isCollapsed,
    required this.adminName,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    const Color textColor = Color(0xFF1D1D1F);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!isCollapsed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: textColor.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          textColor.withOpacity(0.08),
                          textColor.withOpacity(0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: TextStyle(
                            color: textColor.withOpacity(0.8),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            fontFamily: 'Outfit'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          adminName,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              fontFamily: 'Outfit'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ADMINISTRADOR',
                            style: TextStyle(
                                color: textColor.withOpacity(0.4),
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => mostrarCerrarSesionDialog(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('CERRAR SESIÓN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit',
                          letterSpacing: 1.1)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    side: BorderSide(
                        color: const Color(0xFFFF3B30).withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ] else
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton(
                onPressed: () => mostrarCerrarSesionDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: BorderSide(
                      color: const Color(0xFFFF3B30).withOpacity(0.3)),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.logout_rounded, size: 20),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                  onPressed: onCollapse,
                  icon: Icon(
                      isCollapsed
                          ? Icons.chevron_right_rounded
                          : Icons.chevron_left_rounded,
                      size: 20,
                      color: textColor.withOpacity(0.4))),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSlidingIndicator extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;

  const _MenuSlidingIndicator(
      {required this.selectedIndex, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    int position = 0;
    switch (selectedIndex) {
      case 0:
        position = 0;
        break; // Dashboard
      case 2:
        position = 1;
        break; // Productos
      case 3:
        position = 2;
        break; // Ventas
      case 5:
        position = 3;
        break; // Análisis
      case 1:
        position = 4;
        break; // Usuarios
      case 6:
        position = 5;
        break; // Tickets
      case 4:
        position = 6;
        break; // Kardex
      case 7:
        position = 7;
        break; // Ajuste Inventario
      case 8:
        position = 8;
        break; // Sobrantes
      case 9:
        position = 9;
        break; // Configuración
    }

    final double topOffset = position * kMenuItemHeight;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      left: 0,
      right: 0,
      top: topOffset + ((kMenuItemHeight - kPillHeight) / 2),
      child: Container(
        height: kPillHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF8B0000),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFF8B0000).withOpacity(0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.isCollapsed,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    const Color textColor = Colors.black;
    final Color activeColor = Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: kMenuItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon,
                  color: isSelected ? activeColor : textColor.withOpacity(0.7),
                  size: 22),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                        color:
                            isSelected ? activeColor : textColor.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TechnicalGrid extends StatelessWidget {
  final bool isDarkMode;
  const _TechnicalGrid({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(isDarkMode: isDarkMode),
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDarkMode;
  _GridPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.02)
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
