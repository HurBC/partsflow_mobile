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
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_filters_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_tile.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late final ForegroundPoller _poller;
  // true mientras la conversación está abierta encima de la lista.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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
      mode: s.searchMode,
      chats: s.items,
    );
    if (r == null || !mounted) return;
    final c = ref.read(chatListControllerProvider.notifier);
    c.setFilters(r.filters);
    c.setMode(r.mode);
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
            filtersActive: s.filters.isActive || s.searchMode != SearchMode.all,
            tab: s.tab,
            assignedEnabled: ref.watch(apiUserProvider).value != null,
            onSearchChanged: _onSearchChanged,
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
    required this.filtersActive,
    required this.tab,
    required this.assignedEnabled,
    required this.onSearchChanged,
    required this.onClear,
    required this.onFilters,
    required this.onTab,
  });

  final String? subtitle;
  final TextEditingController searchController;
  final SearchMode searchMode;
  final bool filtersActive;
  final ChatTab tab;
  final bool assignedEnabled;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final VoidCallback onFilters;
  final ValueChanged<ChatTab> onTab;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final hint = searchMode == SearchMode.all
        ? 'Buscar cliente, teléfono o patente'
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
                      ? 'Filtros activos: no leídos, sin responder, Julia'
                      : 'Filtros: no leídos, sin responder, Julia',
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
                        child: Icon(Icons.tune, size: 20, color: pf.link),
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
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                style: TextStyle(fontSize: 15, color: pf.text),
                decoration: InputDecoration(
                  hintText: hint,
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
          const SizedBox(height: 4),
        ],
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
      final searching = state.searchText.isNotEmpty || state.filters.isActive;
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
                        if (state.filters.isActive && state.hasMore) ...[
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

    final showMoreButton =
        state.filters.isActive && state.hasMore && !state.loadingMore;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scroll,
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
          return ChatTile(chat: chat, onTap: () => onOpen(chat));
        },
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
