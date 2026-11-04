import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';

/// Une dos listas de mensajes por id (los de [b] pisan a los de [a]) y ordena
/// por fecha ascendente.
List<Message> mergeMessages(List<Message> a, List<Message> b) {
  final byId = {for (final m in a) m.id: m};
  for (final m in b) {
    byId[m.id] = m;
  }
  final out = byId.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  return out;
}

/// Aplica actualizaciones de estado (`items`: mapas con `websocket_id`|`id` y
/// `status`) a [messages]. Devuelve null si no hubo cambios.
List<Message>? applyStatusUpdates(
  List<Message> messages,
  List<Map<String, dynamic>> items,
) {
  final byId = <String, String>{};
  for (final i in items) {
    final id = nonEmpty(asStr(i['websocket_id'])) ?? nonEmpty(asStr(i['id']));
    final st = nonEmpty(asStr(i['status']));
    if (id != null && st != null) byId[id] = st;
  }
  if (byId.isEmpty) return null;
  var changed = false;
  final next = [
    for (final m in messages)
      if ((byId[m.websocketId] ?? byId[m.id]) case final st?
          when st != m.status)
        () {
          changed = true;
          return m.copyWith(status: st);
        }()
      else
        m,
  ];
  return changed ? next : null;
}
