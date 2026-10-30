import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

// Parseo tolerante: los objetos vienen crudos de Wali, todo es opcional y los
// tipos pueden variar (número/string). Nunca lanza por un campo raro.

ChatLastMessage? _lastMessage(Object? json) {
  final m = asMap(json);
  if (m == null) return null;
  return ChatLastMessage(
    flow: asStr(m['flow']),
    ack: asStr(m['ack']),
    type: asStr(m['type']),
    body: asStr(m['body']),
    date: asDate(m['date']),
  );
}

ChatReference? _reference(Object? json) {
  final m = asMap(json);
  if (m == null) return null;
  return ChatReference(
    id: asStr(m['id']),
    text: nonEmpty(asStr(m['message'])) ?? nonEmpty(asStr(m['body'])),
    date: asDate(m['date']),
    flow: asStr(m['flow']),
  );
}

ChatClient? _client(Object? json) {
  final m = asMap(json);
  if (m == null) return null;
  ChatResponsible? responsible;
  final r = asMap(m['responsible']);
  if (r != null && r['id'] != null) {
    responsible = ChatResponsible(
      id: asStr(r['id']) ?? '',
      firstName: asStr(r['first_name']) ?? '',
      lastName: asStr(r['last_name']) ?? '',
    );
  }
  final tags = <ChatTag>[];
  for (final t in asList(m['tags'])) {
    final tm = asMap(t);
    final name = nonEmpty(asStr(tm?['name']));
    if (name != null) tags.add(ChatTag(name: name, color: asStr(tm?['color'])));
  }
  return ChatClient(
    id: asStr(m['id']),
    name: asStr(m['name']),
    isActive: asBool(m['is_active']) ?? true,
    isChatResolved: asBool(m['is_chat_resolved']) ?? false,
    operationMode: asStr(m['operation_mode']),
    isAiActive: asBool(m['is_ai_active']),
    isImportant: asBool(m['is_important']) ?? false,
    status: asStr(m['status']),
    responsible: responsible,
    issuesCount: asList(m['issues']).length,
    tags: tags,
  );
}

/// null si el objeto no trae `id` (se descarta, no rompe la lista).
Chat? chatFromJson(Object? json) {
  try {
    final m = asMap(json);
    if (m == null) return null;
    final id = nonEmpty(asStr(m['id']));
    if (id == null) return null;
    final meta = asMap(m['meta']);
    final contact = asMap(m['contact']);
    final image = asMap(contact?['image']);
    return Chat(
      id: id,
      phone: id.split('@').first.replaceAll('+', ''),
      name: asStr(m['name']),
      contactName: asStr(contact?['displayName']),
      imageUrl: asStr(image?['url']),
      lastMessageAt: asDate(m['lastMessageAt']),
      lastInboundMessageAt: asDate(m['lastInboundMessageAt']),
      lastMessage: _lastMessage(m['lastMessage']),
      referenceMessage: _reference(m['referenceMessage']),
      unreadCount: asInt(meta?['unreadCount']) ?? 0,
      isUnread: asBool(meta?['isUnread']) ?? false,
      client: _client(m['client']),
      hasPendingReminder:
          asBool(asMap(m['client'])?['has_pending_reminder']) ??
          asBool(m['has_pending_reminder']) ??
          false,
    );
  } catch (_) {
    return null;
  }
}

Message? messageFromJson(Object? json) {
  try {
    final m = asMap(json);
    if (m == null) return null;
    final type = asStr(m['type']) ?? 'text';
    final source = asStr(m['source']);
    if (type == 'action') return null;
    if (type == 'unknown' && (source == 'system' || source == 'mobile')) {
      return null;
    }
    final date = asDate(m['date']);
    if (date == null) return null;

    String? mediaUrl;
    String? filename;
    String? caption;
    String? mediaId;
    String? mediaMime;
    final media = m['media'];
    if (media is String) {
      mediaUrl = nonEmpty(media);
    } else {
      final mm = asMap(media);
      mediaUrl = nonEmpty(asStr(mm?['url']));
      filename = nonEmpty(asStr(mm?['filename']));
      caption = nonEmpty(asStr(mm?['caption']));
      mediaId = nonEmpty(asStr(mm?['id']));
      mediaMime = nonEmpty(asStr(mm?['mime']));
    }
    final text = nonEmpty(asStr(m['message'])) ?? caption;

    final quoted = asMap(m['quoted']);
    final loc = asMap(m['location']);
    final locLabel = loc == null
        ? null
        : (nonEmpty(asStr(loc['location_name'])) ??
              nonEmpty(asStr(loc['address'])));
    final contacts = <String>[];
    final cards = <ContactCard>[];
    for (final c in asList(m['contacts'])) {
      final cm = asMap(c);
      final n = nonEmpty(asStr(cm?['name']));
      if (n == null) continue;
      contacts.add(n);
      final phones = <String>[];
      final rawPhones = cm?['phones'];
      for (final p in rawPhones is List ? rawPhones : [rawPhones]) {
        final pm = asMap(p);
        final v = nonEmpty(
          asStr(pm == null ? p : (pm['phone'] ?? pm['wa_id'] ?? pm['number'])),
        );
        if (v != null) phones.add(v);
      }
      cards.add(ContactCard(name: n, phones: phones));
    }

    final id =
        nonEmpty(asStr(m['id'])) ?? '${date.microsecondsSinceEpoch}-$type';
    return Message(
      id: id,
      messageId: nonEmpty(asStr(m['message_id'])),
      date: date,
      type: type,
      flow: asStr(m['flow']),
      text: text,
      status: asStr(m['status']),
      reference: asStr(m['reference']),
      senderName: nonEmpty(asStr(m['sender_name'])),
      agent: nonEmpty(asStr(m['agent'])),
      responsibleId: asStr(m['responsible_id']),
      source: source,
      mediaUrl: mediaUrl,
      mediaFilename: filename,
      quotedBody: nonEmpty(asStr(quoted?['body'])),
      quotedFrom: nonEmpty(asStr(quoted?['fromName'])),
      quotedWid: nonEmpty(asStr(quoted?['wid'])),
      quotedType: nonEmpty(asStr(quoted?['type'])),
      locationLabel: locLabel,
      latitude: asDouble(loc?['latitude']),
      longitude: asDouble(loc?['longitude']),
      contactNames: contacts,
      contacts: cards,
      mediaId: mediaId,
      mediaMime: mediaMime,
      websocketId: nonEmpty(asStr(m['websocket_id'])),
      errorCode: asInt(m['error_code']),
      isEdited:
          (asBool(m['is_edited']) ?? false) || asStr(m['status']) == 'edited',
    );
  } catch (_) {
    return null;
  }
}

/// Acepta lista, `{results: []}` o un mapa de columnas con listas.
OrderStrip? orderStripFromJson(Object? json) {
  Map<String, dynamic>? first;
  Object? firstOf(Object? v) {
    final list = v is List
        ? v
        : (asMap(v)?['results'] is List ? asMap(v)!['results'] as List : null);
    if (list != null) return list.isEmpty ? null : list.first;
    final map = asMap(v);
    if (map == null) return null;
    for (final value in map.values) {
      if (value is List && value.isNotEmpty) return value.first;
      final inner = asMap(value);
      if (inner != null && inner['results'] is List) {
        final l = inner['results'] as List;
        if (l.isNotEmpty) return l.first;
      }
    }
    return null;
  }

  first = asMap(firstOf(json));
  if (first == null) return null;
  final id = nonEmpty(asStr(first['id'])) ?? nonEmpty(asStr(first['order_id']));
  if (id == null) return null;
  // to_quote = los 5 estados de Por cotizar; devolution_requested = Devolución.
  final stage =
      OrderStage.fromStatus(asStr(first['status'])) ?? OrderStage.porCotizar;
  return OrderStrip(id: id, stage: stage);
}
