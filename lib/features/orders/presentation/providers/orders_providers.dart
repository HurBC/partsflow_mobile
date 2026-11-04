import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/utils/reload_gate.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart'
    show ListStatus, failureMessage;
import 'package:partsflow_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:partsflow_mobile/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_providers.g.dart';

const ordersPageSize = 20;

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) =>
    OrdersRepositoryImpl(OrdersRemoteDataSource(ref.watch(dioProvider)));

/// Reloj inyectable (tests).
final ordersClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Antigüedad mínima de la lista para recargarla al montar la tab.
const ordersMountStale = Duration(seconds: 30);

/// Cada cuánto, como máximo, el poll recalcula los contadores (otros usuarios).
const ordersCountsPollEvery = Duration(minutes: 5);

class OrdersListState {
  const OrdersListState({
    this.stage = OrderStage.porCotizar,
    this.searchText = '',
    this.items = const [],
    this.counts = const {},
    this.hasMore = false,
    this.pagesLoaded = 0,
    this.status = ListStatus.loading,
    this.loadingMore = false,
    this.error,
  });

  final OrderStage stage;
  final String searchText;
  final List<OrderSummary> items;

  /// Clientes por etapa (contador de las pestañas); falta si aún no se sabe.
  final Map<OrderStage, int> counts;
  final bool hasMore;
  final int pagesLoaded;
  final ListStatus status;
  final bool loadingMore;
  final String? error;

  /// Texto no vacío que no sirve para buscar (ni n° de pedido ni teléfono).
  bool get searchInvalid =>
      searchText.isNotEmpty && searchParamFor(searchText) == null;

  OrdersListState copyWith({
    OrderStage? stage,
    String? searchText,
    List<OrderSummary>? items,
    Map<OrderStage, int>? counts,
    bool? hasMore,
    int? pagesLoaded,
    ListStatus? status,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) => OrdersListState(
    stage: stage ?? this.stage,
    searchText: searchText ?? this.searchText,
    items: items ?? this.items,
    counts: counts ?? this.counts,
    hasMore: hasMore ?? this.hasMore,
    pagesLoaded: pagesLoaded ?? this.pagesLoaded,
    status: status ?? this.status,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrdersListState &&
          other.stage == stage &&
          other.searchText == searchText &&
          const DeepCollectionEquality().equals(other.items, items) &&
          const DeepCollectionEquality().equals(other.counts, counts) &&
          other.hasMore == hasMore &&
          other.pagesLoaded == pagesLoaded &&
          other.status == status &&
          other.loadingMore == loadingMore &&
          other.error == error;

  @override
  int get hashCode => Object.hashAll([
    stage,
    searchText,
    const DeepCollectionEquality().hash(items),
    const DeepCollectionEquality().hash(counts),
    hasMore,
    pagesLoaded,
    status,
    loadingMore,
    error,
  ]);
}

@Riverpod(keepAlive: true)
class OrdersListController extends _$OrdersListController {
  int _seq = 0;
  int _countSeq = 0;
  int _partialCountSeq = 0;
  int _removedLocally = 0;
  bool _reloadAfterLoadMore = false;
  late ReloadGate _gate;
  DateTime? _lastListOk;
  DateTime? _lastCountsOk;

  DateTime _now() => ref.read(ordersClockProvider)();

  @override
  OrdersListState build() {
    // Un gate por build (la instancia del Notifier puede reutilizarse).
    final gate = _gate = ReloadGate(now: _now);
    ref.onDispose(gate.dispose);
    // Al cambiar la sesión se descarta todo y se vuelve a cargar.
    ref.watch(sessionActiveProvider);
    Future.microtask(() {
      if (ref.mounted) _loadFirst();
    });
    return const OrdersListState();
  }

  String? get _search => searchParamFor(state.searchText);

  Future<String?> _loadFirst({
    bool skeleton = true,
    bool merge = false,
    bool counts = true,
  }) => _gate.track(
    () => _doLoadFirst(skeleton: skeleton, merge: merge, counts: counts),
  );

  /// [counts]: true = siempre recalcula los de las otras etapas; false = solo
  /// si pasaron [ordersCountsPollEvery] desde el último cálculo.
  Future<String?> _doLoadFirst({
    bool skeleton = true,
    bool merge = false,
    bool counts = false,
  }) async {
    final seq = ++_seq;
    if (skeleton) {
      _removedLocally = 0;
      state = state.copyWith(
        status: ListStatus.loading,
        items: const [],
        hasMore: false,
        pagesLoaded: 0,
        loadingMore: false,
        clearError: true,
      );
    }
    final s = state;
    final result = await ref
        .read(ordersRepositoryProvider)
        .list(
          OrdersQuery(
            stage: s.stage,
            search: searchParamFor(s.searchText),
            limit: ordersPageSize,
          ),
        );
    if (!ref.mounted || seq != _seq) return null;
    switch (result) {
      case Ok(:final value):
        _gate.markSuccess();
        _removedLocally = 0;
        _lastListOk = _now();
        var items = value.items;
        var hasMore = value.hasMore;
        var pages = 1;
        if (merge && state.pagesLoaded > 1) {
          final ids = items.map((o) => o.id).toSet();
          items = [...items, ...state.items.where((o) => !ids.contains(o.id))];
          hasMore = state.hasMore;
          pages = state.pagesLoaded;
        }
        state = state.copyWith(
          status: ListStatus.data,
          items: items,
          hasMore: hasMore,
          pagesLoaded: pages,
          loadingMore: false,
          counts: {...state.counts, s.stage: value.count},
          clearError: true,
        );
        final last = _lastCountsOk;
        if (counts ||
            last == null ||
            _now().difference(last) >= ordersCountsPollEvery) {
          _loadCounts();
        }
        return null;
      case Err(:final failure):
        final msg = failureMessage(failure);
        if (skeleton || state.status != ListStatus.data) {
          state = state.copyWith(status: ListStatus.error, error: msg);
        }
        return msg;
    }
  }

  /// Contadores de las pestañas indicadas (por defecto, las demás; una
  /// consulta liviana por etapa).
  Future<void> _loadCounts([Iterable<OrderStage>? only]) async {
    final seq = only == null ? ++_countSeq : ++_partialCountSeq;
    final current = state.stage;
    final search = _search;
    final repo = ref.read(ordersRepositoryProvider);
    final stages = (only ?? OrderStage.values.where((e) => e != current))
        .toList();
    final results = await Future.wait([
      for (final st in stages) repo.count(st, search),
    ]);
    if (!ref.mounted ||
        seq != (only == null ? _countSeq : _partialCountSeq) ||
        _search != search) {
      return;
    }
    final counts = {...state.counts};
    var i = 0;
    var any = false;
    for (final st in stages) {
      if (results[i] case Ok(:final value)) {
        // La etapa visible la fija la lista.
        if (st != state.stage || only != null) counts[st] = value;
        any = true;
      }
      i++;
    }
    if (any && only == null) _lastCountsOk = _now();
    state = state.copyWith(counts: counts);
  }

  /// Carga inicial / reintento (muestra skeleton).
  Future<void> reload() => _loadFirst();

  /// Pull-to-refresh: reemplaza la lista sin skeleton. Devuelve el error, si hubo.
  Future<String?> refresh() => _loadFirst(skeleton: false);

  /// Refresco tras una acción del usuario: sin cooldown ni contadores.
  Future<void> poll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    await _loadFirst(skeleton: false, merge: true, counts: false);
  }

  /// Automático (tick del poller, volver a primer plano): se omite si hay una
  /// carga reciente y reutiliza la que está en vuelo. Los contadores solo se
  /// recalculan cada [ordersCountsPollEvery].
  Future<void> autoPoll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    await _gate.auto(() => _doLoadFirst(skeleton: false, merge: true));
  }

  /// Al montar la tab: recarga lista (y contadores si tienen > 30 s) solo si
  /// la última carga tiene más de [ordersMountStale].
  Future<void> onTabShown() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    final last = _lastListOk;
    if (last != null && _now().difference(last) < ordersMountStale) return;
    final cl = _lastCountsOk;
    final countsStale = cl == null || _now().difference(cl) >= ordersMountStale;
    await _gate.auto(
      () => _doLoadFirst(skeleton: false, merge: true, counts: countsStale),
    );
  }

  /// Un pedido cambió de etapa: ajuste local (lista y contadores) y
  /// confirmación solo de las dos etapas implicadas.
  Future<void> onOrderMoved(int id, OrderStage from, OrderStage to) async {
    if (from == to) return;
    final counts = {...state.counts};
    if (counts[from] != null) {
      counts[from] = (counts[from]! - 1).clamp(0, 1 << 30);
    }
    if (counts[to] != null) counts[to] = counts[to]! + 1;
    final wasListed = state.items.any((o) => o.id == id);
    var items = state.items;
    if (wasListed && state.stage != to) {
      items = items.where((o) => o.id != id).toList();
      _removedLocally++;
    }
    state = state.copyWith(items: items, counts: counts);
    if (state.stage == to) {
      // El pedido aún no está en esta columna: hace falta la lista.
      await Future.wait([
        _reloadFirstPage(),
        _loadCounts([from]),
      ]);
    } else {
      await _loadCounts([from, to]);
    }
  }

  /// Recarga forzada de la primera página (sin skeleton); si hay un loadMore
  /// en curso se difiere a su término.
  Future<void> _reloadFirstPage() async {
    if (state.status != ListStatus.data) return;
    if (state.loadingMore) {
      _reloadAfterLoadMore = true;
      return;
    }
    await _loadFirst(skeleton: false, merge: true, counts: false);
  }

  void setStage(OrderStage stage) {
    if (stage == state.stage) return;
    _removedLocally = 0;
    state = state.copyWith(stage: stage);
    _loadFirst(counts: false);
  }

  void setSearch(String text) {
    final t = text.trim();
    if (t == state.searchText) return;
    _removedLocally = 0;
    final before = _search;
    state = state.copyWith(searchText: t);
    // Un texto que no sirve para buscar no cambia la consulta.
    if (before == _search) return;
    _loadFirst();
  }

  Future<void> loadMore() async {
    final s = state;
    if (!s.hasMore || s.loadingMore || s.status != ListStatus.data) return;
    final seq = _seq;
    state = s.copyWith(loadingMore: true);
    final result = await ref
        .read(ordersRepositoryProvider)
        .list(
          OrdersQuery(
            stage: s.stage,
            search: searchParamFor(s.searchText),
            offset: math.max(
              0,
              s.pagesLoaded * ordersPageSize - _removedLocally,
            ),
            limit: ordersPageSize,
          ),
        );
    if (!ref.mounted || seq != _seq) return;
    switch (result) {
      case Ok(:final value):
        _removedLocally = 0;
        final ids = state.items.map((o) => o.id).toSet();
        state = state.copyWith(
          items: [
            ...state.items,
            ...value.items.where((o) => !ids.contains(o.id)),
          ],
          hasMore: value.hasMore,
          pagesLoaded: state.pagesLoaded + 1,
          loadingMore: false,
        );
      case Err():
        state = state.copyWith(loadingMore: false);
    }
    if (_reloadAfterLoadMore) {
      _reloadAfterLoadMore = false;
      await _reloadFirstPage();
    }
  }
}

/// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
/// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.
@riverpod
Future<OrderDetail> orderDetail(Ref ref, int id) async {
  final r = await ref.read(ordersRepositoryProvider).detail(id);
  return switch (r) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
}
