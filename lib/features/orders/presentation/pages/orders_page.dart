import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart'
    show ListStatus;
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/providers/orders_providers.dart';
import 'package:partsflow_mobile/features/orders/presentation/utils/order_format.dart';
import 'package:partsflow_mobile/features/orders/presentation/widgets/order_tile.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late final ForegroundPoller _poller;
  // true mientras el detalle está abierto encima de la lista.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _poller = ForegroundPoller(
      interval: const Duration(seconds: 30),
      isEnabled: () => mounted && !_covered,
      onTick: () => ref.read(ordersListControllerProvider.notifier).poll(),
    )..start();
  }

  @override
  void dispose() {
    _poller.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      ref.read(ordersListControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(ordersListControllerProvider.notifier).setSearch(text);
      }
    });
    setState(() {});
  }

  Future<void> _open(OrderSummary order) async {
    _covered = true;
    await context.push(AppRoutes.orderDetail(order.id), extra: order);
    if (!mounted) return;
    _covered = false;
    ref.read(ordersListControllerProvider.notifier).poll();
  }

  Future<void> _refresh() async {
    final err = await ref.read(ordersListControllerProvider.notifier).refresh();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final s = ref.watch(ordersListControllerProvider);
    final user = ref.watch(currentUserProvider).value;
    final subtitle = user == null
        ? null
        : [
            user.supplierName,
            user.subsidiaryName,
          ].where((e) => e.isNotEmpty).join(' · ');

    return Scaffold(
      body: Column(
        children: [
          _Header(
            subtitle: subtitle,
            searchController: _searchController,
            state: s,
            onSearchChanged: _onSearchChanged,
            onClear: () {
              _searchController.clear();
              _debounce?.cancel();
              ref.read(ordersListControllerProvider.notifier).setSearch('');
              setState(() {});
            },
            onStage: (st) {
              if (_scroll.hasClients) _scroll.jumpTo(0);
              ref.read(ordersListControllerProvider.notifier).setStage(st);
            },
          ),
          Expanded(
            child: ColoredBox(
              color: pf.bg,
              child: _Body(
                state: s,
                scroll: _scroll,
                onRefresh: _refresh,
                onOpen: _open,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.subtitle,
    required this.searchController,
    required this.state,
    required this.onSearchChanged,
    required this.onClear,
    required this.onStage,
  });

  final String? subtitle;
  final TextEditingController searchController;
  final OrdersListState state;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final ValueChanged<OrderStage> onStage;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 12),
      decoration: BoxDecoration(
        color: pf.surface,
        border: Border(bottom: BorderSide(color: pf.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Pedidos',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: pf.text,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pf.text2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: pf.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15, color: pf.text),
                decoration: InputDecoration(
                  hintText: 'N° de pedido o teléfono',
                  hintStyle: TextStyle(color: pf.placeholder, fontSize: 15),
                  prefixIcon: Icon(Icons.search, size: 18, color: pf.text2),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          onPressed: onClear,
                          icon: Icon(Icons.close, size: 18, color: pf.text2),
                        ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          if (state.searchInvalid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'Escribe el n° de pedido (hasta 7 dígitos) o el teléfono del cliente.',
                style: TextStyle(fontSize: 12, color: pf.warnFg),
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: OrderStage.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final st = OrderStage.values[i];
                return _StagePill(
                  stage: st,
                  count: state.counts[st],
                  selected: st == state.stage,
                  onTap: () => onStage(st),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({
    required this.stage,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final OrderStage stage;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final label = count == null ? stage.tabLabel : '${stage.tabLabel} · $count';
    return Semantics(
      button: true,
      selected: selected,
      label: count == null
          ? stage.tabLabel
          : '${stage.tabLabel}, $count ${count == 1 ? 'cliente' : 'clientes'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? primary : pf.surface,
                borderRadius: BorderRadius.circular(18),
                border: selected
                    ? null
                    : Border.all(color: pf.border, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? pf.mint : stageDot(stage),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? onPrimary : pf.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final OrdersListState state;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderSummary> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);

    switch (state.status) {
      case ListStatus.loading:
        return const _Skeleton();
      case ListStatus.error:
        return ErrorState(
          message: state.error ?? 'No pudimos cargar los pedidos.',
          onRetry: () =>
              ref.read(ordersListControllerProvider.notifier).reload(),
        );
      case ListStatus.data:
        break;
    }

    final items = state.items;
    if (items.isEmpty) {
      final searching = state.searchText.isNotEmpty;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          searching
                              ? Icons.search_off
                              : Icons.receipt_long_outlined,
                          size: 40,
                          color: pf.text2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          searching
                              ? 'Sin resultados'
                              : _emptyTitle(state.stage),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: pf.text),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          searching
                              ? 'Prueba con otro número de pedido o teléfono.'
                              : 'Desliza hacia abajo para actualizar.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: pf.text2),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return state.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final order = items[i];
          return OrderTile(order: order, onTap: () => onOpen(order));
        },
      ),
    );
  }

  String _emptyTitle(OrderStage s) => switch (s) {
    OrderStage.porCotizar => 'No hay pedidos por cotizar',
    OrderStage.cotizacionEnviada => 'No hay cotizaciones enviadas',
    OrderStage.posibleVenta => 'No hay posibles ventas',
    OrderStage.ventaPorGestionar => 'No hay ventas por gestionar',
    OrderStage.devolucion => 'No hay devoluciones por gestionar',
  };
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    Widget block(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: pf.divider,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Semantics(
      label: 'Cargando pedidos',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pf.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(150 + (i % 3) * 30, 16),
                const SizedBox(height: 10),
                block(double.infinity, 12),
                const SizedBox(height: 10),
                block(120, 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
