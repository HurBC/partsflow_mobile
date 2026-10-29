import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_actions_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_client_sheets.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_bubble.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/templates_sheet.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

sealed class _Entry {
  const _Entry();
}

class _Day extends _Entry {
  const _Day(this.date);
  final DateTime date;
}

class _Msg extends _Entry {
  const _Msg(this.message);
  final Message message;
}

class _Note extends _Entry {
  const _Note(this.note);
  final ThreadNote note;
}

class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({super.key, required this.chat});

  final Chat chat;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  List<_Entry> _lastEntries = const [];
  late final ForegroundPoller _poller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Lista invertida: "después" = mensajes más antiguos.
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
        ref.read(chatThreadProvider(widget.chat).notifier).loadOlder();
      }
    });
    _poller = ForegroundPoller(
      interval: Duration(seconds: ref.read(realtimeProvider) ? 30 : 10),
      isEnabled: () => mounted,
      onTick: () => ref.read(chatThreadProvider(widget.chat).notifier).poll(),
    )..start();
  }

  @override
  void dispose() {
    _poller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (text.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.chat);
    }
  }

  Future<void> _toggleJulia(bool current) async {
    final r = await ref
        .read(chatThreadProvider(widget.chat).notifier)
        .setJulia(!current);
    _snack(r.message);
  }

  Future<void> _openActions(ThreadState s) async {
    final me = ref.read(apiUserProvider).value;
    final action = await showChatActionsSheet(
      context,
      chat: s.chat,
      myUserId: me?.id,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case ChatAction.notes:
        return showClientNotesSheet(context, s.chat);
      case ChatAction.tags:
        return showClientTagsSheet(context, s.chat);
      case ChatAction.issues:
        return showClientIssuesSheet(context, s.chat);
      case ChatAction.reminder:
        return showClientReminderSheet(context, s.chat);
      default:
        break;
    }
    final c = ref.read(chatThreadProvider(widget.chat).notifier);
    final r = switch (action) {
      ChatAction.assign => await c.assignToMe(),
      ChatAction.release => await c.release(),
      ChatAction.resolve => await c.setResolved(true),
      ChatAction.unresolve => await c.setResolved(false),
      ChatAction.markUnread => await c.markUnread(),
      ChatAction.archive => await c.setArchived(true),
      ChatAction.unarchive => await c.setArchived(false),
      _ => (ok: false, message: ''),
    };
    _snack(r.message);
    if (r.ok && action == ChatAction.markUnread && mounted) _back();
  }

  Future<void> _messageMenu(Message m) async {
    final canReply = !m.isLocal && !m.hasError;
    final hasText = m.text != null && m.text!.trim().isNotEmpty;
    if (!canReply && !hasText) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReply)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.reply),
                title: const Text('Responder'),
                onTap: () => Navigator.pop(ctx, 'reply'),
              ),
            if (hasText)
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copiar texto'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'reply') {
      ref.read(chatThreadProvider(widget.chat).notifier).setReply(m);
    } else {
      await Clipboard.setData(ClipboardData(text: m.text!));
      _snack('Texto copiado');
    }
  }

  /// Salta al mensaje citado si está cargado (por message_id, id o wid de Wali).
  Future<void> _jumpTo(String wid) async {
    final s = ref.read(chatThreadProvider(widget.chat));
    final target = s.messages
        .where((m) => m.id == wid || m.websocketId == wid || m.messageId == wid)
        .firstOrNull;
    if (target == null) return _snack('El mensaje original no está cargado');
    Future<bool> reveal() async {
      final ctx = _keys[target.id]?.currentContext;
      if (ctx == null) return false;
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.4,
      );
      return true;
    }

    if (await reveal() || !mounted || !_scroll.hasClients) {
      return;
    }
    // Fuera del área construida: acercarse por pasos hasta que se construya.
    final idx = _lastEntries.indexWhere(
      (e) => e is _Msg && e.message.id == target.id,
    );
    if (idx < 0) return;
    for (var i = 0; i < 12 && mounted; i++) {
      final pos = _scroll.position;
      final dest = (idx * 90.0).clamp(0.0, pos.maxScrollExtent);
      _scroll.jumpTo(dest);
      await WidgetsBinding.instance.endOfFrame;
      if (await reveal()) return;
      if (dest >= pos.maxScrollExtent) break;
    }
    _snack('No pudimos ubicar el mensaje original');
  }

  List<_Entry> _timeline(ThreadState s) {
    final all = <({DateTime date, _Entry entry})>[
      for (final m in s.messages) (date: m.date, entry: _Msg(m)),
      for (final m in s.pending) (date: m.date, entry: _Msg(m)),
      for (final n in s.notes) (date: n.date, entry: _Note(n)),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final asc = <_Entry>[];
    DateTime? lastDay;
    for (final e in all) {
      if (lastDay == null || !sameDay(lastDay, e.date)) {
        asc.add(_Day(e.date));
        lastDay = e.date;
      }
      asc.add(e.entry);
    }
    return asc.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final s = ref.watch(chatThreadProvider(widget.chat));
    _poller.setInterval(
      Duration(seconds: ref.watch(realtimeProvider) ? 30 : 10),
    );
    final applies = ref.watch(windowAppliesProvider).value ?? false;
    final me = ref.watch(apiUserProvider).value;
    final myId = me?.id;

    final lastInbound = s.lastInboundAt;
    final windowClosed =
        applies &&
        s.historyLoaded &&
        (lastInbound == null ||
            DateTime.now().difference(lastInbound) >=
                const Duration(hours: 24));

    return Scaffold(
      backgroundColor: pf.bg,
      body: Column(
        children: [
          _Header(
            state: s,
            myUserId: myId,
            onBack: _back,
            onToggleJulia: () => _toggleJulia(s.chat.client?.juliaOn ?? false),
            onMore: () => _openActions(s),
          ),
          if (s.order != null)
            _OrderStrip(
              order: s.order!,
              onTap: () {
                final id = int.tryParse(s.order!.id);
                if (id == null) return _snack('No pudimos abrir el pedido');
                context.push(AppRoutes.orderDetail(id));
              },
            ),
          Expanded(child: _buildBody(s, myId)),
          if (windowClosed)
            _WindowNotice(
              onTemplate: () => pickAndSendTemplate(context, ref, widget.chat),
            )
          else
            ChatComposer(chat: widget.chat, templatesEnabled: applies),
        ],
      ),
    );
  }

  Widget _buildBody(ThreadState s, String? myId) {
    final pf = PfColors.of(context);
    final controller = ref.read(chatThreadProvider(widget.chat).notifier);

    if (s.status == ListStatus.loading && s.messages.isEmpty) {
      return Center(
        child: Semantics(
          label: 'Cargando mensajes',
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (s.status == ListStatus.error && s.messages.isEmpty) {
      return ErrorState(
        message: s.error ?? 'No pudimos cargar la conversación.',
        onRetry: controller.retry,
      );
    }

    final entries = _timeline(s);
    _lastEntries = entries;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Aún no hay mensajes',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: pf.text2),
        ),
      );
    }

    return Semantics(
      label: 'Mensajes',
      child: ListView.builder(
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        itemCount: entries.length + (s.loadingOlder ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= entries.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final e = entries[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: switch (e) {
              _Day(:final date) => _DayChip(label: dayLabel(date)),
              _Note(:final note) => Center(
                child: Text(
                  note.text,
                  style: TextStyle(fontSize: 12, color: pf.text2),
                ),
              ),
              _Msg(:final message) => KeyedSubtree(
                key: _keys.putIfAbsent(message.id, GlobalKey.new),
                child: MessageBubble(
                  message: message,
                  myUserId: myId,
                  onLongPress: () => _messageMenu(message),
                  onQuoteTap: message.quotedWid == null
                      ? null
                      : () => _jumpTo(message.quotedWid!),
                  onRetry: message.isLocal && message.hasError
                      ? () => controller.retrySend(message.id)
                      : null,
                  onDiscard: message.isLocal && message.hasError
                      ? () => controller.discardPending(message.id)
                      : null,
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.myUserId,
    required this.onBack,
    required this.onToggleJulia,
    required this.onMore,
  });

  final ThreadState state;
  final String? myUserId;
  final VoidCallback onBack;
  final VoidCallback onToggleJulia;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final chat = state.chat;
    final client = chat.client;
    final responsible = client?.responsible;
    final owner = responsible == null
        ? 'Sin asignar'
        : (responsible.id == myUserId
              ? 'Asignado a ti'
              : 'Asignado a ${responsible.fullName}');
    final julia = client?.juliaOn ?? false;
    final phone = maskPhone(chat.phone);

    return Container(
      padding: EdgeInsets.fromLTRB(
        4,
        MediaQuery.paddingOf(context).top + 4,
        4,
        8,
      ),
      decoration: BoxDecoration(
        color: pf.surface,
        border: Border(bottom: BorderSide(color: pf.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a chats',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: pf.text),
          ),
          ChatAvatar(chat: chat, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatDisplayName(chat),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(color: pf.text),
                ),
                Text(
                  phone.isEmpty ? owner : '$phone · $owner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pf.text2,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (client?.id != null)
            Semantics(
              button: true,
              toggled: julia,
              label: 'Julia',
              hint: julia
                  ? 'Activada. Toca para pausar'
                  : 'Pausada. Toca para activar',
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onToggleJulia,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
                      decoration: BoxDecoration(
                        color: pf.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: pf.border, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PfSwitch(
                            value: julia,
                            width: 28,
                            height: 16,
                            knob: 12,
                            inset: 2,
                            offColor: const Color(0xFF8A8FA3),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Julia',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pf.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Más acciones',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: onMore,
            icon: Icon(Icons.more_vert, color: pf.text),
          ),
        ],
      ),
    );
  }
}

class _OrderStrip extends StatelessWidget {
  const _OrderStrip({required this.order, required this.onTap});

  final OrderStrip order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final dot = switch (order.stage) {
      OrderStage.porCotizar => PfColors.stagePorCotizar,
      OrderStage.cotizacionEnviada => PfColors.stageCotizacionEnviada,
      OrderStage.posibleVenta => PfColors.stagePosibleVenta,
      OrderStage.ventaPorGestionar => PfColors.stageVentaPorGestionar,
      OrderStage.devolucion => PfColors.stageDevolucion,
    };
    return Semantics(
      button: true,
      label: 'Pedido ${order.id}, ${order.stageLabel}. Ver pedido',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pf.surface,
              border: Border(
                top: BorderSide(color: pf.divider),
                bottom: BorderSide(color: pf.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pf.indicator,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.stageLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pf.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pedido #${order.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: pf.textMid),
                  ),
                ),
                Text(
                  'Ver pedido',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pf.link,
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: pf.link),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: pf.divider,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pf.text2,
          ),
        ),
      ),
    );
  }
}

class _WindowNotice extends StatelessWidget {
  const _WindowNotice({required this.onTemplate});

  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: pf.surface,
        border: Border(top: BorderSide(color: pf.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pf.warnBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 20, color: pf.warnFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Pasaron más de 24 horas desde el último mensaje del cliente: solo puedes enviar una plantilla.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: pf.warnFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onTemplate,
              icon: const Icon(Icons.description_outlined, size: 20),
              label: const Text('Elegir plantilla'),
            ),
          ),
        ],
      ),
    );
  }
}
