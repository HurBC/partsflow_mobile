import 'package:partsflow_mobile/core/utils/pf_log.dart';

/// Latencia de un ítem realtime según `timing` que agrega WaliApi
/// (`received_at` puede ser null, `published_at` en epoch ms).
///
/// CAVEAT: el reloj del teléfono puede estar desfasado respecto del servidor
/// (cientos de ms). Los valores negativos se reportan tal cual: indican desfase.
class RtLatency {
  const RtLatency({
    required this.type,
    required this.pubToClientMs,
    this.waliToClientMs,
  });
  final String type;
  final int pubToClientMs;
  final int? waliToClientMs;
}

/// Calcula la latencia de [item] respecto de [nowMs]; null si no trae
/// `timing.published_at` numérico. Pura: sin logging ni reloj.
RtLatency? rtLatencyOf(Object? item, int nowMs) {
  if (item is! Map) return null;
  final timing = item['timing'];
  if (timing is! Map) return null;
  final pub = timing['published_at'];
  if (pub is! num || !pub.isFinite) return null;
  final rec = timing['received_at'];
  final t = item['type'];
  return RtLatency(
    type: t is String && t.isNotEmpty ? t : '-',
    pubToClientMs: nowMs - pub.toInt(),
    waliToClientMs: rec is num && rec.isFinite ? nowMs - rec.toInt() : null,
  );
}

/// Emite una línea `rt-lat` por ítem (sin ids, teléfonos ni texto).
void logRtLatency(String event, List<Map<String, dynamic>> items, int nowMs) {
  if (!pfDebugLog) return;
  for (final i in items) {
    final l = rtLatencyOf(i, nowMs);
    if (l == null) continue;
    pfLog(
      'rt-lat $event type=${l.type} pub_to_client_ms=${l.pubToClientMs} '
      'wali_to_client_ms=${l.waliToClientMs ?? '-'}',
    );
  }
}
