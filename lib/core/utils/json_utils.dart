// Parseo tolerante de JSON crudo: nunca lanza por un campo raro.

Map<String, dynamic>? asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

List<Object?> asList(Object? v) => v is List ? v : const [];

String? asStr(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s;
}

int? asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

bool? asBool(Object? v) {
  if (v is bool) return v;
  if (v is String) {
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  if (v is num) return v != 0;
  return null;
}

DateTime? asDate(Object? v) {
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is num) {
    final n = v.toInt();
    // Segundos vs milisegundos.
    return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n);
  }
  return null;
}

String? nonEmpty(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

double? asDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '');
}
