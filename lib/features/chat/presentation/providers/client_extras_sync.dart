import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_list_view_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';

/// Refleja etiquetas/problemas/recordatorio editados desde las hojas de
/// cliente. Con el hilo abierto delega en él (que también actualiza la lista);
/// desde el listado no abre el hilo (cargaría el historial): parchea la lista.
void applyClientExtras(
  WidgetRef ref,
  Chat chat, {
  List<ChatTag>? tags,
  int? issuesCount,
  bool? hasPendingReminder,
}) {
  final key = ChatKey(chat);
  if (ref.exists(chatThreadProvider(key))) {
    ref
        .read(chatThreadProvider(key).notifier)
        .applyClientExtras(
          tags: tags,
          issuesCount: issuesCount,
          hasPendingReminder: hasPendingReminder,
        );
    return;
  }
  final current = ref.read(chatsByIdProvider)[chat.id];
  if (current == null) return;
  final list = ref.read(chatListControllerProvider.notifier);
  list.replaceChat(
    current.copyWith(
      client: current.client?.copyWith(tags: tags, issuesCount: issuesCount),
      hasPendingReminder: hasPendingReminder,
    ),
  );
  list.poll();
}
