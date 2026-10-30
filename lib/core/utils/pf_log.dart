import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Registro de diagnóstico (logcat: `adb logcat -s flutter`). Se activa con
/// `--dart-define=PF_DEBUG_LOG=true` y también funciona en release.
/// NUNCA registrar headers, tokens ni datos personales (salvo teléfono
/// enmascarado con [maskPhoneForLog]).
const pfDebugLog = bool.fromEnvironment('PF_DEBUG_LOG');

void pfLog(String message) {
  if (!pfDebugLog) return;
  debugPrint('[pf] $message');
}

String truncateLog(Object? body, {int max = 600}) {
  final s = body?.toString() ?? '';
  return s.length <= max ? s : '${s.substring(0, max)}…(+${s.length - max})';
}

/// Deja solo los últimos 4 dígitos.
String maskPhoneForLog(String? phone) {
  final d = (phone ?? '').split('@').first.replaceAll(RegExp(r'\D'), '');
  if (d.length <= 4) return '*' * d.length;
  return '${'*' * (d.length - 4)}${d.substring(d.length - 4)}';
}

/// Motivo corto y legible de un error HTTP: "HTTP 400: detail" (detail = detail, error, type o message del body).
/// Sin respuesta (timeout, sin red): el tipo de error de dio.
String httpReason(DioException e) {
  final res = e.response;
  if (res == null) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'tiempo de espera agotado',
      DioExceptionType.connectionError => 'sin conexión',
      _ => e.type.name,
    };
  }
  final data = res.data;
  String? detail;
  if (data is Map) {
    for (final k in const ['detail', 'error', 'type', 'message']) {
      final v = data[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        detail = v.toString().trim();
        break;
      }
    }
  } else if (data is String && data.trim().isNotEmpty) {
    detail = data.trim();
  }
  if (detail != null && detail.length > 120) {
    detail = '${detail.substring(0, 120)}…';
  }
  final code = res.statusCode ?? 0;
  return detail == null ? 'HTTP $code' : 'HTTP $code: $detail';
}

/// Texto corto de una excepción cualquiera (para la UI).
String shortError(Object e) {
  if (e is DioException) return httpReason(e);
  var s = e.toString();
  s = s.replaceFirst(
    RegExp(r'^[A-Za-z_]*(Exception|Error)(\([^)]*\))?:?\s*'),
    '',
  );
  s = s.replaceAll('\n', ' ').trim();
  if (s.isEmpty) s = e.runtimeType.toString();
  return s.length > 100 ? '${s.substring(0, 100)}…' : s;
}
