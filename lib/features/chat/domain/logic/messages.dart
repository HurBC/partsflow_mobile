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

/// Reconcilia [incoming] con [old] ya conocido: no retrocede el estado de
/// entrega, no pierde la media ya resuelta ante una respuesta vieja con
/// `mediaPending` (recarga lanzada durante la ventana de pendiente) y conserva
/// campos solo locales (`localPath`, progreso de subida) si el entrante no los
/// trae.
Message _reconcile(Message old, Message incoming) {
  var next = incoming;
  final st = incoming.status;
  if (st != null && _regresses(old.status, st)) {
    next = next.copyWith(status: old.status);
  }
  if (old.mediaUrl != null &&
      !old.mediaPending &&
      incoming.mediaPending &&
      incoming.mediaUrl == null) {
    next = next.copyWith(
      mediaUrl: old.mediaUrl,
      mediaFilename: old.mediaFilename ?? incoming.mediaFilename,
      mediaId: old.mediaId ?? incoming.mediaId,
      mediaMime: old.mediaMime ?? incoming.mediaMime,
      mediaPending: false,
    );
  }
  if ((next.localPath == null && old.localPath != null) ||
      (next.uploadProgress == null && old.uploadProgress != null)) {
    next = next.copyWith(
      localPath: next.localPath ?? old.localPath,
      uploadProgress: next.uploadProgress ?? old.uploadProgress,
    );
  }
  return next;
}

/// (µs, seq) de un id local (`local-<µs>-<seq>`), o null si no lo es.
(int, int)? _localOrder(String id) {
  if (!id.startsWith('local-')) return null;
  final parts = id.split('-');
  if (parts.length != 3) return null;
  final us = int.tryParse(parts[1]);
  final seq = int.tryParse(parts[2]);
  return us == null || seq == null ? null : (us, seq);
}

/// Orden del hilo: por fecha y, a igual fecha (el servidor da segundos), los
/// ids de documento del servidor si ambos los tienen, o el orden de envío
/// local de los propios; si no, empatan (el llamador
/// usa un sort estable y conserva el orden previo/de llegada).
int compareMessages(Message a, Message b) {
  final c = a.date.compareTo(b.date);
  if (c != 0) return c;
  // Ambos con id de documento (ObjectId, 24 hex, creciente por inserción; el
  // entrante y el saliente los inserta Wali en la misma colección).
  final sa = a.serverId;
  final sb = b.serverId;
  if (sa != null && sb != null && sa != sb && _isOid(sa) && _isOid(sb)) {
    return sa.compareTo(sb);
  }
  final la = _localOrder(a.id);
  final lb = _localOrder(b.id);
  if (la != null && lb != null) {
    final u = la.$1.compareTo(lb.$1);
    return u != 0 ? u : la.$2.compareTo(lb.$2);
  }
  return 0;
}

final _oid = RegExp(r'^[0-9a-fA-F]{24}$');
bool _isOid(String s) => _oid.hasMatch(s);

/// Sort estable (Dart no lo garantiza) con [compareMessages].
List<Message> sortedMessages(Iterable<Message> messages) {
  final l = messages.toList();
  final idx = [for (var i = 0; i < l.length; i++) i];
  idx.sort((x, y) {
    final c = compareMessages(l[x], l[y]);
    return c != 0 ? c : x.compareTo(y);
  });
  return [for (final i in idx) l[i]];
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
    var next = old == null ? m : _reconcile(old, m);
    // Mismo mensaje (por message_id) con otro id (p. ej. parcheado desde el
    // evento y luego traído por el historial): conservar el id existente para
    // que keys y animaciones de entrada del hilo no se recreen.
    if (old != null && old.id != next.id) next = next.copyWith(id: old.id);
    byId[next.id] = next;
    if (mid != null) idByMessageId[mid] = next.id;
  }
  return sortedMessages(byId.values);
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
    while (pos > 0 && compareMessages(out[pos - 1], m) > 0) {
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

/// Quita de [pending] los mensajes locales que ya tienen su real en
/// [messages] (mismo id: el real enviado con `websocket_id` = id local lo
/// conserva) y le traslada el archivo local si el real no lo trae. Devuelve
/// las listas finales (las mismas instancias si nada cambió) para asignarlas
/// al estado en UNA sola escritura.
({List<Message> messages, List<Message> pending, Set<String> absorbed})
absorbPending(List<Message> messages, List<Message> pending) {
  if (pending.isEmpty) {
    return (messages: messages, pending: pending, absorbed: const {});
  }
  // Por id y por websocket_id (un real que entró sin él y luego lo recibe).
  final index = <String, int>{
    for (var i = 0; i < messages.length; i++) ...{
      messages[i].id: i,
      if (messages[i].websocketId != null) messages[i].websocketId!: i,
    },
  };
  final absorbed = <String>{};
  List<Message>? outMessages;
  final keep = <Message>[];
  for (final p in pending) {
    final at = index[p.id];
    if (at == null) {
      keep.add(p);
      continue;
    }
    absorbed.add(p.id);
    final real = (outMessages ?? messages)[at];
    if (real.localPath == null && p.localPath != null) {
      (outMessages ??= [...messages])[at] = real.copyWith(
        localPath: p.localPath,
      );
    }
  }
  if (keep.length == pending.length) {
    return (messages: messages, pending: pending, absorbed: const {});
  }
  return (messages: outMessages ?? messages, pending: keep, absorbed: absorbed);
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
      while (pos > 0 && compareMessages(out[pos - 1], m) > 0) {
        pos--;
      }
      out.insert(pos, m);
      changed = true;
      continue;
    }
    final old = out[at];
    var next = _reconcile(old, m);
    if (next.id != old.id) next = next.copyWith(id: old.id);
    if (next != old) {
      out[at] = next;
      changed = true;
    }
  }
  return changed ? out : null;
}
