import 'dart:convert';

/// Decodifica el payload de un JWT (sin verificar la firma: solo lectura de claims).
/// Devuelve un mapa vacío si el token es inválido.
Map<String, dynamic> decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return const {};
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } catch (_) {
    return const {};
  }
}
