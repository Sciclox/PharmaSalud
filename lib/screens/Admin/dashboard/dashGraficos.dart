import 'package:flutter/material.dart';
import 'package:pharma_salud/utils/format_utils.dart';
import 'package:pharma_salud/graficos/ventasMensuales.dart';
import 'package:pharma_salud/graficos/ventasSemanales.dart';
import 'package:pharma_salud/graficos/topProductos.dart';
import 'package:pharma_salud/graficos/estadoStock.dart';
import 'package:pharma_salud/graficos/ventasCategoria.dart';
import 'package:pharma_salud/graficos/rankingVendedores.dart';

import 'package:pharma_salud/graficos/valorInventario.dart';

import 'package:pharma_salud/screens/Admin/dashboard/components/bajoStockDialog.dart';

import 'package:pharma_salud/repositories/graficos.dart';
import 'package:pharma_salud/screens/Admin/dashboard/components/vencimientosDialog.dart';
import 'package:pharma_salud/repositories/sobranteCaja.dart';

class DashboardInicialScreen extends StatefulWidget {
  const DashboardInicialScreen({super.key});

  @override
  State<DashboardInicialScreen> createState() => _DashboardInicialScreenState();
}

class _DashboardInicialScreenState extends State<DashboardInicialScreen> {
  final ChartRepository _chartRepository = ChartRepository();
  double _ventasDia = 0.0;
  double _ventasSemana = 0.0;
  int _bajoStockCount = 0;
  int _vencimientosCount = 0;
  double _sobranteHoy = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final vDia = await _chartRepository.obtenerVentasDia();
      final vSemana = await _chartRepository.obtenerVentasSemanaTotal();
      final bStock = await _chartRepository.obtenerConteoBajoStock();
      final venc = await _chartRepository.obtenerConteoVencimientos();
      final sHoy = await SobranteCajaRepository().obtenerTotalGeneralHoy();

      if (mounted) {
        setState(() {
          _ventasDia = vDia;
          _ventasSemana = vSemana;
          _bajoStockCount = bStock;
          _vencimientosCount = venc;
          _sobranteHoy = sHoy;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Dinámico
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
                          'Resumen Operativo',
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
                        'Monitoreo centralizado de Pharma Salud',
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: Color(0xFFFF3B30)),
                      const SizedBox(width: 10),
                      Text(
                        _getFormattedDate(),
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1D1D1F)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Tarjetas de KPI Rápidos Reales (Responsive Wrap)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 1300) crossAxisCount = 4;
                if (constraints.maxWidth < 1000) crossAxisCount = 2;
                if (constraints.maxWidth < 500) crossAxisCount = 1;

                final double spacing = 20.0;
                final double cardWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _KPICard(
                        title: 'Venta de Hoy',
                        value: 'S/ ${formatMoney(_ventasDia)}',
                        icon: Icons.payments_rounded,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _KPICard(
                        title: 'Venta Semanal',
                        value: 'S/ ${formatMoney(_ventasSemana)}',
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFF5856D6),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _KPICard(
                        title: 'Bajo Stock',
                        value: '$_bajoStockCount',
                        icon: Icons.warning_rounded,
                        color: const Color(0xFFFF9500),
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (_) => const BajoStockDetalleDialog());
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _KPICard(
                        title: 'Vencimientos',
                        value: '$_vencimientosCount',
                        icon: Icons.event_busy_rounded,
                        color: const Color(0xFFFF3B30),
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (_) => const VencimientosDetalleDialog());
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),

            // Gráfico Principal: Ventas Mensuales (Ocupa todo el ancho)
            const SizedBox(
              width: double.infinity,
              child: VentasChart(),
            ),
            const SizedBox(height: 32),

            // Segunda Fila: Valor de Inventario
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ValorInventarioChart())]),

            const SizedBox(height: 20),

            // Tercera Fila: Ranking Vendedores y Categorías
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: RankingVendedoresChart()),
                SizedBox(width: 20),
                Expanded(child: VentasCategoriaChart()),
              ],
            ),

            const SizedBox(height: 20),

            // Tercera Fila: Ventas Semanales y Top Productos
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: VentasChartSemanal()), SizedBox(width: 20), Expanded(child: TopProductosChart())]),
            
            const SizedBox(height: 20),
            
            // Cuarta Fila: Estado del Inventario
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: EstadoStockChart())]),


            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return "${now.day} ${months[now.month - 1]}, ${now.year}";
  }
}

class _KPICard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_KPICard> createState() => _KPICardState();
}


class _KPICardState extends State<_KPICard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getLighterColor(Color color, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final lightColor = _getLighterColor(widget.color, 0.12);
    final darkColor = widget.color;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [lightColor, darkColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: darkColor.withOpacity(_isHovered ? 0.4 : 0.2),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 10 : 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background large icon
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: _isHovered ? 1.1 : 1.0,
                    child: Icon(
                      widget.icon,
                      size: 110,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.onTap != null)
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isHovered ? 1.0 : 0.5,
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Outfit',
                            letterSpacing: -1.0,
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
}

