bool hasLetters(String q) => RegExp(r'\p{L}', unicode: true).hasMatch(q);

String onlyDigits(String q) => q.replaceAll(RegExp(r'\D'), '');

/// Patente chilena: 4 letras + 2 dígitos o 2 letras + 4 dígitos, con o sin
/// separadores. Devuelve la patente normalizada (mayúsculas, sin separadores)
/// o null.
String? plateFrom(String q) {
  final s = q.replaceAll(RegExp(r'[\s\-·.]'), '').toUpperCase();
  final ok =
      RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(s) ||
      RegExp(r'^[A-Z]{2}\d{4}$').hasMatch(s);
  return ok ? s : null;
}
