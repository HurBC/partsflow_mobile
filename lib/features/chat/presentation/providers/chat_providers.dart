import 'dart:async';

import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/config/perf_flags.dart';
import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/utils/reload_gate.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/chats.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/open_chat_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_providers.g.dart';

const chatPageSize = 50;

/// Umbral local de Pendientes (minutos sin actividad): rango y valor por defecto.
const pendingThresholdMin = 1;
const pendingThresholdMax = 20;
const pendingThresholdDefault = 5;

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
    this.advanced = const AdvancedFilters(),
    this.pendingThreshold = pendingThresholdDefault,
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
  final AdvancedFilters advanced;
  final int pendingThreshold;
  final List<Chat> items;
  final bool hasMore;
  final String? cursor;
  final String? cursorId;
  final int pagesLoaded;
  final ListStatus status;
  final bool loadingMore;
  final String? error;

  /// Búsqueda "Todo" con texto: la lista normal se reemplaza por las secciones
  /// Clientes y Mensajes (ver [ChatSearchController]).
  bool get isGlobalSearch =>
      searchText.isNotEmpty && searchMode == SearchMode.all;

  /// Filtros que se aplican en el dispositivo (subfiltros + umbral de Pendientes).
  bool get thresholdApplies => tab == ChatTab.pending && searchText.isEmpty;

  /// ¿Algo se oculta en el dispositivo? (subfiltros o umbral de Pendientes)
  bool get hidesLocally => filters.isActive || thresholdApplies;

  /// Nº de filtros activos para el botón: locales + avanzados + modo de búsqueda.
  int get activeFilterCount =>
      (filters.unread ? 1 : 0) +
      (filters.unanswered ? 1 : 0) +
      (filters.julia ? 1 : 0) +
      (filters.unassigned ? 1 : 0) +
      advanced.count +
      (searchMode != SearchMode.all ? 1 : 0);

  List<Chat> get visible => visibleChats(
    items: items,
    filters: filters,
    thresholdApplies: thresholdApplies,
    pendingThreshold: pendingThreshold,
    now: DateTime.now(),
  );

  ChatListState copyWith({
    ChatTab? tab,
    String? searchText,
    SearchMode? searchMode,
    ChatFilters? filters,
    AdvancedFilters? advanced,
    int? pendingThreshold,
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
    advanced: advanced ?? this.advanced,
    pendingThreshold: pendingThreshold ?? this.pendingThreshold,
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
  late ReloadGate _gate;
  // Eventos recibidos con una carga de primera página en vuelo, con el _seq de
  // esa carga: al aplicarse su respuesta (que pudo empezar antes del evento)
  // se re-aplican sobre los items nuevos. Las funciones puras son idempotentes.
  final _inFlightEvents = <({int seq, RealtimeEvent event})>[];
  bool _signalPending = false;

  @override
  ChatListState build() {
    // Un gate por build: Riverpod reutiliza esta instancia al reconstruir y el
    // gate anterior queda dispuesto.
    final gate = _gate = ReloadGate(
      // Con parche local la señal solo llega cuando no se pudo resolver
      // localmente: se agrupa más.
      signalGap: Duration(seconds: pfPatchList ? 3 : 1),
    );
    _signalPending = false;
    // Al cambiar la sesión se descarta todo y se vuelve a cargar.
    ref.watch(sessionActiveProvider);
    // Tiempo real: Resync -> auto (cooldown); cualquier otro evento trae datos
    // nuevos -> signal (coalesce, nunca se pierde; sustituye al throttle de
    // 1 s porque la señal ya agrupa por vuelo y cooldown).
    final sub = ref.read(realtimeProvider.notifier).events.listen((e) {
      if (!ref.mounted) return;
      if (e is RealtimeResync) {
        autoPoll();
      } else if (pfPatchList) {
        if (_patchFromEvent(e)) _signalPoll();
      } else {
        _signalPoll();
      }
    });
    ref.onDispose(() {
      sub.cancel();
      gate.dispose();
    });
    Future.microtask(() {
      if (ref.mounted) _loadFirst();
    });
    _loadThreshold();
    return const ChatListState();
  }

  Future<void> _loadThreshold() async {
    final storage = await ref.read(localStorageProvider.future);
    final v = await storage.getInt(StorageKeys.pendingThresholdMin);
    if (!ref.mounted || v == null) return;
    state = state.copyWith(
      pendingThreshold: v.clamp(pendingThresholdMin, pendingThresholdMax),
    );
  }

  Future<void> setPendingThreshold(int minutes) async {
    final v = minutes.clamp(pendingThresholdMin, pendingThresholdMax);
    if (v == state.pendingThreshold) return;
    state = state.copyWith(pendingThreshold: v);
    final storage = await ref.read(localStorageProvider.future);
    await storage.setInt(StorageKeys.pendingThresholdMin, v);
  }

  /// Cambia los filtros avanzados (se mandan a la API) y recarga si cambiaron.
  void setAdvanced(AdvancedFilters a) {
    if (a == state.advanced) return;
    state = state.copyWith(advanced: a);
    _loadFirst();
  }

  Future<String?> _loadFirst({bool skeleton = true, bool merge = false}) =>
      _gate.track(() => _doLoadFirst(skeleton: skeleton, merge: merge));

  Future<String?> _doLoadFirst({
    bool skeleton = true,
    bool merge = false,
  }) async {
    final seq = ++_seq;
    _inFlightEvents.removeWhere((x) => x.seq < seq);
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
    final search = ref.read(chatSearchControllerProvider.notifier);
    if (s.isGlobalSearch) {
      state = state.copyWith(
        status: ListStatus.data,
        items: const [],
        hasMore: false,
        clearCursor: true,
        pagesLoaded: 0,
        loadingMore: false,
        clearError: true,
      );
      await search.run(
        text: s.searchText,
        tab: s.tab,
        advanced: s.advanced,
        userId: userId,
      );
      return null;
    }
    search.clear();
    final result = await ref
        .read(chatRepositoryProvider)
        .searchChats(
          ChatQuery(
            tab: s.tab,
            advanced: s.advanced,
            userId: userId,
            searchText: s.searchText,
            searchMode: s.searchMode,
          ),
        );
    if (!ref.mounted || seq != _seq) return null;
    final buffered = [
      for (final x in _inFlightEvents)
        if (x.seq == seq) x.event,
    ];
    _inFlightEvents.removeWhere((x) => x.seq <= seq);
    switch (result) {
      case Ok(:final value):
        _gate.markSuccess();
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
        for (final e in buffered) {
          items = _patchItems(e, items, state).items ?? items;
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
  /// Explícito (tras una acción del usuario): sin cooldown.
  Future<void> poll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    // Los resultados de búsqueda no se sondean.
    if (state.isGlobalSearch) return;
    await _loadFirst(skeleton: false, merge: true);
  }

  /// Automático (Resync, tick del poller, volver a primer plano): se omite si
  /// hay una carga reciente y reutiliza la que está en vuelo.
  Future<void> autoPoll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    if (state.isGlobalSearch) return;
    await _gate.auto(() => _doLoadFirst(skeleton: false, merge: true));
  }

  /// Aplica el evento a la lista cargada. Devuelve true si hay que recargar
  /// (no se pudo resolver localmente).
  bool _patchFromEvent(RealtimeEvent e) {
    final s = state;
    // Sin datos o con búsqueda global no hay lista que parchear; la carga en
    // curso (o la salida de la búsqueda) ya trae datos frescos.
    if (s.status != ListStatus.data || s.isGlobalSearch) return false;
    // Si hay una carga de primera página en vuelo pudo empezar antes del
    // evento: se guarda para re-aplicarlo sobre su respuesta.
    if (_gate.inFlight) {
      _inFlightEvents.add((seq: _seq, event: e));
    }
    final p = _patchItems(e, s.items, s);
    if (p.items != null) state = s.copyWith(items: p.items);
    return p.needsReload;
  }

  ChatListPatch _patchItems(RealtimeEvent e, List<Chat> items, ChatListState s) {
    final searchActive = s.searchText.isNotEmpty;
    final advanced = s.advanced.isActive;
    switch (e) {
      case RealtimeNewMessages(items: final raws):
        return applyNewMessages(
          items,
          raws,
          parse: messageFromJson,
          isOpen: ref.read(openChatRegistryProvider).isOpen,
          tab: s.tab,
          advancedActive: advanced,
          searchActive: searchActive,
        );
      case RealtimeStatusUpdates(items: final updates):
        return ChatListPatch(applyStatusToChats(items, updates));
      case RealtimeClientChanged(:final type, :final data):
        return applyClientChange(
          items,
          type,
          data,
          tab: s.tab,
          advancedActive: advanced,
          searchActive: searchActive,
        );
      case RealtimeResync():
        return ChatListPatch.none;
    }
  }

  /// Señal de datos nuevos (evento realtime): nunca se pierde, se coalesce.
  void _signalPoll() {
    _gate.signal(() async {
      if (!ref.mounted) return;
      // loadMore en curso: se recarga al terminar (ver loadMore).
      if (state.loadingMore) {
        _signalPending = true;
        return;
      }
      // Búsqueda global: salir de ella (setSearch/setTab/setMode) ya dispara
      // una carga explícita, así que no hace falta pendiente. Estado no-data:
      // la carga inicial/reintento en curso trae datos frescos.
      if (state.status != ListStatus.data || state.isGlobalSearch) return;
      await _doLoadFirst(skeleton: false, merge: true);
    });
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
            advanced: s.advanced,
            userId: userId,
            searchText: s.searchText,
            searchMode: s.searchMode,
            cursor: s.cursor,
            cursorId: s.cursorId,
          ),
        );
    if (!ref.mounted) return;
    if (seq != _seq) {
      // Una carga de primera página reemplazó la lista: ya trae lo nuevo.
      _signalPending = false;
      return;
    }
    if (_signalPending) {
      _signalPending = false;
      // Tras terminar loadMore (más abajo) hay que recargar la señal perdida.
      scheduleMicrotask(() {
        if (ref.mounted) _signalPoll();
      });
    }
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
