import 'dart:async';

import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart'
    show ListStatus, failureMessage;
import 'package:partsflow_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:partsflow_mobile/features/orders/data/repositories/orders_repository_impl.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'orders_providers.g.dart';

const ordersPageSize = 20;

@Riverpod(keepAlive: true)
OrdersRepository ordersRepository(Ref ref) =>
    OrdersRepositoryImpl(OrdersRemoteDataSource(ref.watch(dioProvider)));

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
}

@Riverpod(keepAlive: true)
class OrdersListController extends _$OrdersListController {
  int _seq = 0;
  int _countSeq = 0;

  @override
  OrdersListState build() {
    // Al cambiar la sesión se descarta todo y se vuelve a cargar.
    ref.watch(authStateProvider);
    Future.microtask(() {
      if (ref.mounted) _loadFirst();
    });
    return const OrdersListState();
  }

  String? get _search => searchParamFor(state.searchText);

  Future<String?> _loadFirst({bool skeleton = true, bool merge = false}) async {
    final seq = ++_seq;
    if (skeleton) {
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
        _loadCounts();
        return null;
      case Err(:final failure):
        final msg = failureMessage(failure);
        if (skeleton || state.status != ListStatus.data) {
          state = state.copyWith(status: ListStatus.error, error: msg);
        }
        return msg;
    }
  }

  /// Contadores de las demás pestañas (una consulta liviana por etapa).
  Future<void> _loadCounts() async {
    final seq = ++_countSeq;
    final current = state.stage;
    final search = _search;
    final repo = ref.read(ordersRepositoryProvider);
    final others = OrderStage.values.where((e) => e != current);
    final results = await Future.wait([
      for (final st in others) repo.count(st, search),
    ]);
    if (!ref.mounted || seq != _countSeq || state.stage != current) return;
    final counts = {...state.counts};
    var i = 0;
    for (final st in others) {
      if (results[i] case Ok(:final value)) counts[st] = value;
      i++;
    }
    state = state.copyWith(counts: counts);
  }

  /// Carga inicial / reintento (muestra skeleton).
  Future<void> reload() => _loadFirst();

  /// Pull-to-refresh: reemplaza la lista sin skeleton. Devuelve el error, si hubo.
  Future<String?> refresh() => _loadFirst(skeleton: false);

  /// Sondeo / refresco tras una acción: primera página mezclada con lo cargado.
  Future<void> poll() async {
    if (state.status != ListStatus.data || state.loadingMore) return;
    await _loadFirst(skeleton: false, merge: true);
  }

  void setStage(OrderStage stage) {
    if (stage == state.stage) return;
    state = state.copyWith(stage: stage);
    _loadFirst();
  }

  void setSearch(String text) {
    final t = text.trim();
    if (t == state.searchText) return;
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
            offset: s.pagesLoaded * ordersPageSize,
            limit: ordersPageSize,
          ),
        );
    if (!ref.mounted || seq != _seq) return;
    switch (result) {
      case Ok(:final value):
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
