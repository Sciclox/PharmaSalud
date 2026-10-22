import 'package:intl/intl.dart';

/// Formatea un número como moneda con separadores de miles.
/// Ejemplo: formatMoney(1000200.5) => "1,000,200.50"
String formatMoney(dynamic value) {
  final double v = (value is double)
      ? value
      : (value is int)
          ? value.toDouble()
          : (double.tryParse(value.toString()) ?? 0.0);
  return NumberFormat('#,##0.00', 'en_US').format(v);
}

String formatDias(int dias) {
  final absDias = dias.abs();
  final texto = absDias == 1 ? 'día' : 'días';
  return '$dias $texto';
}

String formatAgotamiento(dynamic dias) {
  if (dias == null) return '—';
  final int d = (dias is int) ? dias : (int.tryParse(dias.toString()) ?? 0);

  if (d <= 0) return 'Agotado';

  if (d < 30) {
    return '$d ${d == 1 ? 'día' : 'días'}';
  } else if (d < 365) {
    final double meses = d / 30.0;
    if (meses % 1 == 0) {
      return '${meses.toInt()} ${meses.toInt() == 1 ? 'mes' : 'meses'}';
    }
    return '${meses.toStringAsFixed(1)} meses';
  } else {
    final double anos = d / 365.0;
    if (anos % 1 == 0) {
      return '${anos.toInt()} ${anos.toInt() == 1 ? 'año' : 'años'}';
    }
    return '${anos.toStringAsFixed(1)} años';
  }
}
