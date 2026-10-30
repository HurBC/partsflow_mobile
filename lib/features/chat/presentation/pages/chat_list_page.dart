import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_search_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // El umbral de Pendientes depende de la hora: re-evaluar cada 30 s.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && ref.read(chatListControllerProvider).thresholdApplies) {
        setState(() {});
      }
    });
    _poller = ForegroundPoller(
      interval: _pollEvery(ref.read(realtimeProvider)),
      isEnabled: () => mounted && !_covered,
      onTick: () {
        if (ref.read(apiUserProvider).value == null &&
            !ref.read(apiUserProvider).isLoading) {
          ref.invalidate(apiUserProvider);
        }
        ref.read(chatListControllerProvider.notifier).poll();
      },
    )..start();
  }

  // Con tiempo real el sondeo baja a 60 s; sin él, 20 s.
  Duration _pollEvery(bool realtime) => Duration(seconds: realtime ? 60 : 20);

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
  List<_ActiveFilter> _activeFilters(ChatListState s) {
    final c = ref.read(chatListControllerProvider.notifier);
    final tags = ref.watch(filterTagsProvider).value ?? const [];
    final f = s.filters;
    final a = s.advanced;
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
      if (s.searchMode != SearchMode.all)
        _ActiveFilter(
          'Buscar por ${s.searchMode.label.toLowerCase()}',
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
    final err = await ref.read(chatListControllerProvider.notifier).refresh();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final s = ref.watch(chatListControllerProvider);
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
          _Header(
            subtitle: subtitle,
            searchController: _searchController,
            searchMode: s.searchMode,
            filterCount: s.activeFilterCount,
            activeFilters: _activeFilters(s),
            tab: s.tab,
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
          ),
          if (!realtime) const _NoRealtimeBanner(),
          Expanded(
            child: ColoredBox(
              color: pf.surface,
              child: _Body(
                state: s,
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

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final ChatListState state;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = PfColors.of(context);

    if (state.isGlobalSearch &&
        state.status != ListStatus.error &&
        state.status != ListStatus.loading) {
      return _GlobalResults(state: state, onRefresh: onRefresh, onOpen: onOpen);
    }

    switch (state.status) {
      case ListStatus.loading:
        return const _Skeleton();
      case ListStatus.error:
        return ErrorState(
          message: state.error ?? 'No pudimos cargar los chats.',
          onRetry: () => ref.read(chatListControllerProvider.notifier).reload(),
        );
      case ListStatus.data:
        break;
    }

    final items = state.visible;
    if (items.isEmpty) {
      final searching =
          state.searchText.isNotEmpty || state.activeFilterCount > 0;
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
                          searching ? 'Sin resultados' : _emptyTitle(state.tab),
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
                        if (state.hidesLocally && state.hasMore) ...[
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

    return _ChatListView(
      items: items,
      state: state,
      scroll: scroll,
      onRefresh: onRefresh,
      onOpen: onOpen,
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
/// está en pantalla: se crea al reemplazarse el resultado (carga inicial,
/// pestaña, filtros, búsqueda: pasan por el skeleton) y NO se recrea con
/// sondeos, WebSocket, paginación ni pull-to-refresh. Los ids que escalonan
/// son los presentes al montarse (hasta el índice 12) y cada uno anima una
/// sola vez aunque ListView.builder recicle sus widgets.
class _ChatListView extends ConsumerStatefulWidget {
  const _ChatListView({
    required this.items,
    required this.state,
    required this.scroll,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<Chat> items;
  final ChatListState state;
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
    for (var i = 0; i < widget.items.length && i <= _maxStaggerIndex; i++)
      widget.items[i].id: i,
  };
  final _played = <String>{};
  final _mountedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final items = widget.items;
    final showMoreButton =
        state.hidesLocally && state.hasMore && !state.loadingMore;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: widget.scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == items.length) {
            if (state.loadingMore) {
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
            if (showMoreButton) {
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
          final chat = items[i];
          final idx = _stagger[chat.id];
          final animate =
              idx != null &&
              !_played.contains(chat.id) &&
              DateTime.now().difference(_mountedAt) < _window;
          if (animate) _played.add(chat.id);
          return StaggerIn(
            key: ValueKey(chat.id),
            animate: animate,
            delay: Duration(milliseconds: 35 * (idx ?? 0)),
            child: ChatTile(chat: chat, onTap: () => widget.onOpen(chat)),
          );
        },
      ),
    );
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
  const _GlobalResults({
    required this.state,
    required this.onRefresh,
    required this.onOpen,
  });

  final ChatListState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<Chat> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(chatSearchControllerProvider);
    final ctrl = ref.read(chatSearchControllerProvider.notifier);
    final clients = state.filters.isActive
        ? search.clients.items.where(state.filters.matches).toList()
        : search.clients.items;
    final messages = state.filters.isActive
        ? search.messages.items.where(state.filters.matches).toList()
        : search.messages.items;
    final retry = ref.read(chatListControllerProvider.notifier).reload;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _SectionHeader(
            'Clientes',
            count: clients.length,
            show: search.clients.status == SectionStatus.data,
          ),
          _SectionBody(
            section: search.clients,
            loadingLabel: 'Buscando clientes',
            emptyText: 'Ningún cliente coincide con «${search.query}».',
            errorText: 'No pudimos buscar clientes.',
            onRetry: retry,
            isEmpty: clients.isEmpty,
            children: [
              for (final c in clients)
                ChatTile(chat: c, onTap: () => onOpen(c)),
            ],
          ),
          _SectionHeader(
            'Mensajes',
            count: messages.length,
            show: search.messages.status == SectionStatus.data,
          ),
          _SectionBody(
            section: search.messages,
            loadingLabel: 'Buscando en los mensajes',
            emptyText: 'Ningún mensaje coincide con «${search.query}».',
            errorText: 'No pudimos buscar en los mensajes.',
            onRetry: retry,
            isEmpty: messages.isEmpty,
            children: [
              for (final c in messages)
                MessageResultTile(
                  chat: c,
                  query: search.query,
                  onTap: () => onOpen(c),
                ),
              if (search.messages.loadingMore)
                const Padding(
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
                Padding(
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
            ],
          ),
        ],
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
