import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';

/// Filtra [items] en el dispositivo: subfiltros (si están activos) y umbral de
/// Pendientes (oculta chats con actividad dentro de [pendingThreshold] minutos).
List<Chat> visibleChats({
  required List<Chat> items,
  required ChatFilters filters,
  required bool thresholdApplies,
  required int pendingThreshold,
  required DateTime now,
}) {
  final limit = Duration(minutes: pendingThreshold);
  return items.where((c) {
    if (filters.isActive && !filters.matches(c)) return false;
    if (thresholdApplies) {
      final at = c.activityAt;
      if (at != null && now.difference(at) <= limit) return false;
    }
    return true;
  }).toList();
}

// ---------------------------------------------------------------------------
// Parche local de la lista con eventos realtime (Fase 3, paso 3.4).
//
// Identificación evento -> chat: por id crudo (`normalized_chat_id`,
// `chat_id`, `chat.id`) contra Chat.id, o por teléfono (solo dígitos, ver
// phoneOfItem) contra Chat.phone; en client_updated también por client.id.
// Orden de la lista: el del servidor (última actividad descendente); un chat
// que recibe un mensaje más nuevo que su último conocido sube al tope.
// ---------------------------------------------------------------------------

/// Resultado de aplicar eventos: [items] es null si nada cambió; [needsReload]
/// indica que el evento no se pudo resolver localmente (hay que recargar).
class ChatListPatch {
  const ChatListPatch(this.items, {this.needsReload = false});
  static const none = ChatListPatch(null);

  final List<Chat>? items;
  final bool needsReload;
}

/// Índice del chat al que pertenece el ítem del evento, o -1.
int indexOfChat(
  List<Chat> items,
  Map<String, dynamic> item, {
  bool matchClientId = false,
}) {
  final ids = <String>{};
  for (final k in const ['normalized_chat_id', 'chat_id', 'chatId', 'chat']) {
    final v = item[k];
    final s = v is Map ? v['id']?.toString() : v?.toString();
    if (s != null && s.isNotEmpty) ids.add(s);
  }
  final phone = phoneOfItem(item);
  final clientId = matchClientId ? item['id']?.toString() : null;
  for (var i = 0; i < items.length; i++) {
    final c = items[i];
    if (ids.contains(c.id)) return i;
    if (clientId != null && clientId.isNotEmpty && c.client?.id == clientId) {
      return i;
    }
    if (phone != null && phone == phoneDigits(c.phone)) return i;
  }
  return -1;
}

Chat _withLast(
  Chat c, {
  ChatLastMessage? lastMessage,
  DateTime? lastMessageAt,
  DateTime? lastInboundMessageAt,
  int? unreadCount,
  ChatClient? client,
}) => Chat(
  id: c.id,
  phone: c.phone,
  name: c.name,
  contactName: c.contactName,
  imageUrl: c.imageUrl,
  lastMessageAt: lastMessageAt ?? c.lastMessageAt,
  lastInboundMessageAt: lastInboundMessageAt ?? c.lastInboundMessageAt,
  lastMessage: lastMessage ?? c.lastMessage,
  referenceMessage: c.referenceMessage,
  unreadCount: unreadCount ?? c.unreadCount,
  isUnread: c.isUnread,
  client: client ?? c.client,
  hasPendingReminder: c.hasPendingReminder,
);

/// Aplica los mensajes nuevos de un evento. [parse] convierte el ítem crudo en
/// Message (null si no es visible/parseable -> recarga por seguridad).
///
/// Dispara [ChatListPatch.needsReload] si: el chat no está cargado; el ítem no
/// se puede parsear; hay búsqueda de texto o filtros avanzados activos
/// (dependen de campos del servidor); en Pendientes llega un saliente (puede
/// sacarlo) o un entrante a un chat que no era pendiente; en Resueltos/
/// Archivados llega un entrante (el backend puede reactivarlo). En
/// Asignados/Todos/Problemas la pertenencia no depende del flujo: sin recarga.
ChatListPatch applyNewMessages(
  List<Chat> items,
  List<Map<String, dynamic>> raws, {
  required Message? Function(Map<String, dynamic>) parse,
  required bool Function(String chatId) isOpen,
  required ChatTab tab,
  bool advancedActive = false,
  bool searchActive = false,
}) {
  var cur = items;
  var changed = false;
  var reload = false;
  for (final raw in raws) {
    final msg = parse(raw);
    if (msg == null) {
      reload = true;
      continue;
    }
    final idx = indexOfChat(cur, raw);
    if (idx < 0) {
      reload = true;
      continue;
    }
    final c = cur[idx];
    final last = c.lastMessage;
    final sameId =
        (msg.messageId != null && msg.messageId == last?.messageId) ||
        (msg.websocketId != null && msg.websocketId == last?.websocketId);
    if (sameId) continue;
    final lastDate = last?.date ?? c.lastMessageAt;
    if (lastDate != null && !msg.date.isAfter(lastDate)) continue;

    final inbound = msg.flow == 'inbound';
    if (searchActive || advancedActive) reload = true;
    switch (tab) {
      case ChatTab.pending:
        // Un saliente puede sacarlo; un entrante puede meterlo si no estaba
        // ya pendiente (último mensaje no entrante).
        if (!inbound || !(last?.isInbound ?? false)) reload = true;
      case ChatTab.resolved || ChatTab.archived:
        // Un entrante puede reactivar el chat en el backend.
        if (inbound) reload = true;
      case ChatTab.assigned || ChatTab.all || ChatTab.issues:
        // La pertenencia no depende de si hay respuesta pendiente.
        break;
    }
    final next = _withLast(
      c,
      lastMessage: ChatLastMessage(
        flow: msg.flow,
        ack: msg.status,
        type: msg.type,
        body: msg.text,
        date: msg.date,
        messageId: msg.messageId,
        websocketId: msg.websocketId,
      ),
      lastMessageAt: msg.date,
      lastInboundMessageAt: inbound ? msg.date : null,
      unreadCount: inbound && !isOpen(c.id) ? c.unreadCount + 1 : null,
    );
    cur = [next, ...cur.take(idx), ...cur.skip(idx + 1)];
    changed = true;
  }
  return ChatListPatch(changed ? cur : null, needsReload: reload);
}

const _ackRank = {'pending': 0, 'sent': 1, 'delivered': 2, 'read': 3};

/// Actualiza el estado (ticks) del último mensaje de los chats afectados.
/// Nunca pide recarga; si no coincide con ningún último mensaje, null.
List<Chat>? applyStatusToChats(
  List<Chat> items,
  List<Map<String, dynamic>> updates,
) {
  var cur = items;
  var changed = false;
  for (final u in updates) {
    final status = u['status']?.toString();
    final mid = u['message_id']?.toString();
    final wid = u['websocket_id']?.toString();
    if (status == null || status.isEmpty) continue;
    if ((mid == null || mid.isEmpty) && (wid == null || wid.isEmpty)) continue;
    for (var i = 0; i < cur.length; i++) {
      final c = cur[i];
      final last = c.lastMessage;
      if (last == null) continue;
      final match =
          (mid != null && mid.isNotEmpty && last.messageId == mid) ||
          (wid != null && wid.isNotEmpty && last.websocketId == wid);
      if (!match || last.ack == status) continue;
      final from = _ackRank[last.ack];
      final to = _ackRank[status];
      if (from != null && to != null && to < from) continue;
      if (cur == items) cur = [...items];
      cur[i] = _withLast(
        c,
        lastMessage: ChatLastMessage(
          flow: last.flow,
          ack: status,
          type: last.type,
          body: last.body,
          date: last.date,
          messageId: last.messageId,
          websocketId: last.websocketId,
        ),
      );
      changed = true;
      break;
    }
  }
  return changed ? cur : null;
}

/// Parche de `client_updated` (y similares). Para tipos distintos de
/// `client_updated` (tags, issues, atributos) el evento no trae los datos que
/// muestra el tile -> recarga si el chat está cargado.
///
/// Dispara needsReload si cambia la pertenencia a la pestaña activa: resuelto
/// (todas las pestañas), activo (Pendientes/Archivados), responsable
/// (Asignados), o hay filtros avanzados / búsqueda activos y cambió estado,
/// responsable o importancia. Los subfiltros locales se reevalúan solos
/// (visibleChats) y no recargan. `updated_at` no se guarda en Chat: se aplica
/// sin guarda.
ChatListPatch applyClientChange(
  List<Chat> items,
  String type,
  Map<String, dynamic> d, {
  required ChatTab tab,
  bool advancedActive = false,
  bool searchActive = false,
}) {
  final idx = indexOfChat(items, d, matchClientId: true);
  if (idx < 0) return ChatListPatch.none;
  if (type != 'client_updated') {
    return const ChatListPatch(null, needsReload: true);
  }
  final c = items[idx];
  final cl = c.client;
  if (cl == null) return const ChatListPatch(null, needsReload: true);

  bool? b(String k) {
    final v = d[k];
    return v is bool
        ? v
        : (v is String
              ? (v == 'true' ? true : (v == 'false' ? false : null))
              : null);
  }

  final mode =
      d['operation_mode'] is String &&
          (d['operation_mode'] as String).isNotEmpty
      ? d['operation_mode'] as String
      : null;
  final resolved = b('is_chat_resolved');
  final active = b('is_active');
  final ai = b('is_ai_active');
  final status = d['status'] is String && (d['status'] as String).isNotEmpty
      ? d['status'] as String
      : null;

  ChatResponsible? resp = cl.responsible;
  var respSet = false;
  final rMap = d['responsible'];
  if (rMap is Map && rMap['id'] != null) {
    resp = ChatResponsible(
      id: rMap['id'].toString(),
      firstName: rMap['first_name']?.toString() ?? '',
      lastName: rMap['last_name']?.toString() ?? '',
    );
    respSet = true;
  } else if (d.containsKey('responsible_id')) {
    respSet = true;
    resp = d['responsible_id'] == null
        ? null
        : ChatResponsible(
            id: d['responsible_id'].toString(),
            firstName: d['responsible_first_name']?.toString() ?? '',
            lastName: d['responsible_last_name']?.toString() ?? '',
          );
  } else if (d.containsKey('responsible') && d['responsible'] == null) {
    respSet = true;
    resp = null;
  }

  final respChanged = respSet && resp?.id != cl.responsible?.id;
  final resolvedChanged = resolved != null && resolved != cl.isChatResolved;
  final activeChanged = active != null && active != cl.isActive;
  final modeChanged = mode != null && mode != cl.operationMode;
  final statusChanged = status != null && status != cl.status;
  final aiChanged = ai != null && ai != cl.isAiActive;
  final nameChanged =
      respSet &&
      resp != null &&
      cl.responsible != null &&
      resp.id == cl.responsible!.id &&
      resp.fullName != cl.responsible!.fullName &&
      resp.fullName.isNotEmpty;
  final importance = d.containsKey('importance_level');

  var reload =
      resolvedChanged ||
      (activeChanged && (tab == ChatTab.pending || tab == ChatTab.archived)) ||
      (respChanged && tab == ChatTab.assigned);
  if ((advancedActive || searchActive) &&
      (respChanged || statusChanged || resolvedChanged || activeChanged)) {
    reload = true;
  }
  if (advancedActive && importance) reload = true;

  if (!(respChanged ||
      resolvedChanged ||
      activeChanged ||
      modeChanged ||
      statusChanged ||
      aiChanged ||
      nameChanged)) {
    return ChatListPatch(null, needsReload: reload);
  }
  final newClient = ChatClient(
    id: cl.id,
    name: cl.name,
    isActive: active ?? cl.isActive,
    isChatResolved: resolved ?? cl.isChatResolved,
    operationMode: mode ?? cl.operationMode,
    // Si cambia el modo y el evento no trae is_ai_active, el valor anterior
    // quedaría viejo: juliaOn cae al modo.
    isAiActive: ai ?? (modeChanged ? null : cl.isAiActive),
    isImportant: cl.isImportant,
    status: status ?? cl.status,
    responsible: respSet ? resp : cl.responsible,
    issuesCount: cl.issuesCount,
    tags: cl.tags,
  );
  final next = [...items];
  next[idx] = _withLast(c, client: newClient);
  return ChatListPatch(next, needsReload: reload);
}

/// Actualiza el último mensaje (preview) de los chats cuyo último mensaje es
/// el documento actualizado de un `chat_list_message_update`. Nunca pide
/// recarga; si no coincide con ningún último mensaje, null.
List<Chat>? applyUpdatesToChats(
  List<Chat> items,
  List<Map<String, dynamic>> updates, {
  required Message? Function(Object?) parse,
}) {
  var cur = items;
  var changed = false;
  for (final u in updates) {
    final mid = u['message_id']?.toString();
    final wid = u['websocket_id']?.toString();
    final hasMid = mid != null && mid.isNotEmpty;
    final hasWid = wid != null && wid.isNotEmpty;
    if (!hasMid && !hasWid) continue;
    final m = parse(u);
    if (m == null) continue;
    for (var i = 0; i < cur.length; i++) {
      final c = cur[i];
      final last = c.lastMessage;
      if (last == null) continue;
      final match =
          (hasMid && last.messageId == mid) ||
          (hasWid && last.websocketId == wid);
      if (!match) continue;
      final status = m.status;
      final from = _ackRank[last.ack];
      final to = status == null ? null : _ackRank[status];
      final keepAck = to != null && from != null && to < from;
      final next = ChatLastMessage(
        flow: m.flow ?? last.flow,
        ack: (status == null || keepAck) ? last.ack : status,
        type: m.type,
        body: m.text ?? last.body,
        date: last.date,
        messageId: last.messageId ?? m.messageId,
        websocketId: last.websocketId ?? m.websocketId,
      );
      if (next == last) break;
      if (cur == items) cur = [...items];
      cur[i] = _withLast(c, lastMessage: next);
      changed = true;
      break;
    }
  }
  return changed ? cur : null;
}

/// ¿El chat, ya modificado por una acción local, dejó de pertenecer a [tab]?
/// Pendientes/Todos/Problemas excluyen resueltos y archivados; Asignados exige
/// ser del usuario [userId]; Resueltos exige estar resuelto y Archivados,
/// inactivo. No evalúa lo que depende del servidor (pendiente, problemas).
bool chatLeavesTab(ChatTab tab, Chat c, {String? userId}) {
  final cl = c.client;
  final resolved = cl?.isChatResolved ?? false;
  final active = cl?.isActive ?? true;
  return switch (tab) {
    ChatTab.pending || ChatTab.all || ChatTab.issues => resolved || !active,
    ChatTab.assigned =>
      resolved || userId == null || cl?.responsible?.id != userId,
    ChatTab.resolved => !resolved,
    ChatTab.archived => active,
  };
}
