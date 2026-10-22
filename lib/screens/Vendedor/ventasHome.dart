import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_salud/components/mainLayout.dart';
import 'package:pharma_salud/widgets/key_focus_wrapper.dart';
import 'package:pharma_salud/repositories/productos.dart';
import 'package:pharma_salud/repositories/registroVentas.dart';
import 'package:pharma_salud/repositories/carritoVentas.dart';
import 'package:pharma_salud/screens/Login/login.dart';
import 'package:pharma_salud/screens/Vendedor/components/vendedor_tickets_modal.dart';
import 'package:pharma_salud/screens/Vendedor/components/panelCarritoVentas.dart';
import 'package:pharma_salud/screens/Vendedor/components/vendedorRegistroVentas.dart';
import 'package:pharma_salud/screens/Vendedor/components/productoSeleccionado.dart';
import 'package:pharma_salud/screens/Vendedor/components/sobranteCajaDialog.dart';
import 'package:pharma_salud/screens/Vendedor/components/modoOcultoDialog.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_receta_medica.dart';
import 'package:pharma_salud/screens/Vendedor/components/modal_carrito_completo.dart';
import 'package:pharma_salud/screens/Vendedor/components/inventario_pos_modal.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class VendedorScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String gender;

  const VendedorScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.gender,
  });

  @override
  _VendedorScreenState createState() => _VendedorScreenState();
}

class _VendedorScreenState extends State<VendedorScreen> {
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  final ProductoRepository _productoRepository = ProductoRepository();
  final CartItemRepository _cartItemRepository = CartItemRepository();
  Map<int, int> _unidadesEnCarrito = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool mostrarPanelCarrito = false;
  bool mostrarRegistroDia = false;
  bool mostrarTicketsModal = false;
  bool recargarCarrito = false;
  bool _modoOcultoActivo = false;
  String _panelDerechoTab = 'carrito'; // 'carrito' o 'resumen'
  int _totalItemsEnCarrito = 0;
  late String _userName;
  late String _gender;

  int _selectedIndex = -1;
  bool _dialogOpen = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _gender = widget.gender;
    _fetchProductos();
    _verificarVentasHoy();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSearchField();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_dialogOpen) return false;

      // Combinación secreta: Ctrl + Shift + H, Ctrl + Shift + O, o tecla F8
      final isControlPressed = HardwareKeyboard.instance.isControlPressed;
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      final isShortcut = (isControlPressed &&
              isShiftPressed &&
              (event.logicalKey == LogicalKeyboardKey.keyH ||
                  event.logicalKey == LogicalKeyboardKey.keyO)) ||
          (event.logicalKey == LogicalKeyboardKey.f8);

      if (isShortcut) {
        _toggleModoOculto();
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.f4) {
        if (_totalItemsEnCarrito > 0) {
          _abrirCanastaCompleta();
          return true;
        } else {
          setState(() {
            mostrarPanelCarrito = !mostrarPanelCarrito;
            if (mostrarPanelCarrito) _panelDerechoTab = 'carrito';
          });
          return true;
        }
      }

      if (!_searchFocusNode.hasFocus) return false;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_productosFiltrados.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1).clamp(0, _productosFiltrados.length - 1);
          });
          _scrollToSelected();
          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_productosFiltrados.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1).clamp(0, _productosFiltrados.length - 1);
          });
          _scrollToSelected();
          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_selectedIndex >= 0 && _selectedIndex < _productosFiltrados.length) {
          final producto = _productosFiltrados[_selectedIndex];
          _showCartDialog(producto);
          return true;
        }
      }
    }
    return false;
  }

  void _abrirCanastaCompleta() {
    setState(() => _dialogOpen = true);
    CarritoCompletoModal.show(
      context,
      userId: widget.userId,
      userName: _userName,
      gender: _gender,
      onRecargarTodo: () {
        _mostrarYRecargarCarrito();
      },
    ).then((_) {
      if (mounted) {
        setState(() => _dialogOpen = false);
        _fetchProductos();
        _focusSearchField();
      }
    });
  }

  Future<void> _toggleModoOculto() async {
    if (_modoOcultoActivo) {
      // Bloquear inmediatamente para máxima discreción
      setState(() {
        _modoOcultoActivo = false;
      });
      await _fetchProductos();
      if (_searchController.text.isNotEmpty) {
        await _filterProductos(_searchController.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Modo discreto bloqueado. Productos ocultos protegidos.',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1D1D1F),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      // Solicitar clave en el modal
      setState(() => _dialogOpen = true);
      final unlocked = await ModoOcultoDialog.show(context);
      if (mounted) {
        setState(() => _dialogOpen = false);
      }

      if (unlocked == true && mounted) {
        setState(() {
          _modoOcultoActivo = true;
        });
        await _fetchProductos();
        if (_searchController.text.isNotEmpty) {
          await _filterProductos(_searchController.text);
        } else {
          // Si el buscador está vacío, mostramos directamente los productos ocultos
          final ocultos = await _productoRepository.getSoloProductosOcultos();
          if (mounted && _searchController.text.isEmpty && ocultos.isNotEmpty) {
            setState(() {
              _productosFiltrados = ocultos;
              _selectedIndex = -1;
            });
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Modo discreto activado. Productos ocultos visibles.',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF34C759),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
      _focusSearchField();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients || _selectedIndex == -1) return;

    const double itemHeight = 65.0; // Altura aproximada de fila
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double currentScroll = _scrollController.offset;

    final double itemTop = _selectedIndex * itemHeight;
    final double itemBottom = itemTop + itemHeight;

    if (itemTop < currentScroll) {
      _scrollController.animateTo(
        itemTop,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (itemBottom > currentScroll + viewportHeight) {
      _scrollController.animateTo(
        itemBottom - viewportHeight,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showCartDialog(Map<String, dynamic> producto) async {
    setState(() => _dialogOpen = true);

    // Advertencia de medicamento controlado / con receta médica
    if ((producto['RECETA_MEDICA'] ?? 0) == 1) {
      final bool confirmado = await RecetaMedicaModal.show(context, producto);
      if (!confirmado) {
        if (mounted) {
          setState(() => _dialogOpen = false);
          _focusSearchField();
        }
        return;
      }
    }
    if (!mounted) return;

    await CartDialogSeleccionado.showCart(
      context,
      producto,
      widget.userId,
      _mostrarYRecargarCarrito,
    );
    if (mounted) {
      setState(() => _dialogOpen = false);
    }
  }

  void _focusSearchField() {
    FocusScope.of(context).requestFocus(
        _searchFocusNode); // Solicitar el foco en el campo de búsqueda
  }

  Future<void> _verificarVentasHoy() async {
    final hoy = DateTime.now();
    final fechaHoy =
        "${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}";
    final ventas = await RegistroVentasRepository()
        .obtenerDetallesVentasPorUsuarioConFecha(widget.userId, fechaHoy);
    if (mounted && ventas.isNotEmpty) {
      setState(() {
        mostrarRegistroDia = true;
        _panelDerechoTab = 'resumen';
      });
    }
  }

  Future<void> _fetchProductos() async {
    final prodsFuture = _productoRepository.getAllProductos(incluirOcultos: _modoOcultoActivo);
    final cartFuture = _cartItemRepository.getCantidadesEnCarritoPorUsuario(widget.userId);
    final countFuture = _cartItemRepository.getCartItemCount(widget.userId);
    final results = await Future.wait([prodsFuture, cartFuture, countFuture]);

    _productos = results[0] as List<Map<String, dynamic>>;
    _unidadesEnCarrito = results[1] as Map<int, int>;
    _totalItemsEnCarrito = results[2] as int;

    final query = _searchController.text.trim();
    setState(() {
      _selectedIndex = -1;
      if (query.isNotEmpty) {
        _productosFiltrados = _productos.where((producto) {
          final nombre = producto['Nombre_Producto'].toString().toLowerCase();
          final barra = (producto['Codigo_Barra'] ?? '').toString().toLowerCase();
          return nombre.contains(query.toLowerCase()) || barra.contains(query.toLowerCase());
        }).toList();
      } else {
        if (_modoOcultoActivo) {
          _productosFiltrados = _productos.where((p) => (p['ES_OCULTO'] ?? 0) == 1).toList();
        } else {
          _productosFiltrados = [];
        }
      }
    });
  }

  Future<void> _filterProductos(String query) async {
    _unidadesEnCarrito = await _cartItemRepository.getCantidadesEnCarritoPorUsuario(widget.userId);
    _totalItemsEnCarrito = await _cartItemRepository.getCartItemCount(widget.userId);
    if (query.isEmpty) {
      setState(() {
        if (_modoOcultoActivo) {
          _productosFiltrados = _productos.where((p) => (p['ES_OCULTO'] ?? 0) == 1).toList();
        } else {
          _productosFiltrados = [];
        }
        _selectedIndex = -1;
      });
      return;
    }
    final resultados = await _productoRepository.searchProductos(query, incluirOcultos: _modoOcultoActivo);
    if (mounted) {
      setState(() {
        _productosFiltrados = resultados;
        _selectedIndex = -1;
      });
    }
  }

  void _logout() {
    // y redirigir a la pantalla de inicio de sesión.
    // Cerrar el diálogo
    Navigator.pushReplacement(
      // ignore: use_build_context_synchronously
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionDuration: Duration.zero, // Sin animación
        reverseTransitionDuration: Duration.zero, // Sin animación al volver
      ),
    );
  }

  void _mostrarYRecargarCarrito() {
    setState(() {
      mostrarPanelCarrito = true;
      _panelDerechoTab = 'carrito';
      recargarCarrito = !recargarCarrito; // Fuerza recarga
    });
    _fetchProductos(); // ✅ Agrega esto para recargar productos
    _focusSearchField();
  }

  @override
  Widget build(BuildContext context) {
    double paddingValue = 24;
    return MainLayout(
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Stack(
          children: [
            // Fondo con rejilla técnica para coherencia de marca
            const Positioned.fill(child: _TechnicalGrid()),

            Padding(
              padding: EdgeInsets.all(paddingValue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Minimalista Pharma (Igual que en Admin)
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
                              Text(
                                '${_gender == 'Femenino' ? 'Bienvenida,' : 'Bienvenido,'} $_userName',
                                style: const TextStyle(
                                  color: Color(0xFF1D1D1F),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
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
                              'Terminal de punto de venta y dispensación',
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
                      Row(
                        children: [
                          _headerActionButton(
                            icon: mostrarTicketsModal
                                ? Icons.history_rounded
                                : Icons.history_outlined,
                            label: 'TICKETS',
                            isActive: mostrarTicketsModal,
                            onTap: () async {
                              setState(() {
                                mostrarTicketsModal = true;
                                _dialogOpen = true;
                              });
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false,
                                  barrierDismissible: true,
                                  transitionDuration:
                                      const Duration(milliseconds: 350),
                                  reverseTransitionDuration:
                                      const Duration(milliseconds: 250),
                                  barrierColor: Colors.black.withOpacity(0.3),
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) {
                                    return VendedorTicketsModal(
                                      userId: widget.userId,
                                      userName: _userName,
                                    );
                                  },
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    const begin = Offset(-1.0, 0.0);
                                    const end = Offset.zero;
                                    const curve = Curves.easeOutCubic;

                                    var tween = Tween(begin: begin, end: end)
                                        .chain(CurveTween(curve: curve));

                                    return SlideTransition(
                                      position: animation.drive(tween),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                              setState(() {
                                mostrarTicketsModal = false;
                                _dialogOpen = false;
                              });
                              _fetchProductos();
                              _focusSearchField();
                            },
                          ),
                          const SizedBox(width: 12),
                          _headerActionButton(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'SOBRANTE',
                            onTap: () async {
                              setState(() => _dialogOpen = true);
                              await showDialog(
                                context: context,
                                builder: (ctx) => SobranteCajaDialog(
                                  userId: widget.userId,
                                  userName: _userName,
                                ),
                              );
                              if (mounted) {
                                setState(() => _dialogOpen = false);
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          _headerActionButton(
                            icon: Icons.fact_check_outlined,
                            label: 'INVENTARIO',
                            onTap: () async {
                              setState(() => _dialogOpen = true);
                              await InventarioPosModal.show(
                                context,
                                userId: widget.userId,
                                userName: _userName,
                              );
                              if (mounted) {
                                setState(() => _dialogOpen = false);
                                await _fetchProductos();
                                _focusSearchField();
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          _headerActionButton(
                            icon: (mostrarRegistroDia && _panelDerechoTab == 'resumen')
                                ? Icons.assignment_rounded
                                : Icons.assignment_outlined,
                            label: 'RESUMEN',
                            onTap: () {
                              setState(() {
                                if (mostrarRegistroDia && _panelDerechoTab == 'resumen') {
                                  mostrarRegistroDia = false;
                                  if (mostrarPanelCarrito) _panelDerechoTab = 'carrito';
                                } else {
                                  mostrarRegistroDia = true;
                                  _panelDerechoTab = 'resumen';
                                }
                              });
                            },
                            isActive: mostrarRegistroDia && _panelDerechoTab == 'resumen',
                          ),
                          const SizedBox(width: 12),
                          if (_modoOcultoActivo) ...[
                            _headerActionButton(
                              icon: Icons.lock_open_rounded,
                              label: 'BLOQUEAR DISCRETO',
                              isActive: true,
                              onTap: _toggleModoOculto,
                            ),
                            const SizedBox(width: 12),
                          ],
                          _headerActionButton(
                            icon: (mostrarPanelCarrito && _panelDerechoTab == 'carrito')
                                ? Icons.shopping_cart_rounded
                                : Icons.shopping_cart_outlined,
                            label: _totalItemsEnCarrito > 0
                                ? 'CARRITO ($_totalItemsEnCarrito)'
                                : 'CARRITO',
                            onTap: () {
                              setState(() {
                                if (mostrarPanelCarrito && _panelDerechoTab == 'carrito') {
                                  mostrarPanelCarrito = false;
                                  if (mostrarRegistroDia) _panelDerechoTab = 'resumen';
                                } else {
                                  mostrarPanelCarrito = true;
                                  _panelDerechoTab = 'carrito';
                                }
                              });
                            },
                            isActive: mostrarPanelCarrito && _panelDerechoTab == 'carrito',
                          ),
                          const SizedBox(width: 12),
                          _headerActionButton(
                            icon: Icons.logout_rounded,
                            label: 'SALIR',
                            onTap: _logout,
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna 1: Búsqueda y Tabla (Principal)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(),
                              const SizedBox(height: 24),
                              _buildProductTable(),
                            ],
                          ),
                        ),

                        // Columna 2: Panel Lateral Unificado (Carrito y/o Resumen del Día)
                        if (mostrarPanelCarrito || mostrarRegistroDia) ...[
                          const SizedBox(width: 24),
                          SizedBox(
                            key: const ValueKey('panel_derecho_unificado'),
                            width: 440,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFF1D1D1F)
                                        .withOpacity(0.05)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Switcher de pestañas si ambos paneles están activos
                                  if (mostrarPanelCarrito && mostrarRegistroDia) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _panelTabButton(
                                              title: 'CARRITO ($_totalItemsEnCarrito)',
                                              icon: Icons.shopping_cart_rounded,
                                              isSelected: _panelDerechoTab == 'carrito',
                                              onTap: () => setState(() => _panelDerechoTab = 'carrito'),
                                            ),
                                          ),
                                          Expanded(
                                            child: _panelTabButton(
                                              title: 'RESUMEN DÍA',
                                              icon: Icons.assignment_rounded,
                                              isSelected: _panelDerechoTab == 'resumen',
                                              onTap: () => setState(() => _panelDerechoTab = 'resumen'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Contenido activo
                                  Expanded(
                                    child: (_panelDerechoTab == 'carrito' && mostrarPanelCarrito) || !mostrarRegistroDia
                                        ? PanelCarritoVentas(
                                            userId: widget.userId,
                                            userName: _userName,
                                            gender: _gender,
                                            recargar: recargarCarrito,
                                            onRecargar: () {
                                              _mostrarYRecargarCarrito();
                                            },
                                          )
                                        : DetallesVentaWidget(
                                            userId: widget.userId,
                                            userName: _userName,
                                            onDevolucionSuccess: () {
                                              _fetchProductos();
                                              _focusSearchField();
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF1D1D1F).withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF1D1D1F)
                    : const Color(0xFF1D1D1F).withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isActive ? Colors.white : color,
        backgroundColor: isActive ? color : Colors.transparent,
        side: BorderSide(color: color.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        enabledMouseCursor: SystemMouseCursors.click,
      ),
    );
  }

  Widget _buildSearchBar() {
    return KeyFocusWrapper(
      bindings: {LogicalKeyboardKey.f1: _searchFocusNode},
      actions: {LogicalKeyboardKey.escape: () => _searchController.clear()},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: const Color(0xFF1D1D1F).withOpacity(0.3), size: 20),
            const SizedBox(width: 8),
            const F1Badge(label: 'F1'),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _filterProductos,
                decoration: InputDecoration(
                  hintText: 'Buscar productos por nombre o categoría...',
                  hintStyle: TextStyle(
                    color: const Color(0xFF1D1D1F).withOpacity(0.3),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                    fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1D1D1F)),
              ),
            ),
            if (_modoOcultoActivo) ...[
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF5856D6).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 12, color: Color(0xFF5856D6)),
                    SizedBox(width: 4),
                    Text(
                      'MODO DISCRETO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5856D6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_productosFiltrados.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_productosFiltrados.length} RESULTADOS',
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
    );
  }

  Widget _buildProductTable() {
    if (_searchController.text.isEmpty && !_modoOcultoActivo) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded,
                  size: 48, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
              const SizedBox(height: 16),
              Text(
                "Ingrese un nombre para buscar productos",
                style: TextStyle(
                  color: const Color(0xFF1D1D1F).withOpacity(0.3),
                  fontSize: 15,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_productosFiltrados.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: const Color(0xFF1D1D1F).withOpacity(0.1)),
              const SizedBox(height: 16),
              Text(
                _modoOcultoActivo && _searchController.text.isEmpty
                    ? "No hay productos ocultos registrados."
                    : "No se encontraron coincidencias.",
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1D1D1F),
                    fontFamily: 'Outfit'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          // Cabecera de Tabla (Igual que en Admin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: _tableHeader('PRODUCTO')),
                Expanded(flex: 1, child: _tableHeader('TIPO')),
                Expanded(flex: 1, child: _tableHeader('STOCK CAJA')),
                Expanded(flex: 1, child: _tableHeader('STOCK UNID.')),
                Expanded(flex: 1, child: _tableHeader('P. CAJA')),
                Expanded(flex: 1, child: _tableHeader('P. BLISTER')),
                Expanded(flex: 1, child: _tableHeader('P. UNID.')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _productosFiltrados.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final producto = _productosFiltrados[index];
                return _buildProductRow(producto, index);
              },
            ),
          ),
        ],
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
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> producto, int index) {
    final int prodId = (producto['ID'] as num?)?.toInt() ?? 0;
    final nombreProducto = producto['Nombre_Producto'] ?? 'N/A';
    final tipoProducto = producto['Tipo_Producto'] ?? '--';
    final int stockFisico = (producto['Cantidad_Total'] as num?)?.toInt() ?? 0;
    final int enCarrito = _unidadesEnCarrito[prodId] ?? 0;
    // Stock disponible para el vendedor en tiempo real (restando lo que ya tiene en el carrito)
    final int cantidadTotal = (stockFisico - enCarrito).clamp(0, stockFisico);
    final int qtyPres = (producto['Cantidad_Presentacion'] as num?)?.toInt() ?? 1;
    final preciocaja = (producto['Precio_Caja'] ?? 0.0).toDouble();
    final precioblister = (producto['Precio_Blister'] ?? 0.0).toDouble();
    final preciounidad = (producto['Precio_Unidad'] ?? 0.0).toDouble();

    final int stockMinimo = producto['Stock_Minimo'] ?? 0;
    final bool esBajoStock = cantidadTotal == 0 || cantidadTotal <= stockMinimo;

    final String stockCajaText;
    final int stockCajaVal;
    final int stockUnidadVal;

    if (tipoProducto == 'Caja') {
      final int presSafe = qtyPres > 0 ? qtyPres : 1;
      stockCajaVal = (cantidadTotal / presSafe).floor();
      stockUnidadVal = cantidadTotal % presSafe;
      stockCajaText = stockCajaVal.toString();
    } else {
      stockCajaVal = 0;
      stockUnidadVal = cantidadTotal;
      stockCajaText = '--';
    }

    return Material(
      color: index == _selectedIndex
          ? const Color(0xFFFF3B30).withOpacity(0.08)
          : Colors.white,
      borderRadius: (index == 0 && _productosFiltrados.length == 1)
          ? BorderRadius.circular(12)
          : index == 0
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : index == _productosFiltrados.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          _showCartDialog(producto);
        },
        hoverColor: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: (index == 0 && _productosFiltrados.length == 1)
            ? BorderRadius.circular(12)
            : index == 0
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : index == _productosFiltrados.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(12))
                    : BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nombreProducto,
                            softWrap: true,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1D1D1F),
                                fontFamily: 'Outfit'),
                          ),
                        ),
                        if ((producto['ES_OCULTO'] ?? 0) == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5856D6).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DISCRETO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5856D6),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if ((producto['RECETA_MEDICA'] ?? 0) == 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFF9500).withOpacity(0.35),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_late_outlined,
                                    size: 10, color: Color(0xFFD97706)),
                                SizedBox(width: 3),
                                Text(
                                  'RECETA MÉDICA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'REF: PS-${producto['ID'].toString().padLeft(4, '0')}',
                      style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF1D1D1F).withOpacity(0.3),
                          fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    tipoProducto.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F).withOpacity(0.5)),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    stockCajaText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: esBajoStock
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF1D1D1F),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    stockUnidadVal.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: esBajoStock
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF1D1D1F),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    tipoProducto == 'Caja'
                        ? 'S/ ${formatMoney(preciocaja)}'
                        : '--',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F)),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    precioblister > 0.0
                        ? 'S/ ${formatMoney(precioblister)}'
                        : '--',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F)),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    'S/ ${formatMoney(preciounidad)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Rejilla técnica (Copiada de Admin Dash para consistencia)
class _TechnicalGrid extends StatelessWidget {
  const _TechnicalGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
