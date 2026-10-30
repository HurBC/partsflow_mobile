import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/message_ticks.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final name = chatDisplayName(chat);
    final last = chat.lastMessage;
    final preview = previewFor(last);
    final unread = chat.hasUnread;
    final time = listTime(chat.activityAt);
    final julia = chat.client?.juliaOn ?? false;
    final chips = _chips(context, pf);

    final unreadLabel = chat.unreadCount > 0
        ? (chat.unreadCount == 1
              ? '1 mensaje sin leer'
              : '${chat.unreadCount} mensajes sin leer')
        : 'Marcado como no leído';

    return Semantics(
      button: true,
      label: [
        name,
        if (unread) unreadLabel,
        if (chat.client?.isImportant ?? false) 'Cliente importante',
        if ((chat.client?.tags ?? const <ChatTag>[]).isNotEmpty)
          'Etiquetas: ${chat.client!.tags.take(2).map((t) => t.name).join(', ')}',
        if (julia) 'Julia atendiendo',
        if (chat.hasPendingReminder) 'Recordatorio pendiente',
        if (preview.isNotEmpty) preview,
        if (time.isNotEmpty) time,
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pf.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatAvatar(chat: chat, showJulia: julia),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: pf.text,
                              ),
                            ),
                          ),
                          if (chat.client?.isImportant ?? false) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.star, size: 16, color: pf.warnFg),
                          ],
                          for (final t
                              in (chat.client?.tags ?? const <ChatTag>[]).take(
                                2,
                              )) ...[const SizedBox(width: 6), _TagChip(t)],
                          if (chat.hasPendingReminder) ...[
                            const SizedBox(width: 6),
                            Semantics(
                              label: 'Recordatorio pendiente',
                              child: ExcludeSemantics(
                                child: Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                  color: pf.text2,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: unread ? pf.text : pf.text2,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (last != null && last.isOutbound) ...[
                            MessageTicks(
                              status: last.ack,
                              color: pf.text2,
                              readColor: pf.link,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              preview.isEmpty ? 'Sin mensajes' : preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: unread ? pf.textMid : pf.text2,
                                fontWeight: unread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: chat.unreadCount),
                          ],
                        ],
                      ),
                      if (chips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: chips,
                          ),
                        ),
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

  List<Widget> _chips(BuildContext context, PfColors pf) {
    final out = <Widget>[];
    final last = chat.lastMessage;
    final since = last?.date ?? chat.lastMessageAt;
    if (last != null && last.isInbound && since != null) {
      out.add(
        _Chip(
          'Sin responder · ${relativeShort(since)}',
          bg: pf.warnBg,
          fg: pf.warnFg,
        ),
      );
    }
    final client = chat.client;
    if (client != null) {
      if (client.issuesCount > 0) {
        out.add(_Chip('Problema', bg: pf.errBg, fg: pf.errFg));
      }
      if (client.isPendingQuote) {
        out.add(
          _Chip(
            'Por cotizar',
            bg: pf.indicator,
            fg: pf.textMid,
            dot: PfColors.stagePorCotizar,
          ),
        );
      }
    }
    return out;
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.tag);

  final ChatTag tag;

  Color? get _dot {
    final c = tag.color?.replaceFirst('#', '');
    if (c == null || (c.length != 6 && c.length != 8)) return null;
    final v = int.tryParse(c, radix: 16);
    if (v == null) return null;
    return Color(c.length == 6 ? 0xFF000000 | v : v);
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final dot = _dot;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 76),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: pf.indicator,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pf.textMid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pf.mint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: count > 0
          ? Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pf.onMint,
              ),
            )
          : const SizedBox(width: 6, height: 6),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.bg, required this.fg, this.dot});

  final String label;
  final Color bg;
  final Color fg;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
