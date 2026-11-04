import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_actions_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resultado de una acción sobre un chat. [chat] es el chat ya actualizado
/// (solo si [ok]); el llamador decide dónde reflejarlo (hilo, lista).
class ChatActionOutcome {
  const ChatActionOutcome({required this.ok, required this.message, this.chat});

  final bool ok;
  final String message;
  final Chat? chat;
}

/// Acciones de cliente/chat que no dependen del hilo (no abre su provider ni
/// carga historial): PATCH `clients/{id}/update/` y `chat/mark_unread/`.
/// Lo usan el detalle y el listado.
class ChatActionsService {
  ChatActionsService({
    required this.repository,
    required this.currentUser,
    required this.onUserMissing,
  });

  final ChatRepository repository;
  final Future<ApiUser?> Function() currentUser;

  /// Se invoca si no se pudo identificar al usuario (para reintentar la carga).
  final void Function() onUserMissing;

  static const _fail = 'No se pudo completar la acción';

  /// PATCH genérico del cliente. En [fields], `#me` se reemplaza por el id del
  /// usuario actual.
  Future<ChatActionOutcome> patchClient(
    Chat chat,
    Map<String, Object?> fields,
    Chat Function(Chat, ApiUser?) apply,
    String okMessage, {
    bool needsUser = false,
  }) async {
    final clientId = chat.client?.id;
    if (clientId == null) {
      return const ChatActionOutcome(ok: false, message: _fail);
    }
    final me = await currentUser();
    if (needsUser && me == null) {
      onUserMissing();
      return const ChatActionOutcome(
        ok: false,
        message: 'No pudimos identificar tu usuario',
      );
    }
    final body = fields.map((k, v) => MapEntry(k, v == #me ? me?.id : v));
    final r = await repository.updateClient(clientId, body);
    return switch (r) {
      Ok() => ChatActionOutcome(
        ok: true,
        message: okMessage,
        chat: apply(chat, me),
      ),
      Err(:final failure) => ChatActionOutcome(
        ok: false,
        message: failureMessage(failure).startsWith('Sin conexión')
            ? 'Sin conexión. Revisa tu internet.'
            : _fail,
      ),
    };
  }

  /// Igual que el BO (ChatDetailTobBar.tsx): `importance_level` 'high' o 'none'.
  Future<ChatActionOutcome> setImportant(Chat chat, bool important) =>
      patchClient(
        chat,
        {'importance_level': important ? 'high' : 'none'},
        (c, _) =>
            c.copyWith(client: c.client!.copyWith(isImportant: important)),
        important
            ? 'Cliente marcado como importante'
            : 'Cliente ya no es importante',
      );

  Future<ChatActionOutcome> assignToMe(Chat chat) => patchClient(
    chat,
    {'responsible': #me},
    (c, me) => c.copyWith(
      client: c.client!.copyWith(
        responsible: ChatResponsible(
          id: me!.id,
          firstName: me.firstName,
          lastName: me.lastName,
        ),
      ),
    ),
    'Chat asignado a ti',
    needsUser: true,
  );

  Future<ChatActionOutcome> release(Chat chat) => patchClient(
    chat,
    {'responsible': null},
    (c, _) => c.copyWith(client: c.client!.copyWith(clearResponsible: true)),
    'Chat liberado',
  );

  Future<ChatActionOutcome> setResolved(Chat chat, bool resolved) =>
      patchClient(
        chat,
        {'is_chat_resolved': resolved},
        (c, _) =>
            c.copyWith(client: c.client!.copyWith(isChatResolved: resolved)),
        resolved ? 'Chat marcado como resuelto' : 'Chat marcado por resolver',
      );

  Future<ChatActionOutcome> setArchived(Chat chat, bool archived) =>
      patchClient(
        chat,
        {'is_active': !archived},
        (c, _) => c.copyWith(client: c.client!.copyWith(isActive: !archived)),
        archived ? 'Chat archivado' : 'Chat desarchivado',
      );

  Future<ChatActionOutcome> markUnread(Chat chat) async {
    final r = await repository.markUnread(chat.id);
    if (r case Ok(value: true)) {
      return ChatActionOutcome(
        ok: true,
        message: 'Chat marcado como no leído',
        chat: chat.copyWith(isUnread: true),
      );
    }
    return const ChatActionOutcome(ok: false, message: _fail);
  }

  /// Ejecuta una de las acciones de la hoja que llaman al servidor. Las demás
  /// (notas, etiquetas, problemas, recordatorio, copiar) las resuelve la UI.
  Future<ChatActionOutcome?> perform(ChatAction action, Chat chat) =>
      switch (action) {
        ChatAction.assign => assignToMe(chat),
        ChatAction.release => release(chat),
        ChatAction.important => setImportant(
          chat,
          !(chat.client?.isImportant ?? false),
        ),
        ChatAction.resolve => setResolved(chat, true),
        ChatAction.unresolve => setResolved(chat, false),
        ChatAction.markUnread => markUnread(chat),
        ChatAction.archive => setArchived(chat, true),
        ChatAction.unarchive => setArchived(chat, false),
        _ => Future.value(null),
      };
}

final chatActionsServiceProvider = Provider<ChatActionsService>(
  (ref) => ChatActionsService(
    repository: ref.watch(chatRepositoryProvider),
    currentUser: () => ref.read(apiUserProvider.future),
    onUserMissing: () => ref.invalidate(apiUserProvider),
  ),
);
