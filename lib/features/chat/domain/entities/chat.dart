import 'package:collection/collection.dart';

class ChatResponsible {
  const ChatResponsible({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatResponsible &&
          other.id == id &&
          other.firstName == firstName &&
          other.lastName == lastName;

  @override
  int get hashCode => Object.hashAll([id, firstName, lastName]);
}

class ChatTag {
  const ChatTag({required this.name, this.color});

  final String name;
  final String? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatTag && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hashAll([name, color]);
}

class ChatLastMessage {
  const ChatLastMessage({
    this.flow,
    this.ack,
    this.type,
    this.body,
    this.date,
    this.messageId,
    this.websocketId,
  });

  /// Ids del mensaje (si el servidor los envía o vienen de un evento realtime):
  /// permiten deduplicar y casar actualizaciones de estado.
  final String? messageId;
  final String? websocketId;

  /// 'inbound' | 'outbound'
  final String? flow;

  /// 'read' | 'delivered' | 'sent' | 'pending'
  final String? ack;
  final String? type;
  final String? body;
  final DateTime? date;

  bool get isInbound => flow == 'inbound';
  bool get isOutbound => flow == 'outbound';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatLastMessage &&
          other.flow == flow &&
          other.ack == ack &&
          other.type == type &&
          other.body == body &&
          other.date == date &&
          other.messageId == messageId &&
          other.websocketId == websocketId;

  @override
  int get hashCode =>
      Object.hashAll([flow, ack, type, body, date, messageId, websocketId]);
}

/// Mensaje que coincidió en una búsqueda de texto libre (`referenceMessage`).
class ChatReference {
  const ChatReference({this.id, this.text, this.date, this.flow});

  final String? id;
  final String? text;
  final DateTime? date;

  /// 'inbound' | 'outbound'
  final String? flow;

  bool get isOutbound => flow == 'outbound';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatReference &&
          other.id == id &&
          other.text == text &&
          other.date == date &&
          other.flow == flow;

  @override
  int get hashCode => Object.hashAll([id, text, date, flow]);
}

class ChatClient {
  const ChatClient({
    this.id,
    this.name,
    this.isActive = true,
    this.isChatResolved = false,
    this.operationMode,
    this.isAiActive,
    this.isImportant = false,
    this.status,
    this.responsible,
    this.issuesCount = 0,
    this.tags = const [],
  });

  final String? id;
  final String? name;
  final bool isActive;
  final bool isChatResolved;

  /// 'manual' | 'automatic'
  final String? operationMode;
  final bool? isAiActive;
  final bool isImportant;
  final String? status;
  final ChatResponsible? responsible;
  final int issuesCount;
  final List<ChatTag> tags;

  bool get juliaOn => isAiActive ?? (operationMode == 'automatic');
  bool get isPendingQuote => status == 'pending_quote';

  ChatClient copyWith({
    String? operationMode,
    bool? isAiActive,
    bool? isActive,
    bool? isChatResolved,
    ChatResponsible? responsible,
    bool clearResponsible = false,
    int? issuesCount,
    List<ChatTag>? tags,
    bool? isImportant,
  }) => ChatClient(
    id: id,
    name: name,
    isActive: isActive ?? this.isActive,
    isChatResolved: isChatResolved ?? this.isChatResolved,
    operationMode: operationMode ?? this.operationMode,
    isAiActive: isAiActive ?? this.isAiActive,
    isImportant: isImportant ?? this.isImportant,
    status: status,
    responsible: clearResponsible ? null : (responsible ?? this.responsible),
    issuesCount: issuesCount ?? this.issuesCount,
    tags: tags ?? this.tags,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatClient &&
          other.id == id &&
          other.name == name &&
          other.isActive == isActive &&
          other.isChatResolved == isChatResolved &&
          other.operationMode == operationMode &&
          other.isAiActive == isAiActive &&
          other.isImportant == isImportant &&
          other.status == status &&
          other.responsible == responsible &&
          other.issuesCount == issuesCount &&
          const DeepCollectionEquality().equals(other.tags, tags);

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    isActive,
    isChatResolved,
    operationMode,
    isAiActive,
    isImportant,
    status,
    responsible,
    issuesCount,
    const DeepCollectionEquality().hash(tags),
  ]);
}

class Chat {
  const Chat({
    required this.id,
    required this.phone,
    this.name,
    this.contactName,
    this.imageUrl,
    this.lastMessageAt,
    this.lastInboundMessageAt,
    this.lastMessage,
    this.referenceMessage,
    this.unreadCount = 0,
    this.isUnread = false,
    this.client,
    this.hasPendingReminder = false,
  });

  /// Id crudo de Wali, p. ej. "56912345678@c.us".
  final String id;

  /// Teléfono sin '@...' ni '+'.
  final String phone;
  final String? name;
  final String? contactName;
  final String? imageUrl;
  final DateTime? lastMessageAt;
  final DateTime? lastInboundMessageAt;
  final ChatLastMessage? lastMessage;

  /// Solo en resultados de búsqueda por texto libre.
  final ChatReference? referenceMessage;
  final int unreadCount;
  final bool isUnread;
  final ChatClient? client;

  /// Recordatorio pendiente (`client.has_pending_reminder ?? has_pending_reminder`).
  final bool hasPendingReminder;

  bool get hasUnread => unreadCount > 0 || isUnread;

  /// Fecha para ordenar/mostrar: lastMessageAt o la del último mensaje.
  DateTime? get activityAt => lastMessageAt ?? lastMessage?.date;

  Chat copyWith({
    ChatClient? client,
    int? unreadCount,
    bool? isUnread,
    bool? hasPendingReminder,
  }) => Chat(
    id: id,
    phone: phone,
    name: name,
    contactName: contactName,
    imageUrl: imageUrl,
    lastMessageAt: lastMessageAt,
    lastInboundMessageAt: lastInboundMessageAt,
    lastMessage: lastMessage,
    referenceMessage: referenceMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    isUnread: isUnread ?? this.isUnread,
    client: client ?? this.client,
    hasPendingReminder: hasPendingReminder ?? this.hasPendingReminder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chat &&
          other.id == id &&
          other.phone == phone &&
          other.name == name &&
          other.contactName == contactName &&
          other.imageUrl == imageUrl &&
          other.lastMessageAt == lastMessageAt &&
          other.lastInboundMessageAt == lastInboundMessageAt &&
          other.lastMessage == lastMessage &&
          other.referenceMessage == referenceMessage &&
          other.unreadCount == unreadCount &&
          other.isUnread == isUnread &&
          other.client == client &&
          other.hasPendingReminder == hasPendingReminder;

  @override
  int get hashCode => Object.hashAll([
    id,
    phone,
    name,
    contactName,
    imageUrl,
    lastMessageAt,
    lastInboundMessageAt,
    lastMessage,
    referenceMessage,
    unreadCount,
    isUnread,
    client,
    hasPendingReminder,
  ]);
}
