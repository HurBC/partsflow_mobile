import 'dart:async';

import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message_template.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_thread_controller.g.dart';

/// Mensaje de sistema local (p. ej. cambios de Julia).
class ThreadNote {
  const ThreadNote(this.date, this.text);
  final DateTime date;
  final String text;
}

class ThreadState {
  const ThreadState({
    required this.chat,
    this.messages = const [],
    this.pending = const [],
    this.notes = const [],
    this.status = ListStatus.loading,
    this.error,
    this.loadingOlder = false,
    this.hasMoreOlder = false,
    this.nextPage = 1,
    this.order,
    this.historyLoaded = false,
    this.replyTo,
  });

  final Chat chat;
  final List<Message> messages;
  final List<Message> pending;
  final List<ThreadNote> notes;
  final ListStatus status;
  final String? error;
  final bool loadingOlder;
  final bool hasMoreOlder;
  final int nextPage;
  final OrderStrip? order;
  final bool historyLoaded;

  /// Mensaje que se está citando en el composer.
  final Message? replyTo;

  ThreadState copyWith({
    Chat? chat,
    List<Message>? messages,
    List<Message>? pending,
    List<ThreadNote>? notes,
    ListStatus? status,
    String? error,
    bool clearError = false,
    bool? loadingOlder,
    bool? hasMoreOlder,
    int? nextPage,
    OrderStrip? order,
    bool? historyLoaded,
    Message? replyTo,
    bool clearReply = false,
  }) => ThreadState(
    chat: chat ?? this.chat,
    messages: messages ?? this.messages,
    pending: pending ?? this.pending,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
    nextPage: nextPage ?? this.nextPage,
    order: order ?? this.order,
    historyLoaded: historyLoaded ?? this.historyLoaded,
    replyTo: clearReply ? null : (replyTo ?? this.replyTo),
  );

  /// Último mensaje entrante conocido (historial o dato del chat).
  DateTime? get lastInboundAt {
    DateTime? best = chat.lastInboundMessageAt;
    for (final m in messages) {
      if (m.isInbound && (best == null || m.date.isAfter(best))) best = m.date;
    }
    return best;
  }
}

typedef ActionResult = ({bool ok, String message});

List<Message> _merge(List<Message> a, List<Message> b) {
  final byId = {for (final m in a) m.id: m};
  for (final m in b) {
    byId[m.id] = m;
  }
  final out = byId.values.toList()..sort((x, y) => x.date.compareTo(y.date));
  return out;
}

/// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
/// instancia se crea con el Chat recibido por `extra` desde la lista.
@riverpod
class ChatThread extends _$ChatThread {
  int _localSeq = 0;
  Timer? _rtTimer;

  @override
  ThreadState build(Chat chat) {
    final sub = ref.read(realtimeProvider.notifier).events.listen(_onRealtime);
    ref.onDispose(() {
      sub.cancel();
      _rtTimer?.cancel();
    });
    Future.microtask(() async {
      if (!ref.mounted) return;
      _loadOrder();
      await _loadFirstPage();
      if (ref.mounted) _markReadIfNeeded();
    });
    return ThreadState(chat: chat);
  }

  Future<ApiUser?> _me() => ref.read(apiUserProvider.future);

  Future<void> _loadFirstPage() async {
    final r = await ref
        .read(chatRepositoryProvider)
        .history(state.chat.phone, 0, chatPageSize);
    if (!ref.mounted) return;
    switch (r) {
      case Ok(:final value):
        state = state.copyWith(
          messages: _merge(state.messages, value),
          status: ListStatus.data,
          historyLoaded: true,
          // Si la primera página vino llena, puede haber más atrás.
          hasMoreOlder: state.historyLoaded
              ? state.hasMoreOlder
              : value.length >= chatPageSize,
          clearError: true,
        );
      case Err(:final failure):
        if (state.status != ListStatus.data) {
          state = state.copyWith(
            status: ListStatus.error,
            error: failureMessage(failure),
          );
        }
    }
  }

  Future<void> retry() async {
    state = state.copyWith(status: ListStatus.loading, clearError: true);
    await _loadFirstPage();
    if (ref.mounted) _markReadIfNeeded();
  }

  /// Sondeo: trae la primera página y la mezcla.
  Future<void> poll() async {
    if (state.status != ListStatus.data) return;
    await _loadFirstPage();
  }

  // ---- Tiempo real ---------------------------------------------------------

  void _onRealtime(RealtimeEvent e) {
    if (!ref.mounted) return;
    final chat = state.chat;
    switch (e) {
      case RealtimeResync():
        _scheduleReload();
      case RealtimeNewMessages(:final items):
        // El canal trae los mensajes de todo el subsidiary: solo los de este
        // chat; si no se puede determinar el teléfono, se recarga por si acaso.
        final mine = items.where((i) {
          final p = phoneOfItem(i);
          return p == null || p == phoneDigits(chat.phone);
        });
        if (mine.isNotEmpty) _scheduleReload();
      case RealtimeStatusUpdates(:final items):
        _applyStatusUpdates(items);
      case RealtimeClientChanged(:final data):
        _applyClientEvent(data);
    }
  }

  /// Recarga la primera página (mezclada) con un pequeño agrupamiento.
  void _scheduleReload() {
    if (_rtTimer?.isActive ?? false) return;
    _rtTimer = Timer(const Duration(milliseconds: 400), () {
      if (ref.mounted && state.status == ListStatus.data) _loadFirstPage();
    });
  }

  void _applyStatusUpdates(List<Map<String, dynamic>> items) {
    final byId = <String, String>{};
    for (final i in items) {
      final id = nonEmpty(asStr(i['websocket_id'])) ?? nonEmpty(asStr(i['id']));
      final st = nonEmpty(asStr(i['status']));
      if (id != null && st != null) byId[id] = st;
    }
    if (byId.isEmpty) return;
    var changed = false;
    final next = [
      for (final m in state.messages)
        if ((byId[m.websocketId] ?? byId[m.id]) case final st?
            when st != m.status)
          () {
            changed = true;
            return m.copyWith(status: st);
          }()
        else
          m,
    ];
    if (changed) state = state.copyWith(messages: next);
  }

  void _applyClientEvent(Map<String, dynamic> d) {
    final c = state.chat;
    final cl = c.client;
    if (cl == null) return;
    final sameId = d['id'] != null && asStr(d['id']) == cl.id;
    final phone = phoneOfItem(d);
    if (!sameId && (phone == null || phone != phoneDigits(c.phone))) return;

    final mode = nonEmpty(asStr(d['operation_mode']));
    final ai = asBool(d['is_ai_active']);
    final resolved = asBool(d['is_chat_resolved']);
    final active = asBool(d['is_active']);
    ChatResponsible? resp;
    var clearResp = false;
    final rMap = asMap(d['responsible']);
    if (rMap != null && rMap['id'] != null) {
      resp = ChatResponsible(
        id: asStr(rMap['id']) ?? '',
        firstName: asStr(rMap['first_name']) ?? '',
        lastName: asStr(rMap['last_name']) ?? '',
      );
    } else if (d.containsKey('responsible_id')) {
      if (d['responsible_id'] == null) {
        clearResp = true;
      } else {
        resp = ChatResponsible(
          id: asStr(d['responsible_id']) ?? '',
          firstName: asStr(d['responsible_first_name']) ?? '',
          lastName: asStr(d['responsible_last_name']) ?? '',
        );
      }
    } else if (d.containsKey('responsible') && d['responsible'] == null) {
      clearResp = true;
    }
    if (mode == null &&
        ai == null &&
        resolved == null &&
        active == null &&
        resp == null &&
        !clearResp) {
      return;
    }
    _setChat(
      c.copyWith(
        client: cl.copyWith(
          operationMode: mode,
          isAiActive: ai ?? (mode == null ? null : mode == 'automatic'),
          isChatResolved: resolved,
          isActive: active,
          responsible: resp,
          clearResponsible: clearResp,
        ),
      ),
    );
  }

  Future<void> loadOlder() async {
    final s = state;
    if (!s.hasMoreOlder || s.loadingOlder || s.status != ListStatus.data) {
      return;
    }
    state = s.copyWith(loadingOlder: true);
    final r = await ref
        .read(chatRepositoryProvider)
        .history(s.chat.phone, s.nextPage, chatPageSize);
    if (!ref.mounted) return;
    switch (r) {
      case Ok(:final value):
        final known = state.messages.map((m) => m.id).toSet();
        final fresh = value.where((m) => !known.contains(m.id)).toList();
        state = state.copyWith(
          messages: _merge(state.messages, value),
          nextPage: s.nextPage + 1,
          // Una página sin mensajes nuevos corta la paginación.
          hasMoreOlder: value.length >= chatPageSize && fresh.isNotEmpty,
          loadingOlder: false,
        );
      case Err():
        state = state.copyWith(loadingOlder: false);
    }
  }

  Future<void> _loadOrder() async {
    final clientId = state.chat.client?.id;
    if (clientId == null) return;
    final r = await ref.read(chatRepositoryProvider).activeOrder(clientId);
    if (!ref.mounted) return;
    if (r case Ok(:final value) when value != null) {
      state = state.copyWith(order: value);
    }
  }

  Future<void> _markReadIfNeeded() async {
    final c = state.chat;
    if (!c.hasUnread) return;
    final r = await ref.read(chatRepositoryProvider).markRead(c.id);
    if (!ref.mounted) return;
    if (r is Ok) {
      _setChat(c.copyWith(unreadCount: 0, isUnread: false));
    }
  }

  void _setChat(Chat chat) {
    state = state.copyWith(chat: chat);
    ref.read(chatListControllerProvider.notifier).replaceChat(chat);
  }

  void _note(String text) {
    state = state.copyWith(
      notes: [...state.notes, ThreadNote(DateTime.now(), text)],
    );
  }

  // ---- Envío -------------------------------------------------------------

  static const maxUploadBytes = 16 * 1024 * 1024;
  static const maxBatch = 10;

  final _jobs = <String, _SendJob>{};
  final _uploads = <String, Future<String?>>{};
  final _gate = _Gate(3);

  void setReply(Message? m) {
    state = m == null
        ? state.copyWith(clearReply: true)
        : state.copyWith(replyTo: m);
  }

  /// Toma (y limpia) la cita actual.
  ({String? id, String? body, Message? msg}) _takeReply() {
    final r = state.replyTo;
    if (r == null) return (id: null, body: null, msg: null);
    state = state.copyWith(clearReply: true);
    return (id: r.isLocal ? null : r.replyId, body: r.quoteBody, msg: r);
  }

  Message _local({
    required String? userId,
    String? text,
    String type = 'text',
    OutgoingAttachment? file,
    Message? reply,
  }) => Message(
    id: 'local-${DateTime.now().microsecondsSinceEpoch}-${_localSeq++}',
    date: DateTime.now(),
    type: type,
    flow: 'outbound',
    text: text,
    status: 'temp',
    responsibleId: userId,
    isLocal: true,
    localPath: file?.path,
    mediaFilename: file?.name,
    mediaMime: file?.mime,
    uploadProgress: file == null ? null : 0,
    quotedBody: reply?.quoteBody,
    quotedFrom: reply == null ? null : 'Tú',
    quotedType: reply?.type,
  );

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final me = await _me();
    if (!ref.mounted) return;
    final reply = _takeReply();
    final local = _local(userId: me?.id, text: body, reply: reply.msg);
    _jobs[local.id] = _SendJob(
      text: body,
      quoteId: reply.id,
      quoteBody: reply.body,
    );
    state = state.copyWith(pending: [...state.pending, local]);
    await _deliver(local.id, me);
  }

  /// Un mensaje por archivo (la leyenda solo en el primero). Hasta 3 subidas
  /// en paralelo; los envíos salen en orden.
  Future<void> sendAttachments(
    List<OutgoingAttachment> files,
    String caption,
  ) async {
    if (files.isEmpty) return;
    final me = await _me();
    if (!ref.mounted) return;
    final reply = _takeReply();
    final ids = <String>[];
    final locals = <Message>[];
    for (var i = 0; i < files.length && i < maxBatch; i++) {
      final f = files[i];
      final cap = i == 0 ? caption.trim() : '';
      pfLog(
        'adjunto ${i + 1}/${files.length}: file=${f.name} mime=${f.mime} '
        'kind=${f.kind.name} bytes=${f.size} phone=${maskPhoneForLog(state.chat.phone)}',
      );
      // Reglas de contrato: documento sin leyenda → nombre; audio → vacío.
      final text = f.kind == AttachmentKind.audio
          ? ''
          : (cap.isNotEmpty
                ? cap
                : (f.kind == AttachmentKind.document ? f.name : ''));
      final local = _local(
        userId: me?.id,
        text: f.kind == AttachmentKind.document && cap.isEmpty ? null : cap,
        type: f.kind.name,
        file: f,
        reply: i == 0 ? reply.msg : null,
      );
      _jobs[local.id] = _SendJob(
        text: text,
        file: f,
        quoteId: i == 0 ? reply.id : null,
        quoteBody: i == 0 ? reply.body : null,
      );
      locals.add(local);
      ids.add(local.id);
    }
    state = state.copyWith(pending: [...state.pending, ...locals]);
    for (final id in ids) {
      _ensureUploaded(id);
    }
    for (final id in ids) {
      if (!ref.mounted) return;
      await _deliver(id, me);
    }
  }

  /// Reintenta un mensaje local que falló.
  Future<void> retrySend(String localId) async {
    if (!state.pending.any((m) => m.id == localId)) return;
    final me = await _me();
    if (!ref.mounted) return;
    _replacePending(
      localId,
      (m) => m.copyWith(status: 'temp', clearError: true),
    );
    await _deliver(localId, me);
  }

  void discardPending(String localId) {
    _jobs.remove(localId);
    _uploads.remove(localId);
    state = state.copyWith(
      pending: state.pending.where((m) => m.id != localId).toList(),
    );
  }

  void _replacePending(String id, Message Function(Message) f) {
    state = state.copyWith(
      pending: [for (final m in state.pending) m.id == id ? f(m) : m],
    );
  }

  /// Sube el archivo del job (una sola vez). Devuelve el error o null.
  Future<String?> _ensureUploaded(String id) {
    final job = _jobs[id];
    if (job == null || job.file == null || job.fileId != null) {
      return Future.value(null);
    }
    return _uploads[id] ??= _gate.run(() async {
      if (!ref.mounted) return 'cancelado';
      final r = await ref
          .read(chatRepositoryProvider)
          .uploadFile(
            chat: state.chat,
            file: job.file!,
            onProgress: (p) {
              if (!ref.mounted) return;
              _replacePending(id, (m) => m.copyWith(uploadProgress: p));
            },
          );
      _uploads.remove(id);
      if (!ref.mounted) return 'cancelado';
      switch (r) {
        case Ok(:final value):
          job.fileId = value.fileId;
          _replacePending(id, (m) => m.copyWith(clearProgress: true));
          return null;
        case Err(:final failure):
          return _reasonText(failure, 'subir', job.file!.kind);
      }
    });
  }

  static String _kindNoun(AttachmentKind? k) => switch (k) {
    AttachmentKind.audio => 'el audio',
    AttachmentKind.image => 'la imagen',
    AttachmentKind.video => 'el video',
    AttachmentKind.document => 'el documento',
    null => 'el mensaje',
  };

  /// "No se pudo subir el audio (HTTP 400: detalle)"; el detalle completo va
  /// al log (pfLog).
  static String _reasonText(Failure f, String verb, AttachmentKind? k) {
    final what = _kindNoun(k);
    return switch (f) {
      NetworkFailure() => 'Sin conexión. Revisa tu internet.',
      HttpFailure(:final reason) => 'No se pudo $verb $what ($reason)',
      ServerFailure() => 'No se pudo $verb $what (error del servidor)',
      UnauthorizatedFailure() => 'No se pudo $verb $what (sesión expirada)',
      _ => 'No se pudo $verb $what',
    };
  }

  Future<void> _deliver(String localId, ApiUser? me) async {
    final job = _jobs[localId];
    if (job == null) return;
    String? error = await _ensureUploaded(localId);
    if (!ref.mounted) return;
    if (error == null) {
      final wasAutomatic = state.chat.client?.operationMode == 'automatic';
      final isAudio = job.file?.kind == AttachmentKind.audio;
      final r = await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chat: state.chat,
            text: job.text,
            userId: me?.id,
            quoteId: job.quoteId,
            quoteBody: job.quoteBody,
            mediaFileId: job.fileId,
            mediaFileName: job.file == null
                ? null
                : (isAudio ? '' : job.file!.name),
          );
      if (!ref.mounted) return;
      switch (r) {
        case Ok(:final value):
          switch (value.status) {
            case SendStatus.sent:
              if (wasAutomatic && state.chat.client != null) {
                // El envío pasó el chat a manual (Julia en pausa).
                _setChat(
                  state.chat.copyWith(
                    client: state.chat.client!.copyWith(
                      operationMode: 'manual',
                      isAiActive: false,
                    ),
                  ),
                );
                _note('Tomaste el chat · Julia en pausa');
              }
            case SendStatus.suppressed:
              error = 'No se pudo enviar por este canal';
            case SendStatus.conflict:
              error = 'Este cliente está asignado a otro operador';
            case SendStatus.rejected:
              final what = _kindNoun(job.file?.kind);
              error = value.detail == null
                  ? 'No se pudo enviar $what'
                  : 'No se pudo enviar $what (${value.detail})';
          }
        case Err(:final failure):
          error = _reasonText(failure, 'enviar', job.file?.kind);
      }
    }
    if (error != null) {
      pfLog('adjunto/mensaje con error visible: $error');
      _replacePending(
        localId,
        (m) =>
            m.copyWith(status: 'error', errorText: error, clearProgress: true),
      );
      return;
    }
    await _loadFirstPage();
    if (!ref.mounted) return;
    _jobs.remove(localId);
    state = state.copyWith(
      pending: state.pending.where((m) => m.id != localId).toList(),
    );
    ref.read(chatListControllerProvider.notifier).poll();
  }

  /// Envía una plantilla (sin mensaje optimista: se ve al recargar).
  Future<ActionResult> sendTemplate(
    MessageTemplate template,
    Map<String, String> values,
  ) async {
    final me = await _me();
    if (!ref.mounted) return (ok: false, message: '');
    final r = await ref
        .read(chatRepositoryProvider)
        .sendTemplate(
          chat: state.chat,
          template: template,
          values: values,
          userId: me?.id,
        );
    if (!ref.mounted) return (ok: false, message: '');
    switch (r) {
      case Ok(:final value) when value.ok:
        await _loadFirstPage();
        if (ref.mounted) ref.read(chatListControllerProvider.notifier).poll();
        return (ok: true, message: 'Plantilla enviada');
      case Ok(:final value) when value.status == SendStatus.conflict:
        return (
          ok: false,
          message: 'Este cliente está asignado a otro operador',
        );
      case Ok():
        return (ok: false, message: 'No se pudo enviar la plantilla');
      case Err(:final failure):
        return (
          ok: false,
          message: failureMessage(failure).startsWith('Sin conexión')
              ? 'Sin conexión. Revisa tu internet.'
              : 'No se pudo enviar la plantilla',
        );
    }
  }

  // ---- Acciones ------------------------------------------------------------

  Future<ActionResult> _patch(
    Map<String, Object?> fields,
    Chat Function(Chat, ApiUser?) apply,
    String okMessage, {
    bool needsUser = false,
  }) async {
    final clientId = state.chat.client?.id;
    if (clientId == null) {
      return (ok: false, message: 'No se pudo completar la acción');
    }
    final me = await _me();
    if (!ref.mounted) return (ok: false, message: '');
    if (needsUser && me == null) {
      ref.invalidate(apiUserProvider);
      return (ok: false, message: 'No pudimos identificar tu usuario');
    }
    final fieldsFinal = fields.map(
      (k, v) => MapEntry(k, v == #me ? me?.id : v),
    );
    final r = await ref
        .read(chatRepositoryProvider)
        .updateClient(clientId, fieldsFinal);
    if (!ref.mounted) return (ok: false, message: '');
    switch (r) {
      case Ok():
        _setChat(apply(state.chat, me));
        ref.read(chatListControllerProvider.notifier).poll();
        return (ok: true, message: okMessage);
      case Err(:final failure):
        final offline = failureMessage(failure).startsWith('Sin conexión');
        return (
          ok: false,
          message: offline
              ? 'Sin conexión. Revisa tu internet.'
              : 'No se pudo completar la acción',
        );
    }
  }

  /// Refleja en el chat (y la lista) etiquetas/problemas/recordatorio tras
  /// editarlos desde las hojas de acciones.
  void applyClientExtras({
    List<ChatTag>? tags,
    int? issuesCount,
    bool? hasPendingReminder,
  }) {
    final c = state.chat;
    _setChat(
      c.copyWith(
        client: c.client?.copyWith(tags: tags, issuesCount: issuesCount),
        hasPendingReminder: hasPendingReminder,
      ),
    );
    ref.read(chatListControllerProvider.notifier).poll();
  }

  Future<ActionResult> setJulia(bool on) async {
    final res = await _patch(
      {
        'operation_mode': on ? 'automatic' : 'manual',
        'operation_source': 'backoffice',
      },
      (c, _) => c.copyWith(
        client: c.client!.copyWith(
          operationMode: on ? 'automatic' : 'manual',
          isAiActive: on,
        ),
      ),
      on ? 'Julia activada' : 'Julia en pausa',
    );
    if (res.ok && ref.mounted) {
      _note(on ? 'Julia activada' : 'Julia en pausa');
    }
    return res;
  }

  /// Igual que el BO (ChatDetailTobBar.tsx): PATCH clients/{id}/update/ con
  /// `importance_level` 'high' (importante) o 'none'.
  Future<ActionResult> setImportant(bool important) => _patch(
    {'importance_level': important ? 'high' : 'none'},
    (c, _) => c.copyWith(client: c.client!.copyWith(isImportant: important)),
    important
        ? 'Cliente marcado como importante'
        : 'Cliente ya no es importante',
  );

  Future<ActionResult> assignToMe() => _patch(
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

  Future<ActionResult> release() => _patch(
    {'responsible': null},
    (c, _) => c.copyWith(client: c.client!.copyWith(clearResponsible: true)),
    'Chat liberado',
  );

  Future<ActionResult> setResolved(bool resolved) => _patch(
    {'is_chat_resolved': resolved},
    (c, _) => c.copyWith(client: c.client!.copyWith(isChatResolved: resolved)),
    resolved ? 'Chat marcado como resuelto' : 'Chat marcado por resolver',
  );

  Future<ActionResult> setArchived(bool archived) => _patch(
    {'is_active': !archived},
    (c, _) => c.copyWith(client: c.client!.copyWith(isActive: !archived)),
    archived ? 'Chat archivado' : 'Chat desarchivado',
  );

  Future<ActionResult> markUnread() async {
    final r = await ref.read(chatRepositoryProvider).markUnread(state.chat.id);
    if (!ref.mounted) return (ok: false, message: '');
    if (r case Ok(value: true)) {
      _setChat(state.chat.copyWith(isUnread: true));
      ref.read(chatListControllerProvider.notifier).poll();
      return (ok: true, message: 'Chat marcado como no leído');
    }
    return (ok: false, message: 'No se pudo completar la acción');
  }
}

class _SendJob {
  _SendJob({required this.text, this.file, this.quoteId, this.quoteBody});

  final String text;
  final OutgoingAttachment? file;
  final String? quoteId;
  final String? quoteBody;
  String? fileId;
}

/// Limita la concurrencia de las subidas.
class _Gate {
  _Gate(this._max);

  final int _max;
  int _running = 0;
  final _waiters = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= _max) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    } else {
      _running++;
    }
    try {
      return await task();
    } finally {
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }
}
