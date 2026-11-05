import 'dart:typed_data';

import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/action_required_counts.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message_template.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/quick_answer.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';

/// Resultado de [ChatRepository.extendReminder].
enum ReminderExtendResult {
  /// Se creó el nuevo y se resolvió el original.
  done,

  /// Se creó el nuevo pero el original no se pudo resolver.
  createdOnly,
}

abstract class ChatRepository {
  /// [cancel] aborta el request en vuelo (la respuesta pasa a ser un error
  /// que el llamador debe descartar si `cancel.isCancelled`).
  Future<Result<ChatPage>> searchChats(ChatQuery query, {CancelSignal? cancel});

  /// Estados de cliente de la sucursal (`clients/statuses/`).
  Future<Result<List<String>>> clientStatuses();

  /// `page` es el número de página (0 = la más reciente), no un offset de ítems.
  Future<Result<List<Message>>> history(String phone, int page, int limit);

  /// Texto o media (`mediaFileId` = id devuelto por [uploadFile]); `quoteId`
  /// es el id del mensaje citado.
  Future<Result<SendOutcome>> sendMessage({
    required Chat chat,
    required String text,
    String? userId,
    String? quoteId,
    String? quoteBody,
    String? mediaFileId,
    String? mediaFileName,

    /// id local del mensaje optimista: el servidor lo persiste como
    /// `websocket_id` y lo devuelve en el POST y en el evento realtime.
    String? websocketId,
  });

  Future<Result<UploadedFile>> uploadFile({
    required Chat chat,
    required OutgoingAttachment file,
    void Function(double progress)? onProgress,
  });

  Future<Result<MediaPreview>> mediaPreview(
    RemoteMediaKind kind,
    String mediaId,
    String messageId,
  );

  /// null = el servidor no devolvió base64 (documentos grandes).
  Future<Result<Uint8List?>> mediaDownload(RemoteMediaKind kind, String id);

  Future<Result<List<QuickAnswer>>> quickAnswers();
  Future<Result<Uint8List>> downloadBytes(String url);

  Future<Result<List<MessageTemplate>>> templates();

  Future<Result<SendOutcome>> sendTemplate({
    required Chat chat,
    required MessageTemplate template,
    required Map<String, String> values,
    String? userId,
  });

  Future<Result<bool>> markRead(String chatId);
  Future<Result<bool>> markUnread(String chatId);

  /// Pedidos/clientes que requieren acción (`chat/summary/action-required-counts/`).
  Future<Result<ActionRequiredCounts>> actionRequiredCounts();

  /// PATCH de campos del cliente (el repositorio agrega `id`).
  Future<Result<bool>> updateClient(
    String clientId,
    Map<String, Object?> fields,
  );

  /// POST `agents/llm/order_taker/{phone}/`: Julia atiende ya el mensaje pendiente.
  Future<Result<bool>> triggerOrderTaker(String phone);

  /// true si el tenant usa la API oficial de WhatsApp (aplica la ventana de 24 h).
  Future<Result<bool>> usesWhatsappApi(String subsidiaryId);

  /// Pedido activo más reciente del cliente; null si no hay.
  Future<Result<OrderStrip?>> activeOrder(String clientId);

  // ---- Notas, etiquetas, problemas y recordatorio ----

  Future<Result<List<ClientNote>>> clientNotes(String clientId);
  Future<Result<bool>> addClientNote({
    required String clientId,
    required String userId,
    required String comment,
  });
  Future<Result<bool>> deleteClientNote(String id);

  Future<Result<List<ClientTag>>> allTags();
  Future<Result<List<ClientTag>>> clientTags(String clientId);

  /// El servidor alterna la asignación (no hay body).
  Future<Result<bool>> toggleTag(String tagId, String clientId);

  Future<Result<List<ClientIssue>>> clientIssues(String clientId);
  Future<Result<bool>> createIssue({
    required String clientId,
    required String type,
    String? comment,
  });
  Future<Result<bool>> resolveIssue(String id);

  Future<Result<bool>> createReminder({
    required String chatId,
    required String userId,
    required String unit,
    required int time,
    required String comment,
  });

  /// Recordatorios pendientes (no resueltos) del chat.
  Future<Result<List<Reminder>>> pendingReminders(String chatId);

  Future<Result<bool>> resolveReminder(String id);

  /// Reprograma [reminder] para dentro de [minutes]. SAPI solo extiende +5 min
  /// (`extend-reminder` ignora el body), así que se crea uno nuevo con el mismo
  /// texto y se resuelve el original.
  ///
  /// [chatId] es el respaldo si el recordatorio no trae chat. Un fallo plano
  /// significa que no se creó nada (reintentar es seguro); si se creó el nuevo
  /// pero no se pudo resolver el original, éxito parcial
  /// ([ReminderExtendResult.createdOnly]): reintentar duplicaría.
  Future<Result<ReminderExtendResult>> extendReminder({
    required Reminder reminder,
    required String userId,
    required int minutes,
    String? chatId,
  });
}
