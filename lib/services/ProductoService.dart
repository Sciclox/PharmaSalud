import 'package:flutter/foundation.dart'; // compute
import 'package:pharma_salud/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ProductoService {
  Future<List<Map<String, dynamic>>> analizarProductos({
    String? filtroNombre,
    String? filtroTendencia,
    String? filtroRecomendacion,
  }) async {
    final db = await DatabaseHelper().database;

    // 1. Obtener productos base
    final productos = await db.query(
      'PRODUCTO',
      where: filtroNombre != null && filtroNombre.isNotEmpty
          ? 'Nombre_Producto LIKE ?'
          : null,
      whereArgs: filtroNombre != null && filtroNombre.isNotEmpty
          ? ['%$filtroNombre%']
          : null,
    );

    if (productos.isEmpty) return [];

    final ids = productos.map((p) => (p['ID'] ?? p['id']) as int).toList();

    // 2. Definición de Ventanas de Tiempo
    final hoy = DateTime.now();
    final fechaCorte12Semanas = hoy.subtract(const Duration(days: 84));
    final fechaCorte1Semana = hoy.subtract(const Duration(days: 7));

    final fechaCorte12SStr =
        DateFormat('yyyy-MM-dd').format(fechaCorte12Semanas);
    final hoyStr = DateFormat('yyyy-MM-dd').format(hoy);

    // 3. Recolección de Datos
    final List<Map<String, dynamic>> ventasDetalle = [];
    final Map<int, dynamic> ventasTotalesMap = {};
    final Map<int, int> vencidosMap = {};
    final List<Map<String, dynamic>> kardexData = [];

    const int chunkSize = 500;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunkIds = ids.sublist(i, end);
      final validIds = chunkIds.join(',');

      if (validIds.isEmpty) continue;

      // Obtener nombres para búsqueda en Kardex
      final productsInChunk = productos
          .where((p) => chunkIds.contains((p['ID'] ?? p['id']) as int))
          .toList();
      final productNames =
          productsInChunk.map((p) => "'${p['Nombre_Producto']}'").join(',');

      final vChunk = await db.rawQuery('''
        SELECT 
          DV.PRODUCTO_ID, 
          DV.FECHA,
          CASE 
            WHEN DV.TIPO_VENTA = 'Venta por caja' THEN DV.CANTIDAD * P.Cantidad_Presentacion
            WHEN DV.TIPO_VENTA = 'Venta por blister' THEN DV.CANTIDAD * P.Cantidad_Presentacion_blister
            ELSE DV.CANTIDAD 
          END as CANTIDAD
        FROM DETALLES_VENTA DV
        JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
        WHERE DV.PRODUCTO_ID IN ($validIds) AND DV.FECHA >= ?
      ''', [fechaCorte12SStr]);
      ventasDetalle.addAll(vChunk);

      final totChunk = await db.rawQuery('''
        SELECT 
          DV.PRODUCTO_ID, 
          SUM(CASE WHEN DV.TIPO_VENTA = 'Venta por caja' THEN DV.CANTIDAD ELSE 0 END) as Cajas,
          SUM(CASE WHEN DV.TIPO_VENTA = 'Venta por blister' THEN DV.CANTIDAD ELSE 0 END) as Blisters,
          SUM(CASE WHEN DV.TIPO_VENTA = 'Venta por unidad' THEN DV.CANTIDAD ELSE 0 END) as Unidades,
          SUM(
            CASE 
              WHEN DV.TIPO_VENTA = 'Venta por caja' THEN DV.CANTIDAD * P.Cantidad_Presentacion
              WHEN DV.TIPO_VENTA = 'Venta por blister' THEN DV.CANTIDAD * P.Cantidad_Presentacion_blister
              ELSE DV.CANTIDAD 
            END
          ) as TotalUnidades 
        FROM DETALLES_VENTA DV
        JOIN PRODUCTO P ON DV.PRODUCTO_ID = P.ID
        WHERE DV.PRODUCTO_ID IN ($validIds) 
        GROUP BY DV.PRODUCTO_ID
      ''');
      for (var r in totChunk) {
        ventasTotalesMap[r['PRODUCTO_ID'] as int] = {
          'cajas': (r['Cajas'] as num?)?.toInt() ?? 0,
          'blisters': (r['Blisters'] as num?)?.toInt() ?? 0,
          'unidades': (r['Unidades'] as num?)?.toInt() ?? 0,
          'total': (r['TotalUnidades'] as num?)?.toInt() ?? 0,
        };
      }

      final venChunk = await db.rawQuery('''
        SELECT Producto_ID, SUM(Cantidad) as TotalVencido 
        FROM FECHA_VENCIMIENTO 
        WHERE Producto_ID IN ($validIds) AND Fecha_Vencimiento < ? 
        GROUP BY Producto_ID
      ''', [hoyStr]);
      for (var r in venChunk) {
        vencidosMap[r['Producto_ID'] as int] =
            (r['TotalVencido'] as num?)?.toInt() ?? 0;
      }

      // Obtener historial de Kardex para análisis de duración y frecuencia
      final kChunk = await db.rawQuery('''
        SELECT NOMBRE_PRODUCTO, FECHA_MOVIMIENTO, TIPO_MOVIMIENTO, CANTIDAD 
        FROM KARDEX 
        WHERE NOMBRE_PRODUCTO IN ($productNames)
        ORDER BY FECHA_MOVIMIENTO ASC
      ''');
      kardexData.addAll(kChunk);
    }

    // 4. Procesamiento
    final resultados = await compute(_procesarInteligente, {
      'productos': productos,
      'ventasDetalle': ventasDetalle,
      'ventasTotalesMap': ventasTotalesMap,
      'vencidosMap': vencidosMap,
      'kardexData': kardexData,
      'hoy': hoy.toIso8601String(),
      'fechaCorte1Semana': fechaCorte1Semana.toIso8601String(),
    });

    // 5. Filtrado
    Iterable<Map<String, dynamic>> filtrados = resultados;
    if (filtroTendencia != null && filtroTendencia.toUpperCase() != "TODOS") {
      filtrados = filtrados
          .where((e) => e['tendencia'] == filtroTendencia.toUpperCase());
    }
    if (filtroRecomendacion != null &&
        filtroRecomendacion.toUpperCase() != "TODOS") {
      filtrados = filtrados.where((e) => e['recomendacion']
          .toString()
          .toUpperCase()
          .contains(filtroRecomendacion.toUpperCase()));
    }

    return filtrados.toList();
  }
}

List<Map<String, dynamic>> _procesarInteligente(Map<String, dynamic> data) {
  final productos = List<Map<String, dynamic>>.from(data['productos']);
  final ventasDetalle = List<Map<String, dynamic>>.from(data['ventasDetalle']);
  final Map<int, dynamic> ventasTotalesMap =
      Map<int, dynamic>.from(data['ventasTotalesMap']);
  final Map<int, int> vencidosMap = Map<int, int>.from(data['vencidosMap']);
  final List<Map<String, dynamic>> kardexData =
      List<Map<String, dynamic>>.from(data['kardexData']);
  final hoy = DateTime.parse(data['hoy']);
  final fechaCorte1Semana = DateTime.parse(data['fechaCorte1Semana']);

  final Map<int, List<Map<String, dynamic>>> ventasPorProducto = {};
  for (var v in ventasDetalle) {
    final id = v['PRODUCTO_ID'] as int;
    (ventasPorProducto[id] ??= []).add(v);
  }

  // Agrupar Kardex por nombre de producto
  final Map<String, List<Map<String, dynamic>>> kardexPorProducto = {};
  for (var k in kardexData) {
    final nombre = k['NOMBRE_PRODUCTO'] as String;
    (kardexPorProducto[nombre] ??= []).add(k);
  }

  final List<Map<String, dynamic>> res = [];

  for (var p in productos) {
    final id = (p['ID'] ?? p['id']) as int;
    final nombre = p['Nombre_Producto'] as String;
    final stockTotal = (p['Cantidad_Total'] as num? ?? 0).toInt();
    final stockVencido = (vencidosMap[id] ?? 0);
    final stockUtil = (stockTotal - stockVencido).clamp(0, 9999999);

    // Ventas 12 semanas
    final misVentas = ventasPorProducto[id] ?? [];
    final ventasPorSemana = List<int>.filled(12, 0);
    int ventasUltimaSemana = 0;

    for (var v in misVentas) {
      final fecha = DateTime.tryParse(v['FECHA']?.toString() ?? '');
      if (fecha == null) continue;

      final diffSemanas = hoy.difference(fecha).inDays ~/ 7;
      if (diffSemanas >= 0 && diffSemanas < 12) {
        ventasPorSemana[diffSemanas] += (v['CANTIDAD'] as num? ?? 0).toInt();
      }

      if (fecha.isAfter(fechaCorte1Semana)) {
        ventasUltimaSemana += (v['CANTIDAD'] as num? ?? 0).toInt();
      }
    }

    // --- ANÁLISIS DE KARDEX (NUEVO: Duración y Frecuencia) ---
    final miKardex = kardexPorProducto[nombre] ?? [];
    double diasEntreIngresos = 0;
    int conteoIngresos = 0;
    DateTime? ultimaFechaIngreso;
    int ultimoLoteCantidad = 0;

    for (var m in miKardex) {
      final tipo = m['TIPO_MOVIMIENTO']?.toString().toLowerCase() ?? '';
      final fechaMov =
          DateTime.tryParse(m['FECHA_MOVIMIENTO']?.toString() ?? '');
      if (fechaMov == null) continue;

      if (tipo == 'ingreso' || tipo == 'registro') {
        if (ultimaFechaIngreso != null) {
          diasEntreIngresos += fechaMov.difference(ultimaFechaIngreso).inDays;
          conteoIngresos++;
        }
        ultimaFechaIngreso = fechaMov;
        ultimoLoteCantidad = (m['CANTIDAD'] as num? ?? 0).toInt();
      }
    }

    final double frecuenciaReposicionDias =
        (conteoIngresos > 0) ? (diasEntreIngresos / conteoIngresos) : 30.0;

    // Calcular cuánto duró el último lote (si ya se acabó o está por acabarse)
    double tasaLoteReciente = 0;
    if (ultimaFechaIngreso != null && stockUtil < (ultimoLoteCantidad * 0.2)) {
      final diasDesdeIngreso =
          hoy.difference(ultimaFechaIngreso).inDays.clamp(1, 999);
      final consumidoLote = (ultimoLoteCantidad - stockUtil).clamp(0, 99999);
      tasaLoteReciente = consumidoLote / diasDesdeIngreso;
    }

    // --- Recolección de variables base ---
    final Map<String, int> stats =
        (ventasTotalesMap[id] as Map<String, dynamic>?)?.cast<String, int>() ??
            {'cajas': 0, 'blisters': 0, 'unidades': 0, 'total': 0};

    final int historicoTotal = stats['total'] ?? 0;

    // Helper interno para pluralización
    String plural(int cant, String sing, String plur) =>
        cant == 1 ? '$cant $sing' : '$cant $plur';

    String formatearLista(int c, int b, int u) {
      List<String> p = [];
      if (c > 0) p.add(plural(c, 'caja', 'cajas'));
      if (b > 0) p.add(plural(b, 'blíster', 'blísters'));
      if (u > 0 || p.isEmpty) p.add(plural(u, 'unidad', 'unidades'));
      return p.join(', ');
    }

    // 1. Venta Detallada
    final String totalVendidoTxt = formatearLista(
      stats['cajas'] ?? 0,
      stats['blisters'] ?? 0,
      stats['unidades'] ?? 0,
    );

    final DateTime fechaCreacion =
        DateTime.tryParse(p['Fecha_Creacion']?.toString() ?? '') ??
            hoy.subtract(const Duration(days: 30));
    final int diasActivos =
        hoy.difference(fechaCreacion).inDays.clamp(1, 99999);

    // --- MEJORA DE INTELIGENCIA (Modelo Predictivo Superior) ---

    // 1. Cálculo de Tasa de Venta Ponderada (W-VPM)
    final int ventas12Semanas = ventasPorSemana.reduce((a, b) => a + b);
    final double ventaMesReciente =
        ventasPorSemana.sublist(0, 4).reduce((a, b) => a + b).toDouble();

    final double tasaDiariaReciente = ventaMesReciente / 28;
    final double tasaDiariaHistorica = historicoTotal / diasActivos;

    // Damos un 50% al mes reciente, 30% a la inercia del último lote (Kardex) y 20% al histórico
    double tasaDiariaPonderada = (tasaDiariaReciente * 0.5) +
        ((tasaLoteReciente > 0 ? tasaLoteReciente : tasaDiariaReciente) * 0.3) +
        (tasaDiariaHistorica * 0.2);

    // Si el producto es muy nuevo (< 30 días), confiamos más en lo histórico o evitar sesgos
    if (diasActivos < 30) {
      tasaDiariaPonderada =
          (tasaDiariaReciente * 0.4) + (tasaDiariaHistorica * 0.6);
    }

    // CRÍTICO: Si no hubo ventas en 12 semanas y no es un producto nuevo (< 30 días),
    // asumimos que el producto está descontinuado o no tiene demanda.
    if (ventas12Semanas == 0 && diasActivos > 30) {
      tasaDiariaPonderada = 0;
    }

    // Estabilizar tasa mínima para evitar errores matemáticos, pero permitir 0 si no hay actividad
    if (tasaDiariaPonderada < 0.0001) tasaDiariaPonderada = 0;
    tasaDiariaPonderada = tasaDiariaPonderada.clamp(0.0, 9999.0);

    // 2. Análisis de Volatilidad (Desviación Estándar para Stock de Seguridad)
    final double promedioSemanal = ventasPorSemana.reduce((a, b) => a + b) / 12;
    double sumaDiferencias = 0;
    for (var v in ventasPorSemana) {
      sumaDiferencias += (v - promedioSemanal) * (v - promedioSemanal);
    }
    final double varianza = sumaDiferencias / 12;
    final double desviacionEstandar = math.sqrt(varianza);

    // Si la desviación estándar es mayor que el promedio, hay alta volatilidad
    final double factorVolatilidad =
        (desviacionEstandar > promedioSemanal) ? 1.35 : 1.15;

    // 3. Proyección a 30 días con Stock de Seguridad
    // Ajustar demanda basándonos en la frecuencia de reposición detectada
    // Si sueles comprar cada 15 días, el sistema debe asegurar que no te quedes sin stock en ese ciclo
    final double cicloDias =
        (frecuenciaReposicionDias > 30) ? 30 : frecuenciaReposicionDias;
    final double demandaMes = tasaDiariaPonderada * 30;
    final double stockSeguridad =
        tasaDiariaPonderada * (cicloDias / 2) * factorVolatilidad;

    // 4. Compra Sugerida (Lo que falta para cubrir demanda + seguridad)
    int compraSugerida = (demandaMes + stockSeguridad - stockUtil).ceil();
    if (compraSugerida < 0) compraSugerida = 0;

    // Desglose de compra sugerida en cajas/unidades
    final int cantPorCaja = (p['Cantidad_Presentacion'] as num? ?? 1).toInt();

    String compraSugeridaTxt = "";
    if (compraSugerida > 0) {
      if (cantPorCaja > 1) {
        int cj = compraSugerida ~/ cantPorCaja;
        int un = compraSugerida % cantPorCaja;
        List<String> p = [];
        if (cj > 0) p.add(plural(cj, 'caja', 'cajas'));
        if (un > 0) p.add(plural(un, 'unidad', 'unidades'));
        compraSugeridaTxt = p.join(' y ');
      } else {
        compraSugeridaTxt = plural(compraSugerida, 'unidad', 'unidades');
      }
    } else {
      compraSugeridaTxt = "0 unidades";
    }

    // Desglose de stock actual en cajas/unidades
    String stockUtilTxt = "";
    if (stockUtil > 0) {
      if (cantPorCaja > 1) {
        int scj = stockUtil ~/ cantPorCaja;
        int sun = stockUtil % cantPorCaja;
        List<String> sp = [];
        if (scj > 0) sp.add(plural(scj, 'caja', 'cajas'));
        if (sun > 0) sp.add(plural(sun, 'unidad', 'unidades'));
        stockUtilTxt = sp.isNotEmpty ? sp.join(' y ') : "0 unidades";
      } else {
        stockUtilTxt = plural(stockUtil, 'unidad', 'unidades');
      }
    } else {
      stockUtilTxt = "0 unidades";
    }

    // 5. Estado de Salud del Inventario (Categorización Inteligente)
    String recomendacion;
    final double diasRestantes =
        (tasaDiariaPonderada > 0) ? (stockUtil / tasaDiariaPonderada) : 999;

    if (stockUtil <= 0) {
      if (ventas12Semanas == 0 && diasActivos > 30) {
        recomendacion = "SIN MOVIMIENTO";
      } else {
        recomendacion = "SIN STOCK";
      }
    } else if (tasaDiariaPonderada == 0 && stockUtil > 0) {
      recomendacion = "SIN MOVIMIENTO";
    } else if (diasRestantes < 7) {
      recomendacion = "URGENTE";
    } else if (diasRestantes < 15) {
      recomendacion = "POR AGOTARSE";
    } else if (diasRestantes < 30) {
      recomendacion = "REPOSICIÓN PREVENTIVA";
    } else if (diasRestantes > 90 && stockUtil > 20) {
      recomendacion = "SOBRESTOCK";
    } else {
      recomendacion = "ESTABLE";
    }

    // Tendencia refinada
    String tendencia = 'ESTABLE';
    if (tasaDiariaReciente > tasaDiariaHistorica * 1.5 &&
        ventaMesReciente > 5) {
      tendencia = 'EN AUMENTO';
    } else if (tasaDiariaReciente < tasaDiariaHistorica * 0.5 &&
        historicoTotal > 10) {
      tendencia = 'EN DESCENSO';
    }

    // Margen
    final double precioUnidad = (p['Precio_Unidad'] as num? ?? 0.0).toDouble();
    final double costoUnidad = (p['Costo_Unidad'] as num? ?? 0.0).toDouble();

    double costoRealAprox = costoUnidad;
    // Si no hay costo unitario, intentamos deducirlo del costo por caja
    if (costoRealAprox <= 0.0) {
      final double costoCaja = (p['Costo_Caja'] as num? ?? 0.0).toDouble();
      final int cantPres = (p['Cantidad_Presentacion'] as num? ?? 1).toInt();
      if (costoCaja > 0 && cantPres > 0) {
        costoRealAprox = costoCaja / cantPres;
      } else {
        // Fallback: si no hay ningún costo en la BD, asumimos un costo del 70% del precio (30% margen)
        final double precioCaja = (p['Precio_Caja'] as num? ?? 0.0).toDouble();
        costoRealAprox = (precioCaja / (cantPres > 0 ? cantPres : 1)) * 0.7;
      }
    }

    final double margenGanancia =
        (precioUnidad - costoRealAprox).clamp(0.0, 99999.0);
    double margenPorcentaje = 0.0;
    if (precioUnidad > 0) {
      margenPorcentaje = (margenGanancia / precioUnidad) * 100;
    }

    res.add({
      ...p,
      'ID': id,
      'id': id,
      'nombre': p['Nombre_Producto'] ?? 'Sin nombre',
      'stockUtil': stockUtil,
      'stockUtilTxt': stockUtilTxt,
      'totalVendidas': historicoTotal,
      'totalVendidoTxt': totalVendidoTxt,
      'tendencia': tendencia,
      'recomendacion': recomendacion,
      'diasRestantes':
          diasRestantes > 365 ? "+365" : diasRestantes.toStringAsFixed(0),
      'rotacion': (historicoTotal / (stockTotal + 1)).toStringAsFixed(2),
      'diasActivos': diasActivos,
      'ventasUltimaSemana': ventasUltimaSemana,
      'margenGanancia': margenGanancia.toStringAsFixed(2),
      'margenPorcentaje': margenPorcentaje.toStringAsFixed(1),
      'compraMensualSugerida': compraSugerida,
      'compraSugeridaTxt': compraSugeridaTxt,
      'costoReal': costoRealAprox,
      'gananciaBrutaTotal': margenGanancia * historicoTotal,
      'inversionSugerida': compraSugerida * costoRealAprox,
      'capitalInmovilizado': stockUtil * costoRealAprox,
      'esTopVenta': historicoTotal > 0 &&
          (historicoTotal >= 20 || ventasUltimaSemana >= 5),
    });
  }

  // Ordenar por relevancia
  res.sort((a, b) {
    int getPrioridad(String r) {
      if (r == 'URGENTE') return 0;
      if (r == 'SIN STOCK') return 1;
      if (r == 'POR AGOTARSE') return 2;
      if (r == 'REPOSICIÓN PREVENTIVA') return 3;
      if (r == 'ESTABLE') return 4;
      return 5;
    }

    int pA = getPrioridad(a['recomendacion']);
    int pB = getPrioridad(b['recomendacion']);

    if (pA != pB) return pA.compareTo(pB);
    return (b['totalVendidas'] as int).compareTo(a['totalVendidas'] as int);
  });

  return res;
}
