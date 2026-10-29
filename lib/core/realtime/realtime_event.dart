import 'dart:convert';

import 'package:partsflow_mobile/core/utils/json_utils.dart';

/// Eventos del WebSocket ya decodificados. Los ítems quedan crudos (mapas):
/// su forma interna no está garantizada, cada consumidor los lee con tolerancia.
sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// Mensajes nuevos (entrantes o salientes) de cualquier chat del subsidiary.
class RealtimeNewMessages extends RealtimeEvent {
  const RealtimeNewMessages(this.items);
  final List<Map<String, dynamic>> items;
}

/// Cambios de estado (ticks) de mensajes.
class RealtimeStatusUpdates extends RealtimeEvent {
  const RealtimeStatusUpdates(this.items);
  final List<Map<String, dynamic>> items;
}

/// `client_updated` | `client_tags_updated` | `client_issues_updated` |
/// `client_general_attributes_updated`.
class RealtimeClientChanged extends RealtimeEvent {
  const RealtimeClientChanged(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

/// Un socket se (re)conectó: puede haberse perdido eventos, hay que recargar.
class RealtimeResync extends RealtimeEvent {
  const RealtimeResync();
}

/// Decodifica un frame de texto; null si no es un evento conocido.
RealtimeEvent? parseRealtimeFrame(Object? raw) {
  try {
    if (raw is! String) return null;
    final m = asMap(jsonDecode(raw));
    if (m == null) return null;
    final type = asStr(m['type']);
    switch (type) {
      case 'chat_list_new_message':
        return RealtimeNewMessages(_items(m['new_messages_data']));
      case 'chat_list_message_status_update':
        return RealtimeStatusUpdates(_items(m['message_status_update_data']));
      case 'client_updated':
      case 'client_tags_updated':
      case 'client_issues_updated':
      case 'client_general_attributes_updated':
        return RealtimeClientChanged(
          type!,
          asMap(m['client_data']) ?? const {},
        );
    }
  } catch (_) {}
  return null;
}

List<Map<String, dynamic>> _items(Object? v) => [
  for (final e in asList(v)) ?asMap(e),
];

/// Solo dígitos del teléfono ("56912345678@c.us", "+56 9..." → "56912345678").
String phoneDigits(String? raw) =>
    (raw ?? '').split('@').first.replaceAll(RegExp(r'\D'), '');

/// Teléfono del ítem de un evento: `phone`, `chat.id`/`chat`, `chat_id`,
/// `from`, `to`. null si no se puede determinar.
String? phoneOfItem(Map<String, dynamic> item) {
  for (final key in const [
    'phone',
    'chat',
    'chat_id',
    'chatId',
    'from',
    'to',
  ]) {
    final v = item[key];
    final s = v is Map ? asStr(v['id']) : asStr(v);
    final d = phoneDigits(s);
    if (d.isNotEmpty) return d;
  }
  return null;
}
