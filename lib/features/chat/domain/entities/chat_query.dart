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
  note('Nota', 'client_note:');

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

class ChatQuery {
  const ChatQuery({
    required this.tab,
    this.userId,
    this.searchText = '',
    this.searchMode = SearchMode.all,
    this.cursor,
    this.cursorId,
  });

  final ChatTab tab;
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
