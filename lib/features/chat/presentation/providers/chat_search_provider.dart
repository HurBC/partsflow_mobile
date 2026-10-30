import 'dart:async';

import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
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

  SearchSection copyWith({
    SectionStatus? status,
    List<Chat>? items,
    bool? hasMore,
    String? cursor,
    String? cursorId,
    bool? loadingMore,
    bool? moreFailed,
  }) => SearchSection(
    status: status ?? this.status,
    items: items ?? this.items,
    hint: hint,
    hasMore: hasMore ?? this.hasMore,
    cursor: cursor ?? this.cursor,
    cursorId: cursorId ?? this.cursorId,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
  );
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
}

// ---- Clasificación del texto (puro, sin red) ---------------------------------

bool hasLetters(String q) => RegExp(r'\p{L}', unicode: true).hasMatch(q);

String onlyDigits(String q) => q.replaceAll(RegExp(r'\D'), '');

/// Patente chilena: 4 letras + 2 dígitos o 2 letras + 4 dígitos, con o sin
/// separadores. Devuelve la patente normalizada (mayúsculas, sin separadores)
/// o null.
String? plateFrom(String q) {
  final s = q.replaceAll(RegExp(r'[\s\-·.]'), '').toUpperCase();
  final ok =
      RegExp(r'^[A-Z]{4}\d{2}$').hasMatch(s) ||
      RegExp(r'^[A-Z]{2}\d{4}$').hasMatch(s);
  return ok ? s : null;
}

/// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
/// por separado. Las búsquedas viejas se descartan (`_seq`).
@Riverpod(keepAlive: true)
class ChatSearchController extends _$ChatSearchController {
  int _seq = 0;
  ChatQuery? _messagesBase;

  @override
  ChatSearchState build() => const ChatSearchState();

  void clear() {
    _seq++;
    _messagesBase = null;
    if (state.query.isEmpty) return;
    state = const ChatSearchState();
  }

  Future<void> run({
    required String text,
    required ChatTab tab,
    required AdvancedFilters advanced,
    String? userId,
  }) async {
    final q = text.trim();
    final seq = ++_seq;
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
    state = ChatSearchState(
      query: q,
      clients: clientQueries.isEmpty
          ? const SearchSection(
              hint:
                  'Escribe un nombre, un teléfono (4 dígitos o más) o una patente.',
            )
          : const SearchSection(status: SectionStatus.loading),
      messages: runMessages
          ? const SearchSection(status: SectionStatus.loading)
          : const SearchSection(
              hint:
                  'Escribe al menos 3 caracteres para buscar en los mensajes.',
            ),
    );

    await Future.wait([
      if (clientQueries.isNotEmpty) _runClients(seq, clientQueries),
      if (runMessages) _runMessages(seq, _messagesBase!),
    ]);
  }

  Future<void> _runClients(int seq, List<ChatQuery> queries) async {
    final repo = ref.read(chatRepositoryProvider);
    final results = await Future.wait(queries.map(repo.searchChats));
    if (!ref.mounted || seq != _seq) return;
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

  Future<void> _runMessages(int seq, ChatQuery query) async {
    final r = await ref.read(chatRepositoryProvider).searchChats(query);
    if (!ref.mounted || seq != _seq) return;
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
        s.status != SectionStatus.data) {
      return;
    }
    final seq = _seq;
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
        );
    if (!ref.mounted || seq != _seq) return;
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
