import 'dart:async';

import 'package:collection/collection.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/search_text.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_search_provider.g.dart';

/// Mínimos para lanzar cada consulta del modo "Todo".
const searchMinChars = 3;
const searchMinDigits = 4;

enum SectionStatus { idle, loading, data, error }

/// Una sección de resultados (Clientes o Mensajes) con su propio estado.
class SearchSection {
  const SearchSection({
    this.status = SectionStatus.idle,
    this.items = const [],
    this.hint,
    this.hasMore = false,
    this.cursor,
    this.cursorId,
    this.loadingMore = false,
    this.moreFailed = false,
    this.refreshing = false,
  });

  final SectionStatus status;
  final List<Chat> items;

  /// Texto cuando la sección no se consulta (p. ej. faltan caracteres).
  final String? hint;
  final bool hasMore;
  final String? cursor;
  final String? cursorId;
  final bool loadingMore;
  final bool moreFailed;

  /// Hay una búsqueda nueva en vuelo y [items] son los de la anterior.
  final bool refreshing;

  SearchSection copyWith({
    SectionStatus? status,
    List<Chat>? items,
    bool? hasMore,
    String? cursor,
    String? cursorId,
    bool? loadingMore,
    bool? moreFailed,
    bool? refreshing,
  }) => SearchSection(
    status: status ?? this.status,
    items: items ?? this.items,
    hint: hint,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    cursorId: cursorId ?? this.cursorId,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
    refreshing: refreshing ?? this.refreshing,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSection &&
          other.status == status &&
          const DeepCollectionEquality().equals(other.items, items) &&
          other.hint == hint &&
          other.hasMore == hasMore &&
          other.cursor == cursor &&
          other.cursorId == cursorId &&
          other.loadingMore == loadingMore &&
          other.moreFailed == moreFailed &&
          other.refreshing == refreshing;

  @override
  int get hashCode => Object.hashAll([
    status,
    const DeepCollectionEquality().hash(items),
    hint,
    hasMore,
    cursor,
    cursorId,
    loadingMore,
    moreFailed,
    refreshing,
  ]);
}

class ChatSearchState {
  const ChatSearchState({
    this.query = '',
    this.clients = const SearchSection(),
    this.messages = const SearchSection(),
  });

  final String query;
  final SearchSection clients;
  final SearchSection messages;

  ChatSearchState copyWith({SearchSection? clients, SearchSection? messages}) =>
      ChatSearchState(
        query: query,
        clients: clients ?? this.clients,
        messages: messages ?? this.messages,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSearchState &&
          other.query == query &&
          other.clients == clients &&
          other.messages == messages;

  @override
  int get hashCode => Object.hashAll([query, clients, messages]);
}

// ---- Clasificación del texto (puro, sin red) ---------------------------------

/// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
/// por separado. Las búsquedas viejas se descartan (`_seq`).
@Riverpod(keepAlive: true)
class ChatSearchController extends _$ChatSearchController {
  int _seq = 0;
  ChatQuery? _messagesBase;

  /// Cancela todos los requests de la búsqueda vigente (clientes, mensajes y
  /// páginas siguientes).
  CancelSignal _signal = CancelSignal();

  /// Búsqueda en curso: si llega la misma, se reutiliza en vez de relanzarla.
  Object? _activeKey;
  Future<void>? _activeRun;

  @override
  ChatSearchState build() {
    ref.onDispose(() => _signal.cancel());
    return const ChatSearchState();
  }

  void _supersede() {
    _seq++;
    _signal.cancel();
    _signal = CancelSignal();
    _activeKey = null;
    _activeRun = null;
  }

  void clear() {
    _supersede();
    _messagesBase = null;
    if (state.query.isEmpty) return;
    state = const ChatSearchState();
  }

  Future<void> run({
    required String text,
    required ChatTab tab,
    required AdvancedFilters advanced,
    String? userId,
  }) {
    final q = text.trim();
    if (q.isEmpty) {
      clear();
      return Future.value();
    }
    final key = (q, tab, advanced, userId);
    final active = _activeRun;
    if (active != null && _activeKey == key) return active;
    _supersede();
    _activeKey = key;
    final fut = _run(q, tab, advanced, userId, _seq, _signal);
    _activeRun = fut;
    fut.whenComplete(() {
      if (identical(_activeRun, fut)) {
        _activeKey = null;
        _activeRun = null;
      }
    });
    return fut;
  }

  Future<void> _run(
    String q,
    ChatTab tab,
    AdvancedFilters advanced,
    String? userId,
    int seq,
    CancelSignal signal,
  ) async {
    ChatQuery base(SearchMode mode, String t) => ChatQuery(
      tab: tab,
      advanced: advanced,
      userId: userId,
      searchText: t,
      searchMode: mode,
    );

    final clientQueries = <ChatQuery>[
      if (hasLetters(q)) base(SearchMode.client, q),
      if (onlyDigits(q).length >= searchMinDigits)
        base(SearchMode.phone, onlyDigits(q)),
      if (plateFrom(q) != null) base(SearchMode.plate, plateFrom(q)!),
    ];
    final runMessages = q.length >= searchMinChars;
    _messagesBase = runMessages ? base(SearchMode.all, q) : null;

    pfLog(
      'search todo: q.len=${q.length} clientes=${clientQueries.length} '
      'mensajes=$runMessages',
    );
    // Se conservan los resultados previos mientras carga la nueva búsqueda.
    SearchSection loading(SearchSection prev) =>
        prev.status == SectionStatus.data
        ? SearchSection(
            status: SectionStatus.data,
            items: prev.items,
            refreshing: true,
          )
        : const SearchSection(status: SectionStatus.loading);
    state = ChatSearchState(
      query: q,
      clients: clientQueries.isEmpty
          ? const SearchSection(
              hint:
                  'Escribe un nombre, un teléfono (4 dígitos o más) o una patente.',
            )
          : loading(state.clients),
      messages: runMessages
          ? loading(state.messages)
          : const SearchSection(
              hint:
                  'Escribe al menos 3 caracteres para buscar en los mensajes.',
            ),
    );

    await Future.wait([
      if (clientQueries.isNotEmpty) _runClients(seq, signal, clientQueries),
      if (runMessages) _runMessages(seq, signal, _messagesBase!),
    ]);
  }

  Future<void> _runClients(
    int seq,
    CancelSignal signal,
    List<ChatQuery> queries,
  ) async {
    final repo = ref.read(chatRepositoryProvider);
    final results = await Future.wait(
      queries.map((q) => repo.searchChats(q, cancel: signal)),
    );
    if (!ref.mounted || seq != _seq || signal.isCancelled) return;
    final seen = <String>{};
    final items = <Chat>[];
    var anyOk = false;
    for (final r in results) {
      if (r case Ok(:final value)) {
        anyOk = true;
        for (final c in value.chats) {
          if (seen.add(c.id)) items.add(c);
        }
      }
    }
    state = state.copyWith(
      clients: SearchSection(
        status: anyOk ? SectionStatus.data : SectionStatus.error,
        items: items,
      ),
    );
  }

  Future<void> _runMessages(
    int seq,
    CancelSignal signal,
    ChatQuery query,
  ) async {
    final r = await ref
        .read(chatRepositoryProvider)
        .searchChats(query, cancel: signal);
    if (!ref.mounted || seq != _seq || signal.isCancelled) return;
    switch (r) {
      case Ok(:final value):
        state = state.copyWith(
          messages: SearchSection(
            status: SectionStatus.data,
            items: value.chats,
            hasMore: value.hasMore && value.cursor != null,
            cursor: value.cursor,
            cursorId: value.cursorId,
          ),
        );
      case Err():
        state = state.copyWith(
          messages: const SearchSection(status: SectionStatus.error),
        );
    }
  }

  /// Siguiente página de la sección Mensajes (cursor = referenceMessage).
  Future<void> loadMoreMessages() async {
    final s = state.messages;
    final base = _messagesBase;
    if (base == null ||
        !s.hasMore ||
        s.loadingMore ||
        s.refreshing ||
        s.status != SectionStatus.data) {
      return;
    }
    final seq = _seq;
    final signal = _signal;
    state = state.copyWith(
      messages: s.copyWith(loadingMore: true, moreFailed: false),
    );
    final r = await ref
        .read(chatRepositoryProvider)
        .searchChats(
          ChatQuery(
            tab: base.tab,
            advanced: base.advanced,
            userId: base.userId,
            searchText: base.searchText,
            searchMode: base.searchMode,
            cursor: s.cursor,
            cursorId: s.cursorId,
          ),
          cancel: signal,
        );
    if (!ref.mounted || seq != _seq || signal.isCancelled) return;
    final cur = state.messages;
    switch (r) {
      case Ok(:final value):
        // Un mismo chat puede coincidir con varios mensajes: se muestran todos.
        state = state.copyWith(
          messages: cur.copyWith(
            items: [...cur.items, ...value.chats],
            hasMore: value.hasMore && value.cursor != s.cursor,
            cursor: value.cursor,
            cursorId: value.cursorId,
            loadingMore: false,
          ),
        );
      case Err():
        state = state.copyWith(
          messages: cur.copyWith(loadingMore: false, moreFailed: true),
        );
    }
  }
}
