import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';

enum ChatTab {
  pending('Pendientes'),
  assigned('Asignados'),
  all('Todos'),
  issues('Problemas'),
  resolved('Resueltos'),
  archived('Archivados');

  const ChatTab(this.label);
  final String label;
}

enum SearchMode {
  all('Todo', null),
  client('Cliente', 'client_name:'),
  phone('Teléfono', 'client_phone:'),
  plate('Patente', 'car_plate:'),
  note('Nota', 'client_note:'),
  responsible('Responsable', 'responsible:');

  const SearchMode(this.label, this.prefix);
  final String label;
  final String? prefix;
}

/// Subfiltros locales (hoja "Filtrar chats").
class ChatFilters {
  const ChatFilters({
    this.unread = false,
    this.unanswered = false,
    this.julia = false,
    this.unassigned = false,
  });

  final bool unread;
  final bool unanswered;
  final bool julia;
  final bool unassigned;

  bool get isActive => unread || unanswered || julia || unassigned;

  ChatFilters copyWith({
    bool? unread,
    bool? unanswered,
    bool? julia,
    bool? unassigned,
  }) => ChatFilters(
    unread: unread ?? this.unread,
    unanswered: unanswered ?? this.unanswered,
    julia: julia ?? this.julia,
    unassigned: unassigned ?? this.unassigned,
  );

  bool matches(Chat c) {
    if (unread && !c.hasUnread) return false;
    if (unanswered && !(c.lastMessage?.isInbound ?? false)) return false;
    if (julia && !(c.client?.juliaOn ?? false)) return false;
    if (unassigned && c.client?.responsible != null) return false;
    return true;
  }
}

/// Filtros avanzados que viajan como params de `chat/search/` (C1). Se
/// combinan con AND con cualquier pestaña; las claves vacías se omiten.
class AdvancedFilters {
  const AdvancedFilters({
    this.channel,
    this.tagId,
    this.status,
    this.issueType,
    this.recurrent = false,
    this.important = false,
    this.hasIssues = false,
    this.noOrders = false,
  });

  final String? channel;
  final String? tagId;
  final String? status;
  final String? issueType;
  final bool recurrent;
  final bool important;
  final bool hasIssues;
  final bool noOrders;

  int get count =>
      (channel != null ? 1 : 0) +
      (tagId != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (issueType != null ? 1 : 0) +
      (recurrent ? 1 : 0) +
      (important ? 1 : 0) +
      (hasIssues ? 1 : 0) +
      (noOrders ? 1 : 0);

  bool get isActive => count > 0;

  /// Params de la API; omite lo que no aplica (nunca null ni false).
  Map<String, String> toParams() => {
    'lead_generation_channel': ?channel,
    'client_tag': ?tagId,
    'client_status': ?status,
    'issue_type': ?issueType,
    if (recurrent) 'is_recurrent': 'true',
    if (important) 'is_important': 'true',
    if (hasIssues) 'has_issues': 'true',
    if (noOrders) 'no_orders': 'true',
  };

  /// Pasar `null` en un campo de texto NO lo limpia; usar [clearChannel] etc.
  AdvancedFilters copyWith({
    String? channel,
    bool clearChannel = false,
    String? tagId,
    bool clearTag = false,
    String? status,
    bool clearStatus = false,
    String? issueType,
    bool clearIssue = false,
    bool? recurrent,
    bool? important,
    bool? hasIssues,
    bool? noOrders,
  }) => AdvancedFilters(
    channel: clearChannel ? null : (channel ?? this.channel),
    tagId: clearTag ? null : (tagId ?? this.tagId),
    status: clearStatus ? null : (status ?? this.status),
    issueType: clearIssue ? null : (issueType ?? this.issueType),
    recurrent: recurrent ?? this.recurrent,
    important: important ?? this.important,
    hasIssues: hasIssues ?? this.hasIssues,
    noOrders: noOrders ?? this.noOrders,
  );

  @override
  bool operator ==(Object other) =>
      other is AdvancedFilters &&
      other.channel == channel &&
      other.tagId == tagId &&
      other.status == status &&
      other.issueType == issueType &&
      other.recurrent == recurrent &&
      other.important == important &&
      other.hasIssues == hasIssues &&
      other.noOrders == noOrders;

  @override
  int get hashCode => Object.hash(
    channel,
    tagId,
    status,
    issueType,
    recurrent,
    important,
    hasIssues,
    noOrders,
  );
}

/// Canales de captación (valor del servidor, texto).
const leadChannels = <(String, String)>[
  ('web', 'Web'),
  ('facebook_campaign', 'Facebook'),
  ('instagram_campaign', 'Instagram'),
];

/// Textos de `Client.Choices.status` del BO (messages/es/clients/client.json).
const clientStatusLabels = <String, String>{
  'pending_quote': 'Por cotizar',
  'quoting': 'Cotizando',
  'quoted': 'Seguimiento',
  'accepted': 'Aceptado',
  'waiting_importation': 'En Importación',
  'waiting_payment': 'Esperando pago',
  'to_invoice': 'Por Facturar',
  'to_pickup': 'Por retirar',
  'to_ship': 'Por despachar',
  'shipped': 'Despachado',
  'issues': 'Problemas',
  'return': 'Devolucion',
};

String clientStatusLabel(String v) => clientStatusLabels[v] ?? v;

String leadChannelLabel(String v) {
  for (final (k, l) in leadChannels) {
    if (k == v) return l;
  }
  return v;
}

class ChatQuery {
  const ChatQuery({
    required this.tab,
    this.advanced = const AdvancedFilters(),
    this.userId,
    this.searchText = '',
    this.searchMode = SearchMode.all,
    this.cursor,
    this.cursorId,
  });

  final ChatTab tab;
  final AdvancedFilters advanced;
  final String? userId;
  final String searchText;
  final SearchMode searchMode;
  final String? cursor;
  final String? cursorId;
}

class ChatPage {
  const ChatPage({
    required this.chats,
    required this.hasMore,
    this.cursor,
    this.cursorId,
  });

  final List<Chat> chats;
  final bool hasMore;
  final String? cursor;
  final String? cursorId;
}
