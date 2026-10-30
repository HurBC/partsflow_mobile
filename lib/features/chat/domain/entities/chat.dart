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
}

class ChatTag {
  const ChatTag({required this.name, this.color});

  final String name;
  final String? color;
}

class ChatLastMessage {
  const ChatLastMessage({this.flow, this.ack, this.type, this.body, this.date});

  /// 'inbound' | 'outbound'
  final String? flow;

  /// 'read' | 'delivered' | 'sent' | 'pending'
  final String? ack;
  final String? type;
  final String? body;
  final DateTime? date;

  bool get isInbound => flow == 'inbound';
  bool get isOutbound => flow == 'outbound';
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

  // La identidad es el id: permite usar el Chat como clave de provider
  // (la conversación se crea con el primer Chat recibido).
  @override
  bool operator ==(Object other) => other is Chat && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
