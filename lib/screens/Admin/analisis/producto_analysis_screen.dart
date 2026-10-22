import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pharma_salud/services/ProductoService.dart';
import 'package:pharma_salud/screens/Admin/analisis/ProductoDetalleModal.dart';
import 'package:pharma_salud/services/AnalysisReportService.dart';

class ProductoAnalysisScreen extends StatefulWidget {
  const ProductoAnalysisScreen({super.key});

  @override
  State<ProductoAnalysisScreen> createState() => _ProductoAnalysisScreenState();
}

class _ProductoAnalysisScreenState extends State<ProductoAnalysisScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _productos = [];
  bool _isLoading = true;
  Timer? _debounce;

  late TabController _tabController;

  // Subfiltro para la pestaña de compras
  String _filtroSubCompras = 'TODOS'; // 'TODOS', 'URGENTES', 'PREVENTIVAS'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _cargarProductos();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _cargarProductos();
    });
  }

  Future<void> _cargarProductos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final query = _searchController.text.trim().toLowerCase();
      final resultados = await ProductoService().analizarProductos(
        filtroNombre: query.isEmpty ? null : query,
      );

      if (mounted) {
        setState(() {
          _productos = resultados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProductDetails(Map<String, dynamic> p) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: ProductoDetalleModal(producto: p),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutQuart)),
          child: child,
        );
      },
    );
  }

  String _formatMoney(double val) {
    return val.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cálculos para KPIs ejecutivos
    final productosAPedir = _productos.where((p) => (p['compraMensualSugerida'] as int? ?? 0) > 0).toList();
    final double totalInversion = productosAPedir.fold<double>(
      0.0,
      (sum, p) => sum + ((p['inversionSugerida'] as num?)?.toDouble() ?? 0.0),
    );

    final quiebres = _productos.where((p) =>
      (p['recomendacion'] == 'SIN STOCK' || (p['stockUtil'] as int? ?? 0) <= 0) &&
      (p['totalVendidas'] as int? ?? 0) > 0
    ).toList();

    final sinMovimientoConStock = _productos.where((p) =>
      (p['totalVendidas'] as int? ?? 0) == 0 && (p['stockUtil'] as int? ?? 0) > 0
    ).toList();
    final double capitalInmovilizadoTotal = sinMovimientoConStock.fold<double>(
      0.0,
      (sum, p) => sum + ((p['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0),
    );

    final productosConVenta = _productos.where((p) => (p['totalVendidas'] as int? ?? 0) > 0).toList();
    final double margenPromedio = productosConVenta.isEmpty
        ? 0.0
        : productosConVenta.fold<double>(
            0.0, (s, p) => s + double.parse(p['margenPorcentaje'] ?? '0')) /
          productosConVenta.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            // Banner de KPIs Ejecutivos
            _buildExecutiveBanner(
              inversionTotal: totalInversion,
              productosAPedirCount: productosAPedir.length,
              quiebresCount: quiebres.length,
              capitalInmovilizado: capitalInmovilizadoTotal,
              productosInmovilizadosCount: sinMovimientoConStock.length,
              margenPromedio: margenPromedio,
            ),
            const SizedBox(height: 18),
            // Buscador y Pestañas
            _buildSearchAndTabsBar(),
            const SizedBox(height: 14),
            // Contenido de las pestañas
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
                    )
                  : _productos.isEmpty
                      ? _buildEmptyState('No se encontraron productos', Icons.search_off_rounded)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildComprasTab(),
                            _buildVentasTab(),
                            _buildRentabilidadTab(),
                            _buildSinMovimientoTab(sinMovimientoConStock),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CABECERA LIMPIA (Sin botón actualizar, diseño exacto a imagen 2) ---
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
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
                  'Análisis de Negocio',
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
                'Resumen inteligente para la toma de decisiones',
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
        ElevatedButton.icon(
          onPressed: () => AnalysisReportService.generatePurchaseOrderPdf(_productos),
          icon: const Icon(Icons.file_download_outlined, size: 17),
          label: const Text(
            'EXPORTAR PLAN',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D1D1F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // --- BANNER DE KPIS EJECUTIVOS ---
  Widget _buildExecutiveBanner({
    required double inversionTotal,
    required int productosAPedirCount,
    required int quiebresCount,
    required double capitalInmovilizado,
    required int productosInmovilizadosCount,
    required double margenPromedio,
  }) {
    return Row(
      children: [
        Expanded(
          child: _executiveCard(
            title: 'INVERSIÓN SUGERIDA',
            value: 'S/ ${_formatMoney(inversionTotal)}',
            subtext: '$productosAPedirCount productos a reponer',
            icon: Icons.shopping_bag_outlined,
            accentColor: const Color(0xFF007AFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _executiveCard(
            title: 'QUIEBRES CRÍTICOS',
            value: '$quiebresCount',
            subtext: quiebresCount == 1 ? '1 producto sin existencias' : '$quiebresCount productos agotados',
            icon: Icons.error_outline_rounded,
            accentColor: const Color(0xFFFF3B30),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _executiveCard(
            title: 'CAPITAL INMOVILIZADO',
            value: 'S/ ${_formatMoney(capitalInmovilizado)}',
            subtext: '$productosInmovilizadosCount ítems con stock dormido',
            icon: Icons.inventory_2_outlined,
            accentColor: const Color(0xFFFF9500),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _executiveCard(
            title: 'MARGEN COMERCIAL',
            value: '${margenPromedio.toStringAsFixed(1)}%',
            subtext: 'Rentabilidad promedio s/ventas',
            icon: Icons.trending_up_rounded,
            accentColor: const Color(0xFF34C759),
          ),
        ),
      ],
    );
  }

  Widget _executiveCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: const Color(0xFF1D1D1F).withOpacity(0.45),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtext,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF1D1D1F).withOpacity(0.45),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- BARRA DE BÚSQUEDA Y PESTAÑAS SEGMENTADAS ---
  Widget _buildSearchAndTabsBar() {
    int urgentes = _productos
        .where((p) =>
            p['recomendacion'] == 'URGENTE' ||
            p['recomendacion'] == 'SIN STOCK' ||
            p['recomendacion'] == 'POR AGOTARSE')
        .length;
    int estancadosConStock = _productos
        .where((p) => (p['totalVendidas'] as int? ?? 0) == 0 && (p['stockUtil'] as int? ?? 0) > 0)
        .length;

    return Column(
      children: [
        // Buscador
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1D1D1F).withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              icon: Icon(Icons.search_rounded,
                  color: const Color(0xFF1D1D1F).withOpacity(0.35), size: 18),
              hintText: 'Buscar por producto o fórmula...',
              border: InputBorder.none,
              hintStyle: TextStyle(
                  color: const Color(0xFF1D1D1F).withOpacity(0.35),
                  fontFamily: 'Outfit',
                  fontSize: 13.5),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pestañas Segmentadas
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5EA).withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _segmentedTabButton(0, 'Plan de Compras', Icons.shopping_cart_checkout_rounded, badgeCount: urgentes),
              _segmentedTabButton(1, 'Más Vendidos', Icons.trending_up_rounded),
              _segmentedTabButton(2, 'Rentabilidad Real', Icons.monetization_on_outlined),
              _segmentedTabButton(3, 'Capital Inmovilizado', Icons.remove_shopping_cart_outlined, badgeCount: estancadosConStock),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segmentedTabButton(int index, String label, IconData icon, {int badgeCount = 0}) {
    bool isSelected = _tabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF8E8E93),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1D1D1F) : const Color(0xFF6E6E73),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: 'Outfit',
                  fontSize: 13,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF3B30) : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PLAN DE COMPRAS
  // ==========================================
  Widget _buildComprasTab() {
    final urgent = _productos.where((p) =>
        p['recomendacion'] == 'SIN STOCK' ||
        p['recomendacion'] == 'POR AGOTARSE' ||
        p['recomendacion'] == 'URGENTE').toList();

    final regular = _productos.where((p) =>
        p['recomendacion'] == 'REPOSICIÓN PREVENTIVA').toList();

    List<Map<String, dynamic>> itemsMostrar;
    if (_filtroSubCompras == 'URGENTES') {
      itemsMostrar = urgent;
    } else if (_filtroSubCompras == 'PREVENTIVAS') {
      itemsMostrar = regular;
    } else {
      itemsMostrar = [...urgent, ...regular];
    }

    final totalInversionPlan = itemsMostrar.fold<double>(
      0.0,
      (sum, p) => sum + ((p['inversionSugerida'] as num?)?.toDouble() ?? 0.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de control de la pestaña (Filtro + Resumen de inversión)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _filterChip('TODOS (${urgent.length + regular.length})', 'TODOS'),
                const SizedBox(width: 8),
                _filterChip('CRÍTICOS (${urgent.length})', 'URGENTES'),
                const SizedBox(width: 8),
                _filterChip('PREVENTIVOS (${regular.length})', 'PREVENTIVAS'),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 15, color: Color(0xFF007AFF)),
                  const SizedBox(width: 8),
                  Text(
                    'Presupuesto requerido: S/ ${_formatMoney(totalInversionPlan)}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Encabezado de la tabla
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(flex: 4, child: _tableHeader('PRODUCTO / SKU', textAlign: TextAlign.left)),
              Expanded(flex: 2, child: _tableHeader('ESTADO')),
              Expanded(flex: 2, child: _tableHeader('STOCK ACTUAL')),
              Expanded(flex: 2, child: _tableHeader('A PEDIR (SUGERIDO)')),
              Expanded(flex: 2, child: _tableHeader('INVERSIÓN EST.')),
              const SizedBox(width: 32),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: itemsMostrar.isEmpty
              ? _buildEmptyState(
                  _filtroSubCompras == 'URGENTES'
                      ? 'Excelente, no hay quiebres ni productos urgentes por reponer'
                      : 'No hay sugerencias de compra para este filtro',
                  Icons.check_circle_outline_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: itemsMostrar.length,
                  itemBuilder: (context, index) {
                    final item = itemsMostrar[index];
                    final double inv = (item['inversionSugerida'] as num?)?.toDouble() ?? 0.0;
                    return _buildModernCardRow(
                      product: item,
                      col1: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF1D1D1F),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'SKU: PRD-${item['ID'].toString().padLeft(4, '0')}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: const Color(0xFF1D1D1F).withOpacity(0.4),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item['Tipo_Producto'] ?? 'Unidad',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      col2: _buildStatusChip(item['recomendacion']),
                      col3: Text(
                        item['stockUtilTxt'] ?? '0',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      col4: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['compraSugeridaTxt'] ?? '${item['compraMensualSugerida']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                      col5: Text(
                        'S/ ${_formatMoney(inv)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filtroSubCompras == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroSubCompras = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D1D1F) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF1D1D1F),
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: MÁS VENDIDOS (Ranking estructurado)
  // ==========================================
  Widget _buildVentasTab() {
    final topVented = _productos.where((p) => (p['totalVendidas'] as int? ?? 0) > 0).toList();
    topVented.sort((a, b) => (b['totalVendidas'] as int).compareTo(a['totalVendidas'] as int));

    final maxVendido = topVented.isNotEmpty ? (topVented.first['totalVendidas'] as int) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(flex: 4, child: _tableHeader('RANKING & PRODUCTO', textAlign: TextAlign.left)),
              Expanded(flex: 2, child: _tableHeader('UNIDADES VENDIDAS')),
              Expanded(flex: 2, child: _tableHeader('INGRESOS GENERADOS')),
              Expanded(flex: 2, child: _tableHeader('GANANCIA BRUTA')),
              Expanded(flex: 2, child: _tableHeader('STOCK ACTUAL')),
              const SizedBox(width: 32),
            ],
          ),
        ),
        Expanded(
          child: topVented.isEmpty
              ? _buildEmptyState('No hay ventas registradas en el período', Icons.trending_up_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: topVented.length,
                  itemBuilder: (context, index) {
                    final item = topVented[index];
                    final int vendidas = item['totalVendidas'] as int;
                    final double precio = (item['Precio_Unidad'] as num? ?? 0.0).toDouble();
                    final double ingresos = vendidas * precio;
                    final double ganancia = (item['gananciaBrutaTotal'] as num?)?.toDouble() ?? 0.0;
                    final int stock = item['stockUtil'] as int? ?? 0;
                    final double shareRatio = (vendidas / maxVendido).clamp(0.0, 1.0);

                    return _buildModernCardRow(
                      product: item,
                      col1: Row(
                        children: [
                          _buildRankingMedal(index + 1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['nombre'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: Color(0xFF1D1D1F),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: shareRatio,
                                    minHeight: 4,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      index == 0 ? const Color(0xFFFFD700) : const Color(0xFF34C759),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      col2: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['totalVendidoTxt'] ?? '$vendidas und.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Outfit',
                              fontSize: 13.5,
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                          Text(
                            'Últ. semana: ${item['ventasUltimaSemana']} und.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      col3: Text(
                        'S/ ${_formatMoney(ingresos)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      col4: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+ S/ ${_formatMoney(ganancia)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                            fontSize: 12.5,
                            color: Color(0xFF34C759),
                          ),
                        ),
                      ),
                      col5: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (stock <= 5)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFF3B30)),
                            ),
                          Text(
                            item['stockUtilTxt'] ?? '$stock und.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              color: stock <= 5 ? const Color(0xFFFF3B30) : const Color(0xFF1D1D1F),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRankingMedal(int position) {
    Color bg = Colors.grey.shade200;
    Color textColor = Colors.grey.shade700;
    if (position == 1) {
      bg = const Color(0xFFFFD700);
      textColor = const Color(0xFF684900);
    } else if (position == 2) {
      bg = const Color(0xFFE0E0E0);
      textColor = const Color(0xFF424242);
    } else if (position == 3) {
      bg = const Color(0xFFCD7F32).withOpacity(0.3);
      textColor = const Color(0xFF5C3300);
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$position',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: RENTABILIDAD REAL
  // ==========================================
  Widget _buildRentabilidadTab() {
    final profitable = List<Map<String, dynamic>>.from(_productos);
    // Ordenar por ganancia bruta real total aportada
    profitable.sort((a, b) {
      final gA = (a['gananciaBrutaTotal'] as num?)?.toDouble() ?? 0.0;
      final gB = (b['gananciaBrutaTotal'] as num?)?.toDouble() ?? 0.0;
      return gB.compareTo(gA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(flex: 4, child: _tableHeader('PRODUCTO', textAlign: TextAlign.left)),
              Expanded(flex: 2, child: _tableHeader('PRECIO / COSTO')),
              Expanded(flex: 2, child: _tableHeader('MARGEN (%)')),
              Expanded(flex: 2, child: _tableHeader('GANANCIA TOTAL')),
              Expanded(flex: 2, child: _tableHeader('CLASIFICACIÓN')),
              const SizedBox(width: 32),
            ],
          ),
        ),
        Expanded(
          child: profitable.isEmpty
              ? _buildEmptyState('No hay productos con datos de rentabilidad', Icons.monetization_on_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: profitable.length,
                  itemBuilder: (context, index) {
                    final item = profitable[index];
                    final double precio = (item['Precio_Unidad'] as num? ?? 0.0).toDouble();
                    final double costo = (item['costoReal'] as num?)?.toDouble() ?? 0.0;
                    final double margenPct = double.tryParse(item['margenPorcentaje'] ?? '0') ?? 0.0;
                    final double gananciaTotal = (item['gananciaBrutaTotal'] as num?)?.toDouble() ?? 0.0;
                    final int vendidas = item['totalVendidas'] as int? ?? 0;

                    // Clasificación estratégica
                    String etiqueta = 'ESTABLE';
                    Color etiquetaColor = Colors.grey.shade700;
                    if (vendidas >= 10 && margenPct >= 35) {
                      etiqueta = 'ESTRELLA';
                      etiquetaColor = Colors.purple;
                    } else if (vendidas >= 15 && margenPct < 35) {
                      etiqueta = 'VOLUMEN';
                      etiquetaColor = const Color(0xFF007AFF);
                    } else if (vendidas < 10 && margenPct >= 40) {
                      etiqueta = 'ALTO MARGEN';
                      etiquetaColor = const Color(0xFF34C759);
                    } else if (vendidas == 0) {
                      etiqueta = 'SIN ROTACIÓN';
                      etiquetaColor = Colors.orange;
                    }

                    return _buildModernCardRow(
                      product: item,
                      col1: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF1D1D1F),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            'SKU: PRD-${item['ID'].toString().padLeft(4, '0')}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: const Color(0xFF1D1D1F).withOpacity(0.4),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      col2: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Venta: S/ ${_formatMoney(precio)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Outfit',
                              fontSize: 12.5,
                              color: Color(0xFF1D1D1F),
                            ),
                          ),
                          Text(
                            'Costo: S/ ${_formatMoney(costo)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      col3: Text(
                        '${margenPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: margenPct >= 30 ? const Color(0xFF34C759) : const Color(0xFF1D1D1F),
                        ),
                      ),
                      col4: Text(
                        '+ S/ ${_formatMoney(gananciaTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          color: Color(0xFF34C759),
                        ),
                      ),
                      col5: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: etiquetaColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          etiqueta,
                          style: TextStyle(
                            color: etiquetaColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: CAPITAL INMOVILIZADO (Estancados)
  // ==========================================
  Widget _buildSinMovimientoTab(List<Map<String, dynamic>> sinMovimiento) {
    // Ordenar de mayor a menor dinero inmovilizado
    final estancadosOrdenados = List<Map<String, dynamic>>.from(sinMovimiento);
    estancadosOrdenados.sort((a, b) {
      final cA = (a['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0;
      final cB = (b['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0;
      return cB.compareTo(cA);
    });

    final double totalDineroDormido = estancadosOrdenados.fold<double>(
      0.0,
      (sum, p) => sum + ((p['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ribbon informativo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFFF9500)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tienes S/ ${_formatMoney(totalDineroDormido)} retenidos en ${estancadosOrdenados.length} productos sin ventas. Se muestran priorizados por mayor capital en riesgo.',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB26A00),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(flex: 4, child: _tableHeader('PRODUCTO ESTANCADO', textAlign: TextAlign.left)),
              Expanded(flex: 2, child: _tableHeader('STOCK EN BODEGA')),
              Expanded(flex: 2, child: _tableHeader('CAPITAL RETENIDO')),
              Expanded(flex: 2, child: _tableHeader('DÍAS SIN VENTA')),
              Expanded(flex: 2, child: _tableHeader('ACCIÓN SUGERIDA')),
              const SizedBox(width: 32),
            ],
          ),
        ),
        Expanded(
          child: estancadosOrdenados.isEmpty
              ? _buildEmptyState('¡Felicitaciones! Todo el inventario con stock registra movimiento comercial', Icons.check_circle_outline_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: estancadosOrdenados.length,
                  itemBuilder: (context, index) {
                    final item = estancadosOrdenados[index];
                    final double dineroRetenido = (item['capitalInmovilizado'] as num?)?.toDouble() ?? 0.0;
                    final int dias = item['diasActivos'] as int? ?? 30;

                    // Sugerencia táctica
                    String accion = 'Armar Combo';
                    Color accionColor = Colors.blue;
                    if (dineroRetenido > 100) {
                      accion = 'Promoción 2x1';
                      accionColor = const Color(0xFFFF3B30);
                    } else if (dias > 60) {
                      accion = 'Rebaja 20%';
                      accionColor = Colors.orange;
                    }

                    return _buildModernCardRow(
                      product: item,
                      col1: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF1D1D1F),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            'SKU: PRD-${item['ID'].toString().padLeft(4, '0')}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: const Color(0xFF1D1D1F).withOpacity(0.4),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                      col2: Text(
                        item['stockUtilTxt'] ?? '0',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      col3: Text(
                        'S/ ${_formatMoney(dineroRetenido)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          fontSize: 13.5,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                      col4: Text(
                        '$dias días',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                          fontSize: 12.5,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      col5: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          accion,
                          style: TextStyle(
                            color: accionColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- COMPONENTES AUXILIARES VISUALES ---
  Widget _tableHeader(String text, {TextAlign textAlign = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1D1D1F).withOpacity(0.38),
          letterSpacing: 0.8,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildModernCardRow({
    required Map<String, dynamic> product,
    required Widget col1,
    required Widget col2,
    required Widget col3,
    required Widget col4,
    required Widget col5,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showProductDetails(product),
          hoverColor: const Color(0xFFFF3B30).withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 4, child: col1),
                Expanded(flex: 2, child: Center(child: col2)),
                Expanded(flex: 2, child: Center(child: col3)),
                Expanded(flex: 2, child: Center(child: col4)),
                Expanded(flex: 2, child: Center(child: col5)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: const Color(0xFF1D1D1F).withOpacity(0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text) {
    Color color = Colors.grey.shade600;
    if (text == 'URGENTE' || text == 'SIN STOCK') color = const Color(0xFFFF3B30);
    if (text == 'ESTABLE' || text == 'SALUDABLE') color = const Color(0xFF34C759);
    if (text == 'POR AGOTARSE') color = const Color(0xFFFF9500);
    if (text == 'REPOSICIÓN PREVENTIVA') color = const Color(0xFF007AFF);
    if (text == 'SOBRESTOCK' || text == 'EXCESO') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: const Color(0xFF1D1D1F).withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1D1D1F).withOpacity(0.6),
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay registros que coincidan con los criterios actuales.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1D1D1F).withOpacity(0.35),
                fontFamily: 'Outfit',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
