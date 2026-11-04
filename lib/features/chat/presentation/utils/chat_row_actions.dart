import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_actions_service.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_actions_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_client_sheets.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_reminders_sheet.dart';

/// Acciones de un chat desde su fila del listado (mantener presionado): la
/// misma hoja del detalle, pero sin abrir el hilo (no carga el historial).
/// Éxito -> se refleja en la lista; error -> snackbar.
Future<void> showChatRowActions(
  BuildContext context,
  WidgetRef ref,
  Chat chat,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final me = ref.read(apiUserProvider).value;
  final action = await showChatActionsSheet(
    context,
    chat: chat,
    myUserId: me?.id,
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case ChatAction.notes:
      return showClientNotesSheet(context, chat);
    case ChatAction.tags:
      return showClientTagsSheet(context, chat);
    case ChatAction.issues:
      return showClientIssuesSheet(context, chat);
    case ChatAction.reminder:
      return showClientRemindersSheet(context, chat);
    case ChatAction.copyPhone:
      final text = formatPhone(chat.phone).replaceAll(' ', '');
      if (text.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: text));
      _snack(messenger, 'Número copiado');
      return;
    default:
      break;
  }
  final o = await ref.read(chatActionsServiceProvider).perform(action, chat);
  if (o == null) return;
  if (o.ok && o.chat != null) {
    await ref
        .read(chatListControllerProvider.notifier)
        .applyLocalChange(o.chat!);
  }
  _snack(messenger, o.message);
}

void _snack(ScaffoldMessengerState m, String text) {
  if (text.isEmpty) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
