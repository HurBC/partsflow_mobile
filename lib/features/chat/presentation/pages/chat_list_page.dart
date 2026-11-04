import 'dart:async';

import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/router/tab_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/realtime/chat_poll_policy.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/action_required_provider.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_list_view_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_search_provider.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_row_actions.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/action_required_bar.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_filters_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_tile.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_result_tile.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Timer? _clock;
  late final ForegroundPoller _poller;
  // true mientras la conversación está abierta encima de la lista.
  bool _covered = false;
  // false mientras otra tab del shell está al frente (la rama sigue viva).
  bool _tabVisible = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // El umbral de Pendientes depende de la hora: re-evaluar cada 30 s.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          _tabVisible &&
          !_covered &&
          ref.read(chatListControllerProvider).thresholdApplies) {
        // Solo reconstruye la lista si el resultado visible cambia.
        ref.read(chatClockProvider.notifier).tick();
      }
    });
    _poller = ForegroundPoller(
      interval: _pollEvery(ref.read(realtimeProvider)),
      isEnabled: () => mounted && !_covered && _tabVisible,
      onTick: () {
        if (ref.read(apiUserProvider).value == null &&
            !ref.read(apiUserProvider).isLoading) {
          ref.invalidate(apiUserProvider);
        }
        ref.read(chatListControllerProvider.notifier).autoPoll();
        // Watchdog: refresca las tarjetas (con tope de frecuencia propio).
        ref.read(actionRequiredProvider.notifier).refresh();
      },
    )..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TabVisibility.isActive(context, 0);
    if (visible == _tabVisible) return;
    _tabVisible = visible;
    // Al volver a la tab el poller estuvo pausado: refresca (con cooldown).
    if (visible && !_covered) {
      ref.read(chatListControllerProvider.notifier).autoPoll();
    }
  }

  // Socket sano: watchdog de 120 s; si no, 20 s.
  Duration _pollEvery(bool healthy) => chatListPollEvery(healthy: healthy);

  @override
  void dispose() {
    _poller.dispose();
    _debounce?.cancel();
    _clock?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      ref.read(chatListControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(chatListControllerProvider.notifier).setSearch(text);
      }
    });
    setState(() {});
  }

  Future<void> _openChat(Chat chat) async {
    _covered = true;
    await context.push(AppRoutes.chatDetail(chat.id), extra: chat);
    if (!mounted) return;
    _covered = false;
    ref.read(chatListControllerProvider.notifier).poll();
  }

  /// Tap en una tarjeta. Importantes: igual que el BO (pestaña Todos + búsqueda
  /// por esos teléfonos). Pedidos: hoja con la lista (máx. 50) y abre el
  /// detalle del elegido (el BO abre su kanban filtrado por esos ids).
  Future<void> _openActionCard(ActionCard card) async {
    final counts = ref.read(actionRequiredProvider).counts;
    if (card == ActionCard.importantClients) {
      _debounce?.cancel();
      _searchController.text = counts.importantClients.join(',');
      if (_scroll.hasClients) _scroll.jumpTo(0);
      ref
          .read(chatListControllerProvider.notifier)
          .searchPhones(counts.importantClients);
      setState(() {});
      return;
    }
    final ids = card == ActionCard.toQuote
        ? counts.toQuoteOrders
        : counts.optionsAcceptedOrders;
    final id = await showActionOrdersSheet(context, card: card, orderIds: ids);
    if (id == null || !mounted) return;
    context.push(AppRoutes.orderDetail(id));
  }

  Future<void> _openFilters() async {
    final s = ref.read(chatListControllerProvider);
    final r = await showChatFiltersSheet(
      context,
      filters: s.filters,
      advanced: s.advanced,
      threshold: s.pendingThreshold,
      showThreshold: s.tab == ChatTab.pending,
      chats: s.items,
    );
    if (r == null || !mounted) return;
    final c = ref.read(chatListControllerProvider.notifier);
    c.setFilters(r.filters);
    c.setPendingThreshold(r.threshold);
    c.setAdvanced(r.advanced);
  }

  /// Chips de filtros activos, cada uno con su "x".
  List<_ActiveFilter> _activeFilters(
    WidgetRef ref,
    ChatFilters f,
    AdvancedFilters a,
    SearchMode searchMode,
  ) {
    final c = ref.read(chatListControllerProvider.notifier);
    final tags = ref.watch(filterTagsProvider).value ?? const [];
    String tagName(String id) {
      for (final t in tags) {
        if (t.id == id) return t.name;
      }
      return 'Etiqueta';
    }

    return [
      if (f.unread)
        _ActiveFilter(
          'No leídos',
          () => c.setFilters(f.copyWith(unread: false)),
        ),
      if (f.unanswered)
        _ActiveFilter(
          'Sin responder',
          () => c.setFilters(f.copyWith(unanswered: false)),
        ),
      if (f.julia)
        _ActiveFilter(
          'Julia atendiendo',
          () => c.setFilters(f.copyWith(julia: false)),
        ),
      if (f.unassigned)
        _ActiveFilter(
          'Sin asignar',
          () => c.setFilters(f.copyWith(unassigned: false)),
        ),
      if (searchMode != SearchMode.all)
        _ActiveFilter(
          'Buscar por ${searchMode.label.toLowerCase()}',
          () => c.setMode(SearchMode.all),
        ),
      if (a.channel != null)
        _ActiveFilter(
          'Canal: ${leadChannelLabel(a.channel!)}',
          () => c.setAdvanced(a.copyWith(clearChannel: true)),
        ),
      if (a.tagId != null)
        _ActiveFilter(
          'Etiqueta: ${tagName(a.tagId!)}',
          () => c.setAdvanced(a.copyWith(clearTag: true)),
        ),
      if (a.status != null)
        _ActiveFilter(
          'Estado: ${clientStatusLabel(a.status!)}',
          () => c.setAdvanced(a.copyWith(clearStatus: true)),
        ),
      if (a.issueType != null)
        _ActiveFilter(
          'Problema: ${issueTypeLabel(a.issueType!)}',
          () => c.setAdvanced(a.copyWith(clearIssue: true)),
        ),
      if (a.recurrent)
        _ActiveFilter(
          'Recurrentes',
          () => c.setAdvanced(a.copyWith(recurrent: false)),
        ),
      if (a.important)
        _ActiveFilter(
          'Importantes',
          () => c.setAdvanced(a.copyWith(important: false)),
        ),
      if (a.hasIssues)
        _ActiveFilter(
          'Con problemas',
          () => c.setAdvanced(a.copyWith(hasIssues: false)),
        ),
      if (a.noOrders)
        _ActiveFilter(
          'Sin pedidos',
          () => c.setAdvanced(a.copyWith(noOrders: false)),
        ),
    ];
  }

  Future<void> _refresh() async {
    final cards = ref
        .read(actionRequiredProvider.notifier)
        .refresh(force: true);
    final err = await ref.read(chatListControllerProvider.notifier).refresh();
    await cards;
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final user = ref.watch(currentUserProvider).value;
    final realtime = ref.watch(realtimeProvider);
    _poller.setInterval(_pollEvery(realtime));
    final subtitle = user == null
        ? null
        : [
            user.supplierName,
            user.subsidiaryName,
          ].where((e) => e.isNotEmpty).join(' · ');

    return Scaffold(
      body: Column(
        children: [
          // Observa solo los campos del header (modo, filtros, pestaña).
          Consumer(
            builder: (context, ref, _) {
              final h = ref.watch(
                chatListControllerProvider.select(
                  (s) => (
                    tab: s.tab,
                    searchMode: s.searchMode,
                    filters: s.filters,
                    advanced: s.advanced,
                  ),
                ),
              );
              return _Header(
                subtitle: subtitle,
                searchController: _searchController,
                searchMode: h.searchMode,
                filterCount: ChatListState(
                  searchMode: h.searchMode,
                  filters: h.filters,
                  advanced: h.advanced,
                ).activeFilterCount,
                activeFilters: _activeFilters(
                  ref,
                  h.filters,
                  h.advanced,
                  h.searchMode,
                ),
                tab: h.tab,
                assignedEnabled: ref.watch(apiUserProvider).value != null,
                onSearchChanged: _onSearchChanged,
                onMode: (m) =>
                    ref.read(chatListControllerProvider.notifier).setMode(m),
                onClear: () {
                  _searchController.clear();
                  _debounce?.cancel();
                  ref.read(chatListControllerProvider.notifier).setSearch('');
                  setState(() {});
                },
                onFilters: _openFilters,
                onTab: (t) {
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  ref.read(chatListControllerProvider.notifier).setTab(t);
                },
              );
            },
          ),
          if (!realtime) const _NoRealtimeBanner(),
          ActionRequiredBar(onOpen: _openActionCard),
          Expanded(
            child: ColoredBox(
              color: pf.surface,
              child: ChatListBody(
                scroll: _scroll,
                onRefresh: _refresh,
                onOpen: _openChat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso discreto: no bloquea nada, solo informa que el refresco es por sondeo.
class _NoRealtimeBanner extends StatelessWidget {
  const _NoRealtimeBanner();

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        color: pf.warnBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.sync_problem_outlined, size: 14, color: pf.warnFg),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Sin tiempo real · actualizando cada 20 s',
                style: TextStyle(fontSize: 12, color: pf.warnFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.subtitle,
    required this.searchController,
    required this.searchMode,
    required this.filterCount,
    required this.activeFilters,
    required this.tab,
    required this.assignedEnabled,
    required this.onSearchChanged,
    required this.onMode,
    required this.onClear,
    required this.onFilters,
    required this.onTab,
  });

  final String? subtitle;
  final TextEditingController searchController;
  final SearchMode searchMode;
  final int filterCount;
  final List<_ActiveFilter> activeFilters;
  final ChatTab tab;
  final bool assignedEnabled;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SearchMode> onMode;
  final VoidCallback onClear;
  final VoidCallback onFilters;
  final ValueChanged<ChatTab> onTab;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final filtersActive = filterCount > 0;
    final hint = searchMode == SearchMode.all
        ? 'Buscar clientes y mensajes'
        : 'Buscar por ${searchMode.label.toLowerCase()}';

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Chats',
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
                Semantics(
                  button: true,
                  label: filtersActive
                      ? 'Filtros, $filterCount activos'
                      : 'Filtros',
                  child: ExcludeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onFilters,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: filtersActive ? primary : pf.border,
                            width: 1.5,
                          ),
                          color: filtersActive ? pf.indicator : null,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.tune, size: 20, color: pf.link),
                            if (filtersActive)
                              Positioned(
                                top: -8,
                                right: -8,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$filterCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
              child: Row(
                children: [
                  _SearchModeButton(mode: searchMode, onSelected: onMode),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: 15, color: pf.text),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: pf.placeholder,
                          fontSize: 15,
                        ),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                onPressed: onClear,
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: pf.text2,
                                ),
                              ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ChatTab.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = ChatTab.values[i];
                final enabled = t != ChatTab.assigned || assignedEnabled;
                return _TabPill(
                  label: t.label,
                  selected: t == tab,
                  enabled: enabled,
                  onTap: () => onTab(t),
                );
              },
            ),
          ),
          if (activeFilters.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activeFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _ActiveFilterChip(activeFilters[i]),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

IconData searchModeIcon(SearchMode m) => switch (m) {
  SearchMode.all => Icons.search,
  SearchMode.client => Icons.person_outline,
  SearchMode.phone => Icons.phone_outlined,
  SearchMode.plate => Icons.directions_car_outlined,
  SearchMode.note => Icons.description_outlined,
  SearchMode.responsible => Icons.badge_outlined,
  SearchMode.orderId => Icons.receipt_long_outlined,
  SearchMode.orderNote => Icons.sticky_note_2_outlined,
};

/// Modo de búsqueda a la izquierda de la barra (equivale a SEARCH_MODES del BO).
class _SearchModeButton extends StatelessWidget {
  const _SearchModeButton({required this.mode, required this.onSelected});

  final SearchMode mode;
  final ValueChanged<SearchMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final active = mode != SearchMode.all;
    return PopupMenuButton<SearchMode>(
      tooltip: 'Buscar por: ${mode.label}',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final m in SearchMode.values)
          PopupMenuItem<SearchMode>(
            value: m,
            height: 48,
            child: Row(
              children: [
                Icon(searchModeIcon(m), size: 20, color: pf.link),
                const SizedBox(width: 12),
                Expanded(child: Text(m.label)),
                if (m == mode) Icon(Icons.check, size: 18, color: pf.link),
              ],
            ),
          ),
      ],
      child: Container(
        width: 56,
        height: 44,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searchModeIcon(mode),
              size: 20,
              color: active ? pf.link : pf.text2,
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: pf.text2),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilter {
  const _ActiveFilter(this.label, this.onRemove);

  final String label;
  final VoidCallback onRemove;
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip(this.filter);

  final _ActiveFilter filter;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Semantics(
      button: true,
      label: 'Quitar filtro ${filter.label}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: filter.onRemove,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              child: Container(
                height: 32,
                padding: const EdgeInsets.only(left: 12, right: 6),
                decoration: BoxDecoration(
                  color: pf.indicator,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pf.link,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.close, size: 16, color: pf.link),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? primary : pf.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: selected
                      ? null
                      : Border.all(color: pf.border, width: 1.5),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? onPrimary : pf.textMid,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BodyMode { skeleton, error, global, list }

/// Cuerpo de la página: decide qué mostrar observando solo el modo; cada
/// subárbol observa únicamente lo que pinta.
class ChatListBody extends ConsumerWidget {
  const ChatListBody({
    super.key,
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      chatListControllerProvider.select(
        (s) => s.isGlobalSearch && s.status == ListStatus.data
            ? _BodyMode.global
            : switch (s.status) {
                ListStatus.loading => _BodyMode.skeleton,
                ListStatus.error => _BodyMode.error,
                ListStatus.data => _BodyMode.list,
              },
      ),
    );
    switch (mode) {
      case _BodyMode.skeleton:
        return const _Skeleton();
      case _BodyMode.error:
        final error = ref.watch(
          chatListControllerProvider.select((s) => s.error),
        );
        return ErrorState(
          message: error ?? 'No pudimos cargar los chats.',
          onRetry: () => ref.read(chatListControllerProvider.notifier).reload(),
        );
      case _BodyMode.global:
        return _GlobalResults(onRefresh: onRefresh, onOpen: onOpen);
      case _BodyMode.list:
        return Stack(
          children: [
            _VisibleList(scroll: scroll, onRefresh: onRefresh, onOpen: onOpen),
            const _RefiningBar(),
          ],
        );
    }
  }
}

/// Indicador de refinamiento (texto / filtros avanzados): la lista actual
/// sigue en pantalla hasta que llega la respuesta.
class _RefiningBar extends ConsumerWidget {
  const _RefiningBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refining = ref.watch(
      chatListControllerProvider.select((s) => s.refining),
    );
    if (!refining) return const SizedBox.shrink();
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(minHeight: 2),
    );
  }
}

/// Observa solo la secuencia de ids visibles.
class _VisibleList extends ConsumerWidget {
  const _VisibleList({
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(chatVisibleIdsProvider).ids;
    if (ids.isEmpty) return _EmptyView(onRefresh: onRefresh);
    return _ChatListView(
      ids: ids,
      scroll: scroll,
      onRefresh: onRefresh,
      onOpen: onOpen,
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);
    final v = ref.watch(
      chatListControllerProvider.select(
        (s) => (
          refining: s.refining,
          searching: s.searchText.isNotEmpty || s.activeFilterCount > 0,
          tab: s.tab,
          canLoadMore: s.hidesLocally && s.hasMore,
        ),
      ),
    );
    // Refinando desde una lista vacía no hay nada que conservar.
    if (v.refining) return const _Skeleton();
    final searching = v.searching;
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
                            : Icons.chat_bubble_outline,
                        size: 40,
                        color: pf.text2,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searching ? 'Sin resultados' : _emptyTitle(v.tab),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: pf.text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        searching
                            ? 'Prueba con otra búsqueda o quita los filtros.'
                            : 'Desliza hacia abajo para actualizar.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: pf.text2),
                        textAlign: TextAlign.center,
                      ),
                      if (v.canLoadMore) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref
                              .read(chatListControllerProvider.notifier)
                              .loadMore(),
                          child: const Text('Cargar más chats'),
                        ),
                      ],
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

  String _emptyTitle(ChatTab tab) => switch (tab) {
    ChatTab.pending => 'No tienes chats pendientes',
    ChatTab.assigned => 'No tienes chats asignados',
    ChatTab.all => 'No hay chats',
    ChatTab.issues => 'No hay chats con problemas',
    ChatTab.resolved => 'No hay chats resueltos',
    ChatTab.archived => 'No hay chats archivados',
  };
}

/// Lista de chats con entrada escalonada. Su State vive mientras la lista
/// está en pantalla: se crea al reemplazarse el resultado por otra pestaña o
/// carga con skeleton y NO se recrea con sondeos, WebSocket, paginación,
/// pull-to-refresh ni refinamientos. Los ids que escalonan son los presentes
/// al montarse (hasta el índice 12) y cada uno anima una sola vez aunque
/// ListView.builder recicle sus widgets. Solo se reconstruye cuando cambia la
/// secuencia de ids; cada fila observa su propio chat y el pie su propio
/// estado de carga.
class _ChatListView extends ConsumerStatefulWidget {
  const _ChatListView({
    required this.ids,
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<String> ids;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  ConsumerState<_ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends ConsumerState<_ChatListView> {
  static const _maxStaggerIndex = 12;
  static const _window = Duration(seconds: 1);

  late final Map<String, int> _stagger = {
    for (var i = 0; i < widget.ids.length && i <= _maxStaggerIndex; i++)
      widget.ids[i]: i,
  };
  final _played = <String>{};
  final _mountedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ids = widget.ids;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: widget.scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: ids.length + 1,
        itemBuilder: (context, i) {
          if (i == ids.length) return const _ListFooter();
          final id = ids[i];
          final idx = _stagger[id];
          final animate =
              idx != null &&
              !_played.contains(id) &&
              DateTime.now().difference(_mountedAt) < _window;
          if (animate) _played.add(id);
          return StaggerIn(
            key: ValueKey(id),
            animate: animate,
            delay: Duration(milliseconds: 35 * (idx ?? 0)),
            child: _ChatRow(id: id, onOpen: widget.onOpen),
          );
        },
      ),
    );
  }
}

/// Fila: observa SU chat por id; un cambio en otro chat no la reconstruye.
class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.id, required this.onOpen});

  final String id;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatByIdProvider(id));
    if (chat == null) return const SizedBox.shrink();
    return ChatTile(
      chat: chat,
      onTap: () => onOpen(chat),
      onLongPress: () => showChatRowActions(context, ref, chat),
    );
  }
}

class _ListFooter extends ConsumerWidget {
  const _ListFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(
      chatListControllerProvider.select(
        (s) => (
          loadingMore: s.loadingMore,
          showMore: s.hidesLocally && s.hasMore && !s.loadingMore,
        ),
      ),
    );
    if (v.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (v.showMore) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: TextButton(
          onPressed: () =>
              ref.read(chatListControllerProvider.notifier).loadMore(),
          child: const Text('Cargar más chats'),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    Widget block(double w, double h, {double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: pf.divider,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    return Semantics(
      label: 'Cargando chats',
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                block(48, 48, r: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(150 + (i % 3) * 30, 14),
                      const SizedBox(height: 8),
                      block(double.infinity, 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resultados del modo "Todo": sección Clientes (nombre / teléfono / patente)
/// y sección Mensajes (texto libre, con el fragmento que coincidió).
class _GlobalResults extends ConsumerWidget {
  const _GlobalResults({required this.onRefresh, required this.onOpen});

  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(chatSearchControllerProvider);
    // Solo los subfiltros locales afectan lo que se muestra de la lista.
    final filters = ref.watch(
      chatListControllerProvider.select((s) => s.filters),
    );
    final ctrl = ref.read(chatSearchControllerProvider.notifier);
    final clients = filters.isActive
        ? search.clients.items.where(filters.matches).toList()
        : search.clients.items;
    final messages = filters.isActive
        ? search.messages.items.where(filters.matches).toList()
        : search.messages.items;
    final retry = ref.read(chatListControllerProvider.notifier).reload;

    Widget note(
      SearchSection section,
      String loadingLabel,
      String emptyText,
      String errorText,
      bool isEmpty,
    ) => _SectionBody(
      section: section,
      loadingLabel: loadingLabel,
      emptyText: emptyText,
      errorText: errorText,
      onRetry: retry,
      isEmpty: isEmpty,
      children: const [],
    );

    // Filas planas construidas de forma perezosa (ListView.builder).
    final rows = <Widget Function()>[
      () => _SectionHeader(
        'Clientes',
        count: clients.length,
        show: search.clients.status == SectionStatus.data,
      ),
      if (search.clients.status == SectionStatus.data && clients.isNotEmpty)
        for (final c in clients) () => ChatTile(chat: c, onTap: () => onOpen(c))
      else
        () => note(
          search.clients,
          'Buscando clientes',
          'Ningún cliente coincide con «${search.query}».',
          'No pudimos buscar clientes.',
          clients.isEmpty,
        ),
      () => _SectionHeader(
        'Mensajes',
        count: messages.length,
        show: search.messages.status == SectionStatus.data,
      ),
      if (search.messages.status == SectionStatus.data &&
          messages.isNotEmpty) ...[
        for (final c in messages)
          () => MessageResultTile(
            chat: c,
            query: search.query,
            onTap: () => onOpen(c),
          ),
        if (search.messages.loadingMore)
          () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (search.messages.hasMore)
          () => Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: TextButton(
                onPressed: ctrl.loadMoreMessages,
                child: Text(
                  search.messages.moreFailed
                      ? 'No pudimos cargar más. Reintentar'
                      : 'Cargar más mensajes',
                ),
              ),
            ),
          ),
      ] else
        () => note(
          search.messages,
          'Buscando en los mensajes',
          'Ningún mensaje coincide con «${search.query}».',
          'No pudimos buscar en los mensajes.',
          messages.isEmpty,
        ),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: rows.length,
        itemBuilder: (_, i) => rows[i](),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.count, required this.show});

  final String title;
  final int count;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      width: double.infinity,
      color: pf.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          show ? '$title · $count' : title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: pf.text2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.loadingLabel,
    required this.emptyText,
    required this.errorText,
    required this.onRetry,
    required this.isEmpty,
    required this.children,
  });

  final SearchSection section;
  final String loadingLabel;
  final String emptyText;
  final String errorText;
  final VoidCallback onRetry;
  final bool isEmpty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    Widget note(String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: pf.text2)),
          ),
          ?action,
        ],
      ),
    );

    switch (section.status) {
      case SectionStatus.idle:
        return note(section.hint ?? '');
      case SectionStatus.loading:
        return Semantics(
          label: loadingLabel,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        );
      case SectionStatus.error:
        return note(
          errorText,
          action: TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        );
      case SectionStatus.data:
        if (isEmpty) return note(emptyText);
        return Column(children: children);
    }
  }
}
