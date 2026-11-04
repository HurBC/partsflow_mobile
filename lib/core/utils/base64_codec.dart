import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

/// Umbral (en caracteres) a partir del cual la decodificación sale del hilo de UI.
const int kBase64IsolateThreshold = 256 * 1024;

/// Limpia (comillas, prefijo data:, espacios) y decodifica base64. Pura.
/// Lanza [FormatException] si el contenido es inválido.
Uint8List decodeBase64Clean(String data) {
  var s = data.trim();
  if (s.startsWith('"')) {
    // Literal JSON (body crudo): jsonDecode resuelve \n, \/, \r\n, etc.
    final decoded = jsonDecode(s);
    if (decoded is! String) {
      throw const FormatException('Se esperaba un literal JSON string');
    }
    s = decoded.trim();
  }
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma >= 0) s = s.substring(comma + 1);
  }
  if (s.contains('\n') ||
      s.contains('\r') ||
      s.contains(' ') ||
      s.contains('\t')) {
    s = s.replaceAll(RegExp(r'\s'), '');
  }
  return base64.decode(base64.normalize(s));
}

/// Decodifica en línea si es pequeño; si no, en un isolate. null si [data]
/// no es String. Propaga [FormatException] como la versión síncrona.
Future<Uint8List?> decodeBase64Async(
  Object? data, {
  int threshold = kBase64IsolateThreshold,
}) async {
  if (data is! String) return null;
  if (_looksLikeJsonContainer(data)) return null;
  if (data.length < threshold) return decodeBase64Clean(data);
  return Isolate.run(() => decodeBase64Clean(data));
}

bool _looksLikeJsonContainer(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09) continue;
    return c == 0x7B || c == 0x5B; // { [
  }
  return false;
}
