import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';

enum ChatAction {
  assign,
  release,
  resolve,
  unresolve,
  markUnread,
  archive,
  unarchive,
  notes,
  tags,
  issues,
  reminder,
}

/// Hoja de acciones. Devuelve la acción elegida o null.
Future<ChatAction?> showChatActionsSheet(
  BuildContext context, {
  required Chat chat,
  required String? myUserId,
}) {
  return showModalBottomSheet<ChatAction>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: PfColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ActionsSheet(chat: chat, myUserId: myUserId),
  );
}

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet({required this.chat, required this.myUserId});

  final Chat chat;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final client = chat.client;
    final responsible = client?.responsible;
    final mine = responsible != null && responsible.id == myUserId;
    final canAct = client?.id != null;

    final items = <_Item>[
      if (mine)
        _Item(
          'Liberar chat',
          Icons.person_remove_outlined,
          ChatAction.release,
          detail: 'Hoy: ${responsible.fullName}',
          enabled: canAct,
        )
      else
        _Item(
          'Asignarme el chat',
          Icons.person_add_alt_outlined,
          ChatAction.assign,
          detail: responsible == null
              ? 'Hoy: sin responsable'
              : 'Hoy: ${responsible.fullName}',
          enabled: canAct,
        ),
      if (client?.isChatResolved ?? false)
        _Item(
          'Marcar como por resolver',
          Icons.undo,
          ChatAction.unresolve,
          enabled: canAct,
        )
      else
        _Item(
          'Marcar como resuelto',
          Icons.check_circle_outline,
          ChatAction.resolve,
          enabled: canAct,
        ),
      _Item(
        'Marcar como no leído',
        Icons.mark_email_unread_outlined,
        ChatAction.markUnread,
      ),
      _Item(
        'Notas del cliente',
        Icons.sticky_note_2_outlined,
        ChatAction.notes,
        enabled: canAct,
      ),
      _Item(
        'Etiquetas',
        Icons.sell_outlined,
        ChatAction.tags,
        detail: (client?.tags.isEmpty ?? true)
            ? 'Sin etiquetas'
            : client!.tags.map((t) => t.name).join(', '),
        enabled: canAct,
      ),
      _Item(
        'Registrar problema',
        Icons.warning_amber_outlined,
        ChatAction.issues,
        detail: (client?.issuesCount ?? 0) > 0
            ? '${client!.issuesCount} activo${client.issuesCount == 1 ? '' : 's'}'
            : null,
        enabled: canAct,
      ),
      _Item(
        'Recordarme más tarde',
        Icons.schedule,
        ChatAction.reminder,
        detail: chat.hasPendingReminder
            ? 'Hay un recordatorio pendiente'
            : null,
        enabled: canAct,
      ),
      if (client != null && !client.isActive)
        _Item(
          'Desarchivar chat',
          Icons.unarchive_outlined,
          ChatAction.unarchive,
          enabled: canAct,
        )
      else
        _Item(
          'Archivar chat',
          Icons.archive_outlined,
          ChatAction.archive,
          enabled: canAct,
        ),
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          0,
          8,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  chatDisplayName(chat),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: pf.text2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            for (final i in items) _ActionRow(item: i),
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item(
    this.label,
    this.icon,
    this.action, {
    this.detail,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final ChatAction? action;
  final String? detail;
  final bool enabled;

  bool get comingSoon => action == null;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final enabled = !item.comingSoon && item.enabled;
    final color = enabled ? pf.text : pf.text2;
    final detail = item.comingSoon ? 'Próximamente' : item.detail;

    return Semantics(
      button: true,
      enabled: enabled,
      label: item.label,
      hint: detail,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => Navigator.pop(context, item.action) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(item.icon, size: 24, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pf.text2,
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
}
