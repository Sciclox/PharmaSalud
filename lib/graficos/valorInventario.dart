import 'package:flutter/material.dart';
import 'package:pharma_salud/repositories/graficos.dart';
import 'package:pharma_salud/utils/format_utils.dart';

class ValorInventarioChart extends StatefulWidget {
  const ValorInventarioChart({super.key});

  @override
  _ValorInventarioChartState createState() => _ValorInventarioChartState();
}

class _ValorInventarioChartState extends State<ValorInventarioChart> {
  final ChartRepository _chartRepository = ChartRepository();
  double valorInversion = 0.0;
  double valorVenta = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final datos = await _chartRepository.obtenerValorInventario();
      if (datos.isNotEmpty) {
        final row = datos.first;
        if (mounted) {
          setState(() {
            valorInversion = (row['VALOR_COSTO'] is num)
                ? row['VALOR_COSTO'].toDouble()
                : 0.0;
            valorVenta = (row['VALOR_VENTA'] is num)
                ? row['VALOR_VENTA'].toDouble()
                : 0.0;
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF2F2F7), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.01),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Valorización del Inventario',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1C1C1E),
                      fontFamily: 'Outfit',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Balance entre costo de inversión y proyección de venta',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A24), Color(0xFF2C2C3E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1A24).withAlpha(40),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ],
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 32,
              children: [
                // Bloque Inversión
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_rounded, color: Colors.white.withAlpha(150), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'COSTO DE INVERSIÓN',
                          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'S/ ${formatMoney(valorInversion)}',
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, fontFamily: 'Outfit', letterSpacing: -1),
                    ),
                  ],
                ),
                
                // Divisor Visual (solo visible en pantallas anchas)
                Container(
                  width: 2,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Bloque Venta
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up_rounded, color: Color(0xFF34C759), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'VALOR DE VENTA',
                          style: TextStyle(color: Color(0xFF34C759), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'S/ ${formatMoney(valorVenta)}',
                      style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, fontFamily: 'Outfit', letterSpacing: -1),
                    ),
                  ],
                ),

                // Bloque Badge ROI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34C759).withAlpha(50), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'MARGEN BRUTO ESTIMADO',
                        style: TextStyle(color: Color(0xFF34C759), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Outfit', letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final double ganancia = valorVenta - valorInversion;
                          final double margenPorcentaje = valorInversion > 0 ? (ganancia / valorInversion) * 100 : 0.0;
                          return Text(
                            '+${margenPorcentaje.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Color(0xFF34C759), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'Outfit'),
                          );
                        }
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
