import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class RankingVendedoresChart extends StatefulWidget {
  const RankingVendedoresChart({super.key});

  @override
  State<RankingVendedoresChart> createState() => _RankingVendedoresChartState();
}

class _RankingVendedoresChartState extends State<RankingVendedoresChart> {
  final ChartRepository _chartRepository = ChartRepository();
  List<Map<String, dynamic>> datosVendedores = [];
  Map<String, dynamic>? vendedorDelMes;
  bool isLoading = true;
  String _filtroPeriodo = 'mes'; // 'dia' o 'mes'

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() => isLoading = true);
    try {
      final datos = await _chartRepository.obtenerVentasPorVendedor(
          periodo: _filtroPeriodo);

      // Solo buscamos vendedor del mes si estamos cargando por primera vez o si cambiamos al mes
      final topVendedor = await _chartRepository.obtenerVendedorDelMes();

      if (mounted) {
        setState(() {
          datosVendedores = datos;
          vendedorDelMes = topVendedor;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _cambiarFiltro(String periodo) {
    if (_filtroPeriodo == periodo) return;
    setState(() => _filtroPeriodo = periodo);
    cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Widget Destacado: Vendedor del Mes (Siempre visible arriba)
        if (vendedorDelMes != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFF2F2F7), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.03),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.01),
                  blurRadius: 8,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF9500), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vendedor Destacado del Mes',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendedorDelMes!['NOMBRE_VENDEDOR'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D1D1F),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${formatMoney(vendedorDelMes!['TOTAL_VENTAS'] ?? 0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF34C759),
                          fontFamily: 'Outfit',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFF2F2F7), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.03),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.01),
                blurRadius: 8,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                spacing: 16,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0097A7).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Desempeño Vendedores',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1C1C1E),
                                fontFamily: 'Outfit',
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Ventas totales por colaborador',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8E8E93),
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Outfit',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FilterButton(
                          label: 'Día',
                          isSelected: _filtroPeriodo == 'dia',
                          onTap: () => _cambiarFiltro('dia'),
                        ),
                        // Separador visual pequeño
                        const SizedBox(width: 2),
                        _FilterButton(
                          label: 'Mes',
                          isSelected: _filtroPeriodo == 'mes',
                          onTap: () => _cambiarFiltro('mes'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()))
              else if (datosVendedores.isEmpty)
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: Text('No hay ventas registradas en este periodo.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final maxTotal = datosVendedores.isNotEmpty 
                        ? datosVendedores.map((e) => (e['TOTAL_VENTAS'] as num).toDouble()).reduce((a, b) => a > b ? a : b) 
                        : 100.0;
                    
                    return SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          maxY: maxTotal * 1.2,
                          barGroups: List.generate(datosVendedores.length, (index) {
                            final total = (datosVendedores[index]['TOTAL_VENTAS'] as num).toDouble();
                            
                            final List<Color> vendorColors = [
                              const Color(0xFF00BCD4), const Color(0xFFE91E63), const Color(0xFF8BC34A),
                              const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF3F51B5), const Color(0xFF009688),
                            ];
                            final c = vendorColors[index % vendorColors.length];

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: total,
                                  width: 28,
                                  borderRadius: BorderRadius.zero,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [c, c.withValues(alpha: 0.85)],
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: maxTotal * 1.2,
                                    color: const Color(0xFFF3F4F6),
                                  ),
                                )
                              ],
                            );
                          }),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index < 0 || index >= datosVendedores.length) return const SizedBox.shrink();

                                  final nombre = datosVendedores[index]['NOMBRE_VENDEDOR'] ?? '';
                                  final primerNombre = nombre.split(' ').first;
                                  
                                  final List<Color> vendorColors = [
                                    const Color(0xFF00BCD4), const Color(0xFFE91E63), const Color(0xFF8BC34A),
                                    const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF3F51B5), const Color(0xFF009688),
                                  ];
                                  final c = vendorColors[index % vendorColors.length];

                                  return SizedBox(
                                    width: 56, // Doble del barWidth para espacio
                                    height: 40,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _SlantedConnectorPainter(color: c, barWidth: 28),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          top: 16,
                                          width: 28, // Mismo que la barra
                                          height: 20,
                                          child: Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: c,
                                              border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: c.withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                            child: Text(
                                              primerNombre,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                fontFamily: 'Outfit',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.clip,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                interval: maxTotal > 0 ? (maxTotal * 1.2) / 5 : 100,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0 || value == meta.max) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Text('S/ ${formatMoney(value)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 9, color: Colors.black38)),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.black.withValues(alpha: 0.05),
                                strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => Colors.white,
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              tooltipMargin: 12,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final nombre = datosVendedores[groupIndex]['NOMBRE_VENDEDOR'] ?? '';
                                final total = rod.toY;
                                final List<Color> vendorColors = [
                                  const Color(0xFF00BCD4), const Color(0xFFE91E63), const Color(0xFF8BC34A),
                                  const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF3F51B5), const Color(0xFF009688),
                                ];
                                final c = vendorColors[groupIndex % vendorColors.length];
                                
                                return BarTooltipItem(
                                  "$nombre\n",
                                  const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: "S/ ${formatMoney(total)}",
                                      style: TextStyle(
                                        color: c,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Outfit',
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.black54,
          ),
        ),
      ),
    );
  }
}

class _SlantedConnectorPainter extends CustomPainter {
  final Color color;
  final double barWidth;
  _SlantedConnectorPainter({required this.color, required this.barWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // Si canvas width es doble de barWidth, e.g. 56 vs 28.
    // startX = (56 - 28) / 2 = 14
    final double startX = (size.width - barWidth) / 2;
    final double endX = startX + barWidth;
    final double offset = barWidth / 2; // Desplazamiento isométrico
    
    final path = Path();
    path.moveTo(startX, 0);  // Borde sup izq (toca la barra)
    path.lineTo(endX, 0);  // Borde sup der
    path.lineTo(endX - offset, 16); // Borde inf der (desplazado a la izq)
    path.lineTo(startX - offset, 16);  // Borde inf izq
    path.close();

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
