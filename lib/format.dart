/// 1234567 -> "1.234.567", the Colombian way.
String formatNumber(num value) =>
    value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');

String _scaled(double value) {
  final text = value >= 10 ? formatNumber(value) : value.toStringAsFixed(1).replaceFirst('.', ',');
  return text.endsWith(',0') ? text.substring(0, text.length - 2) : text;
}

/// Colombian pesos the way people say them: "$4,3 billones", "$491 mil millones", "$13 millones".
/// In Spanish a "billón" is a million millions (1e12), not the English billion.
String formatCop(double value) {
  if (value >= 1e12) return '\$${_scaled(value / 1e12)} billones';
  if (value >= 1e9) return '\$${_scaled(value / 1e9)} mil millones';
  if (value >= 1e6) return '\$${_scaled(value / 1e6)} millones';
  return '\$${formatNumber(value)}';
}
