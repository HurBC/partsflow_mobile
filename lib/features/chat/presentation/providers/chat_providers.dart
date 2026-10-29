import 'dart:async';

import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:partsflow_mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.g.dart';

const chatPageSize = 50;

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) =>
    ChatRepositoryImpl(ChatRemoteDataSource(ref.watch(dioProvider)));

String failureMessage(Failure f) => switch (f) {
  NetworkFailure() => 'Sin conexión. Revisa tu internet.',
  _ => 'No pudimos cargar los datos. Intenta de nuevo.',
};

/// ¿Aplica la ventana de 24 h? Solo si el tenant usa la API oficial de
/// WhatsApp. Si la consulta falla, no se aplica.
@Riverpod(keepAlive: true)
Future<bool> windowApplies(Ref ref) async {
  final me = await ref.watch(currentUserProvider.future);
  if (me == null || me.subsidiaryId.isEmpty) return false;
  final r = await ref
      .read(chatRepositoryProvider)
      .usesWhatsappApi(me.subsidiaryId);
  return switch (r) {
    Ok(:final value) => value,
    Err() => false,
  };
}

enum ListStatus { loading, data, error }

class ChatListState {
  const ChatListState({
    this.tab = ChatTab.pending,
    this.searchText = '',
    this.searchMode = SearchMode.all,
    this.filters = const ChatFilters(),
    this.items = const [],
    this.hasMore = false,
    this.cursor,
    this.cursorId,
    this.pagesLoaded = 0,
    this.status = ListStatus.loading,
    this.loadingMore = false,
    this.error,
  });

  final ChatTab tab;
  final String searchText;
  final SearchMode searchMode;
  final ChatFilters filters;
  final List<Chat> items;
  final bool hasMore;
  final String? cursor;
  final String? cursorId;
  final int pagesLoaded;
  final ListStatus status;
  final bool loadingMore;
  final String? error;

  List<Chat> get visible =>
      filters.isActive ? items.where(filters.matches).toList() : items;

  ChatListState copyWith({
    ChatTab? tab,
    String? searchText,
    SearchMode? searchMode,
    ChatFilters? filters,
    List<Chat>? items,
    bool? hasMore,
    String? cursor,
    String? cursorId,
    bool clearCursor = false,
    int? pagesLoaded,
    ListStatus? status,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) => ChatListState(
    tab: tab ?? this.tab,
    searchText: searchText ?? this.searchText,
    searchMode: searchMode ?? this.searchMode,
    filters: filters ?? this.filters,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    cursorId: clearCursor ? null : (cursorId ?? this.cursorId),
    pagesLoaded: pagesLoaded ?? this.pagesLoaded,
    status: status ?? this.status,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : (error ?? this.error),
  );
}

@Riverpod(keepAlive: true)
class ChatListController extends _$ChatListController {
  int _seq = 0;
  Timer? _rtTimer;

  @override
  ChatListState build() {
    // Al cambiar la sesión se descarta todo y se vuelve a cargar.
    ref.watch(authStateProvider);
    // Tiempo real: cualquier evento relevante recarga la primera página (se
    // suma al sondeo, no lo reemplaza).
    final sub = ref.read(realtimeProvider.notifier).events.listen((_) {
      if (_rtTimer?.isActive ?? false) return; // como mucho 1 recarga por s
      _rtTimer = Timer(const Duration(seconds: 1), () {
        if (ref.mounted) poll();
      });
    });
    ref.onDispose(() {
      sub.cancel();
      _rtTimer?.cancel();
    });
    Future.microtask(() {
      if (ref.mounted) _loadFirst();
    });
    return const ChatListState();
  }

  Future<String?> _loadFirst({bool skeleton = true, bool merge = false}) async {
    final seq = ++_seq;
    if (skeleton) {
      state = state.copyWith(
        status: ListStatus.loading,
        items: const [],
        hasMore: false,
        clearCursor: true,
        pagesLoaded: 0,
        loadingMore: false,
        clearError: true,
      );
    }
    final s = state;
    String? userId;
    if (s.tab == ChatTab.assigned) {
      userId = (await ref.read(apiUserProvider.future))?.id;
      if (!ref.mounted || seq != _seq) return null;
      if (userId == null) {
        // Sin usuario no se puede filtrar por responsable (mostraría todo).
        ref.invalidate(apiUserProvider);
        state = state.copyWith(
          status: ListStatus.error,
          error: 'No pudimos identificar tu usuario. Intenta de nuevo.',
        );
        return state.error;
      }
    }
    final result = await ref
        .read(chatRepositoryProvider)
        .searchChats(
          ChatQuery(
            tab: s.tab,
            userId: userId,
            searchText: s.searchText,
            searchMode: s.searchMode,
          ),
        );
    if (!ref.mounted || seq != _seq) return null;
    switch (result) {
      case Ok(:final value):
        var items = value.chats;
        var cursor = value.cursor;
        var cursorId = value.cursorId;
        var hasMore = value.hasMore;
        var pages = 1;
        if (merge && state.pagesLoaded > 1) {
          final ids = items.map((c) => c.id).toSet();
          items = [...items, ...state.items.where((c) => !ids.contains(c.id))];
          cursor = state.cursor;
          cursorId = state.cursorId;
          hasMore = state.hasMore;
          pages = state.pagesLoaded;
        }
        state = state.copyWith(
          status: ListStatus.data,
          items: items,
          hasMore: hasMore,
          cursor: cursor,
          cursorId: cursorId,
          clearCursor: cursor == null,
          pagesLoaded: pages,
          loadingMore: false,
          clearError: true,
        );
        return null;
      case Err(:final failure):
        final msg = failureMessage(failure);
        if (skeleton || state.status != ListStatus.data) {
          state = state.copyWith(status: ListStatus.error, error: msg);
        }
        return msg;
    }
  }

  /// Carga inicial / reintento (muestra skeleton).
  Future<void> reload() => _loadFirst();

  /// Pull-to-refresh: reemplaza la lista sin skeleton. Devuelve el error, si hubo.
  Future<String?> refresh() => _loadFirst(skeleton: false);

  /// Sondeo / refresco tras una acción: primera página mezclada con lo ya cargado.
  Future<void> poll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    await _loadFirst(skeleton: false, merge: true);
  }

  void setTab(ChatTab tab) {
    if (tab == state.tab) return;
    state = state.copyWith(tab: tab);
    _loadFirst();
  }

  void setSearch(String text) {
    final t = text.trim();
    if (t == state.searchText) return;
    state = state.copyWith(searchText: t);
    _loadFirst();
  }

  void setMode(SearchMode mode) {
    if (mode == state.searchMode) return;
    state = state.copyWith(searchMode: mode);
    if (state.searchText.isNotEmpty) _loadFirst();
  }

  void setFilters(ChatFilters f) => state = state.copyWith(filters: f);

  Future<void> loadMore() async {
    final s = state;
    if (!s.hasMore || s.loadingMore || s.status != ListStatus.data) return;
    final seq = _seq;
    state = s.copyWith(loadingMore: true);
    String? userId;
    if (s.tab == ChatTab.assigned) {
      userId = (await ref.read(apiUserProvider.future))?.id;
    }
    final result = await ref
        .read(chatRepositoryProvider)
        .searchChats(
          ChatQuery(
            tab: s.tab,
            userId: userId,
            searchText: s.searchText,
            searchMode: s.searchMode,
            cursor: s.cursor,
            cursorId: s.cursorId,
          ),
        );
    if (!ref.mounted || seq != _seq) return;
    switch (result) {
      case Ok(:final value):
        final ids = state.items.map((c) => c.id).toSet();
        state = state.copyWith(
          items: [
            ...state.items,
            ...value.chats.where((c) => !ids.contains(c.id)),
          ],
          // Un cursor repetido sin avance cortaría la paginación.
          hasMore: value.hasMore && value.cursor != s.cursor,
          cursor: value.cursor,
          cursorId: value.cursorId,
          clearCursor: value.cursor == null,
          pagesLoaded: state.pagesLoaded + 1,
          loadingMore: false,
        );
      case Err():
        state = state.copyWith(loadingMore: false);
    }
  }

  /// Actualiza un chat ya cargado (lo usa la conversación al leer / actuar).
  void replaceChat(Chat chat) {
    state = state.copyWith(
      items: [for (final c in state.items) c.id == chat.id ? chat : c],
    );
  }
}
