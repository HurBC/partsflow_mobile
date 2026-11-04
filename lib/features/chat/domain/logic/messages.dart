import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';

/// Orden de avance de los estados de entrega; los no listados (edited,
/// removed, error…) no participan del orden y siempre se aplican.
const _statusRank = {
  'temp': 0,
  'pending': 0,
  'sent': 1,
  'delivered': 2,
  'read': 3,
};

/// true si pasar de [from] a [to] retrocedería el estado de entrega.
bool _regresses(String? from, String to) {
  final f = _statusRank[from];
  final t = _statusRank[to];
  return f != null && t != null && t < f;
}

/// Une dos listas de mensajes por id (los de [b] pisan a los de [a]) y ordena
/// por fecha ascendente. Un mensaje de [b] con el mismo `messageId` que uno de
/// [a] (p. ej. el parche realtime y el historial con id real) reemplaza a ese,
/// para no duplicar. Dos mensajes con `messageId` distinto nunca son el mismo.
/// Al reemplazar no se retrocede el estado de entrega.
List<Message> mergeMessages(List<Message> a, List<Message> b) {
  final byId = {for (final m in a) m.id: m};
  final idByMessageId = <String, String>{
    for (final m in a)
      if (m.messageId != null) m.messageId!: m.id,
  };
  for (final m in b) {
    final mid = m.messageId;
    final other = mid == null ? null : idByMessageId[mid];
    var old = byId[m.id];
    if (other != null && other != m.id) old = byId.remove(other);
    if (old != null &&
        old.messageId != null &&
        mid != null &&
        old.messageId != mid) {
      old = null;
    }
    var next = m;
    if (old != null && m.status != null && _regresses(old.status, m.status!)) {
      next = m.copyWith(status: old.status);
    }
    // Mismo mensaje (por message_id) con otro id (p. ej. parcheado desde el
    // evento y luego traído por el historial): conservar el id existente para
    // que keys y animaciones de entrada del hilo no se recreen.
    if (old != null && old.id != next.id) next = next.copyWith(id: old.id);
    byId[next.id] = next;
    if (mid != null) idByMessageId[mid] = next.id;
  }
  final out = byId.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  return out;
}

/// Aplica actualizaciones de estado (`items`: mapas con `message_id`,
/// `websocket_id` o `id` y `status`) a [messages]. Casa por `message_id`
/// (único que comparten evento e historial), `websocket_id` e `id`. No
/// retrocede el estado de entrega (read -> delivered). Devuelve null si no
/// hubo cambios.
List<Message>? applyStatusUpdates(
  List<Message> messages,
  List<Map<String, dynamic>> items,
) {
  final byKey = <String, String>{};
  for (final i in items) {
    final st = nonEmpty(asStr(i['status']));
    if (st == null) continue;
    for (final k in [i['message_id'], i['websocket_id'], i['id']]) {
      final key = nonEmpty(asStr(k));
      if (key != null) byKey[key] = st;
    }
  }
  if (byKey.isEmpty) return null;
  var changed = false;
  final next = [
    for (final m in messages)
      if ((byKey[m.messageId] ?? byKey[m.websocketId] ?? byKey[m.id])
          case final st? when st != m.status && !_regresses(m.status, st))
        () {
          changed = true;
          return m.copyWith(status: st);
        }()
      else
        m,
  ];
  return changed ? next : null;
}

/// Aplica mensajes entrantes (evento realtime) sobre [current] sin
/// reordenar la lista. Dedupe por `messageId`, luego `id`, luego `websocketId`:
/// un evento repetido no duplica. Si el mensaje ya existe solo se avanza su
/// estado (sin retroceder); el contenido del existente se conserva. Los nuevos
/// se insertan por fecha buscando desde el final (lo habitual es al final).
/// Devuelve null si nada cambió.
List<Message>? applyNewMessages(List<Message> current, List<Message> incoming) {
  if (incoming.isEmpty) return null;
  final byMessageId = <String, int>{};
  final byId = <String, int>{};
  final byWs = <String, int>{};
  void index(Message m, int i) {
    if (m.messageId != null) byMessageId[m.messageId!] = i;
    byId[m.id] = i;
    if (m.websocketId != null) byWs[m.websocketId!] = i;
  }

  final out = [...current];
  for (var i = 0; i < out.length; i++) {
    index(out[i], i);
  }
  var changed = false;
  for (final m in incoming) {
    int? at;
    if (m.messageId != null) at = byMessageId[m.messageId];
    if (at == null) {
      // Fallback por id/websocket solo si no son mensajes distintos (ambos
      // con messageId y diferentes).
      bool compatible(int? i) =>
          i != null &&
          (m.messageId == null ||
              out[i].messageId == null ||
              out[i].messageId == m.messageId);
      final byIdx = byId[m.id];
      final byWsIdx = m.websocketId == null ? null : byWs[m.websocketId];
      at = compatible(byIdx) ? byIdx : (compatible(byWsIdx) ? byWsIdx : null);
    }
    if (at != null) {
      final old = out[at];
      final st = m.status;
      if (st != null && st != old.status && !_regresses(old.status, st)) {
        out[at] = old.copyWith(status: st);
        changed = true;
      }
      continue;
    }
    var pos = out.length;
    while (pos > 0 && out[pos - 1].date.isAfter(m.date)) {
      pos--;
    }
    out.insert(pos, m);
    changed = true;
    // Los índices posteriores se desplazan: se reconstruyen (insertar en medio
    // es raro y la lista es corta).
    if (pos != out.length - 1) {
      byMessageId.clear();
      byId.clear();
      byWs.clear();
      for (var j = 0; j < out.length; j++) {
        index(out[j], j);
      }
    } else {
      index(m, pos);
    }
  }
  return changed ? out : null;
}

/// Aplica documentos completos actualizados (evento `chat_list_message_update`,
/// p. ej. media pendiente ya lista) como upsert por `messageId`, luego `id`,
/// luego `websocketId`. Si existe se reemplaza su contenido conservando el
/// `id` (keys/animaciones) y sin retroceder el estado de entrega; si no existe
/// (el update llegó antes que el mensaje nuevo) se inserta por fecha.
/// Devuelve null si nada cambió.
List<Message>? applyMessageUpdates(
  List<Message> current,
  List<Message> incoming,
) {
  if (incoming.isEmpty) return null;
  final out = [...current];
  var changed = false;
  for (final m in incoming) {
    var at = -1;
    if (m.messageId != null) {
      at = out.indexWhere((e) => e.messageId == m.messageId);
    }
    if (at < 0) {
      bool compatible(Message e) =>
          m.messageId == null ||
          e.messageId == null ||
          e.messageId == m.messageId;
      at = out.indexWhere(
        (e) =>
            compatible(e) &&
            (e.id == m.id ||
                (m.websocketId != null && e.websocketId == m.websocketId)),
      );
    }
    if (at < 0) {
      var pos = out.length;
      while (pos > 0 && out[pos - 1].date.isAfter(m.date)) {
        pos--;
      }
      out.insert(pos, m);
      changed = true;
      continue;
    }
    final old = out[at];
    var next = m;
    if (m.status != null && _regresses(old.status, m.status!)) {
      next = next.copyWith(status: old.status);
    }
    if (next.id != old.id) next = next.copyWith(id: old.id);
    if (next != old) {
      out[at] = next;
      changed = true;
    }
  }
  return changed ? out : null;
}
