import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/foreground_poller.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
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
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_bubble.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/swipe_to_reply.dart';
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
  final _composerFocus = FocusNode();

  // Entrada de mensajes nuevos. Solo anima lo que aparece DESPUÉS de cargado
  // el hilo: el historial inicial, las páginas antiguas y los re-renders no.
  final _known = <String>{};
  bool _baselined = false;
  DateTime? _newest;
  final _enter = <String, ({MessageEntranceKind kind, DateTime at})>{};
  final _played = <String>{};
  // Firmas de mensajes locales ya animados, para no reanimar al confirmarse.
  final _localSigs = <({String sig, DateTime at})>[];
  static const _enterWindow = Duration(milliseconds: 1500);

  String? _flashId;
  int _flashSerial = 0;
  Timer? _flashTimer;

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
    _flashTimer?.cancel();
    _composerFocus.dispose();
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

  Future<void> _copyPhone(String phone) async {
    final text = formatPhone(phone).replaceAll(' ', '');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _snack('Número copiado');
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
      case ChatAction.copyPhone:
        return _copyPhone(s.chat.phone);
      default:
        break;
    }
    final c = ref.read(chatThreadProvider(widget.chat).notifier);
    final r = switch (action) {
      ChatAction.assign => await c.assignToMe(),
      ChatAction.release => await c.release(),
      ChatAction.important => await c.setImportant(
        !(s.chat.client?.isImportant ?? false),
      ),
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

  bool _canReply(Message m) => !m.isLocal && !m.hasError && !m.isDeleted;

  /// Acción "Responder" (menú y deslizar): cita el mensaje y enfoca el composer.
  void _reply(Message m) {
    ref.read(chatThreadProvider(widget.chat).notifier).setReply(m);
    _composerFocus.requestFocus();
  }

  Future<void> _messageMenu(Message m) async {
    final canReply = _canReply(m);
    final hasText = !m.isDeleted && m.text != null && m.text!.trim().isNotEmpty;
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
      _reply(m);
    } else {
      await Clipboard.setData(ClipboardData(text: m.text!));
      _snack('Texto copiado');
    }
  }

  bool _jumping = false;

  Message? _findQuoted(String wid) => ref
      .read(chatThreadProvider(widget.chat))
      .messages
      .where((m) => m.id == wid || m.websocketId == wid || m.messageId == wid)
      .firstOrNull;

  int _entryIndex(String id) =>
      _lastEntries.indexWhere((e) => e is _Msg && e.message.id == id);

  /// Alto promedio de los ítems construidos (estimación para la lista perezosa).
  double _avgExtent() {
    var total = 0.0;
    var n = 0;
    for (final k in _keys.values) {
      final box = k.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.attached) {
        total += box.size.height + 8;
        n++;
      }
    }
    return n == 0 ? 90.0 : total / n;
  }

  /// Salta al mensaje citado (por message_id, id o websocket_id). Si no está
  /// cargado, trae páginas antiguas (máx. 5); si está fuera del área construida
  /// de la lista perezosa, se acerca por estimación (máx. 6 intentos).
  Future<void> _jumpTo(String wid) async {
    if (_jumping) return;
    _jumping = true;
    var pages = 0;
    var attempts = 0;
    var found = false;
    var idx = -1;
    try {
      var target = _findQuoted(wid);
      final controller = ref.read(chatThreadProvider(widget.chat).notifier);
      if (target == null) _snack('Buscando mensaje original…');
      while (target == null && pages < 5 && mounted) {
        if (!ref.read(chatThreadProvider(widget.chat)).hasMoreOlder) break;
        await controller.loadOlder();
        pages++;
        await WidgetsBinding.instance.endOfFrame;
        target = _findQuoted(wid);
      }
      if (!mounted) return;
      if (target == null) {
        _snack('No se encontró el mensaje original');
        return;
      }
      final id = target.id;
      for (; attempts < 6; attempts++) {
        if (!mounted) return;
        final ctx = _keys[id]?.currentContext;
        if (ctx != null && ctx.mounted) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
          _flash(id);
          found = true;
          return;
        }
        idx = _entryIndex(id);
        if (idx < 0 || !_scroll.hasClients) break;
        final pos = _scroll.position;
        final avg = _avgExtent();
        // Lista invertida: índice mayor = más antiguo = más offset.
        var dest = idx * avg;
        final nearest = _nearestBuiltIndex(idx);
        if (nearest != null) {
          dest = pos.pixels + (idx - nearest) * avg;
        }
        _scroll.jumpTo(dest.clamp(0.0, pos.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted) _snack('No se encontró el mensaje original');
    } finally {
      _jumping = false;
      pfLog(
        'jumpTo wid=$wid found=$found index=$idx pages=$pages '
        'attempts=$attempts',
      );
    }
  }

  /// Índice (en `_lastEntries`) del ítem construido más cercano a [idx].
  int? _nearestBuiltIndex(int idx) {
    int? best;
    for (var i = 0; i < _lastEntries.length; i++) {
      final e = _lastEntries[i];
      if (e is! _Msg || _keys[e.message.id]?.currentContext == null) continue;
      if (best == null || (i - idx).abs() < (best - idx).abs()) best = i;
    }
    return best;
  }

  void _flash(String id) {
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() {
      _flashId = id;
      _flashSerial++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  String _sig(Message m) => '${m.hasMedia}|${(m.text ?? '').trim()}';

  /// Detecta mensajes que aparecen después de cargado el hilo. Nuevo =
  /// id desconocido y (local, o más reciente que todo lo conocido): así las
  /// páginas antiguas nunca cuentan. Un mensaje del servidor que confirma uno
  /// local (misma firma) no se anima otra vez.
  void _classify(ThreadState s) {
    if (!s.historyLoaded) return;
    final all = [...s.messages, ...s.pending];
    final now = DateTime.now();
    _localSigs.removeWhere(
      (e) => now.difference(e.at) > const Duration(minutes: 2),
    );
    if (!_baselined) {
      _baselined = true;
      for (final m in all) {
        _known.add(m.id);
        if (_newest == null || m.date.isAfter(_newest!)) _newest = m.date;
      }
      return;
    }
    final base = _newest;
    for (final m in all) {
      if (!_known.add(m.id)) continue;
      if (m.isLocal) {
        _localSigs.add((sig: _sig(m), at: now));
        _enter[m.id] = (kind: MessageEntranceKind.own, at: now);
        continue;
      }
      if (base != null && !m.date.isAfter(base)) continue;
      if (m.isOutbound) {
        var i = _localSigs.indexWhere((e) => e.sig == _sig(m));
        // Media: el tipo/leyenda local puede diferir del confirmado.
        if (i < 0 && m.hasMedia) {
          i = _localSigs.indexWhere((e) => e.sig.startsWith('true|'));
        }
        if (i >= 0) {
          _localSigs.removeAt(i);
          continue;
        }
      }
      _enter[m.id] = (kind: MessageEntranceKind.incoming, at: now);
    }
    for (final m in all) {
      if (_newest == null || m.date.isAfter(_newest!)) _newest = m.date;
    }
  }

  /// true una sola vez por mensaje, mientras la detección sea reciente.
  MessageEntranceKind? _takeEntrance(String id) {
    final e = _enter[id];
    if (e == null || _played.contains(id)) return null;
    if (DateTime.now().difference(e.at) > _enterWindow) return null;
    _played.add(id);
    return e.kind;
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

  /// ¿El mensaje de `entries[j]` es del mismo remitente que [m] y ≤ 2 min de
  /// distancia, sin separador de día ni nota entre medio?
  bool _joined(List<_Entry> entries, int j, Message m, String? myId) {
    if (j < 0 || j >= entries.length) return false;
    final o = entries[j];
    if (o is! _Msg) return false;
    final other = o.message;
    if (other.isDeleted != m.isDeleted) return false;
    final a = m.author(myId);
    if (a != other.author(myId)) return false;
    if (a != MessageAuthor.client &&
        (m.senderName ?? m.agent) != (other.senderName ?? other.agent)) {
      return false;
    }
    return m.date.difference(other.date).abs() <= const Duration(minutes: 2);
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
            onCopyPhone: () => _copyPhone(s.chat.phone),
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
            ChatComposer(
              chat: widget.chat,
              templatesEnabled: applies,
              focusNode: _composerFocus,
            ),
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

    _classify(s);
    final entries = _timeline(s);
    _lastEntries = entries;
    final reduce = MediaQuery.disableAnimationsOf(context);
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
          // `entries` va de nuevo a antiguo: i+1 es el vecino anterior.
          final joinedPrev =
              e is _Msg && _joined(entries, i + 1, e.message, myId);
          final joinedNext =
              e is _Msg && _joined(entries, i - 1, e.message, myId);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              joinedPrev ? 1 : 4,
              0,
              joinedNext ? 1 : 4,
            ),
            child: switch (e) {
              _Day(:final date) => _DayChip(label: dayLabel(date)),
              _Note(:final note) => Center(
                child: Text(
                  note.text,
                  style: TextStyle(fontSize: 12, color: pf.text2),
                ),
              ),
              _Msg(:final message) => _messageRow(
                message,
                myId,
                controller,
                reduce,
                joinedPrev: joinedPrev,
                joinedNext: joinedNext,
              ),
            },
          );
        },
      ),
    );
  }
}

extension on _ChatDetailPageState {
  Widget _messageRow(
    Message message,
    String? myId,
    ChatThread controller,
    bool reduce, {
    bool joinedPrev = false,
    bool joinedNext = false,
  }) {
    final kind = _takeEntrance(message.id);
    final animate = kind != null && !reduce;
    final bubble = SwipeToReply(
      enabled: _canReply(message),
      onReply: () => _reply(message),
      child: MessageBubble(
        message: message,
        myUserId: myId,
        joinedPrev: joinedPrev,
        joinedNext: joinedNext,
        auraEntrance: animate && kind == MessageEntranceKind.incoming,
        flashSerial: _flashId == message.id ? _flashSerial : 0,
        onLongPress: () => _messageMenu(message),
        onQuoteTap: message.quotedWid == null
            ? null
            : () => _jumpTo(message.quotedWid!),
        onTemplate: () => pickAndSendTemplate(context, ref, widget.chat),
        onRetry: message.isLocal && message.hasError
            ? () => controller.retrySend(message.id)
            : null,
        onDiscard: message.isLocal && message.hasError
            ? () => controller.discardPending(message.id)
            : null,
      ),
    );
    return KeyedSubtree(
      key: _keys.putIfAbsent(message.id, GlobalKey.new),
      child: MessageEntrance(
        animate: animate,
        kind: kind ?? MessageEntranceKind.incoming,
        child: bubble,
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
    required this.onCopyPhone,
  });

  final ThreadState state;
  final String? myUserId;
  final VoidCallback onBack;
  final VoidCallback onToggleJulia;
  final VoidCallback onMore;
  final VoidCallback onCopyPhone;

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
    final phone = formatPhone(chat.phone);
    final important = client?.isImportant ?? false;

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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        chatDisplayName(chat),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: pf.text,
                        ),
                      ),
                    ),
                    if (important) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        label: 'Cliente importante',
                        child: ExcludeSemantics(
                          child: Icon(Icons.star, size: 18, color: pf.warnFg),
                        ),
                      ),
                    ],
                  ],
                ),
                Semantics(
                  button: phone.isNotEmpty,
                  label: phone.isEmpty ? owner : 'Copiar número $phone, $owner',
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: phone.isEmpty ? null : onCopyPhone,
                      child: Text(
                        phone.isEmpty ? owner : '$phone · $owner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pf.text2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
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
