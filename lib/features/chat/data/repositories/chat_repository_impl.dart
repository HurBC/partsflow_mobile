import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message_template.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/quick_answer.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._remote);

  final ChatRemoteDataSource _remote;

  Failure _fail(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (e.response == null) return Failure.network();
      if (status == 401) return Failure.unauthorization();
      if (status != null && status >= 500) return Failure.server();
    }
    return Failure.unknown();
  }

  /// Como [_fail] pero conserva el motivo (status + detalle) para la UI.
  Failure _failReason(Object e) {
    pfLog('error ${e.runtimeType}: ${truncateLog(e)}');
    if (e is DioException) {
      if (e.response == null) return Failure.network();
      if (e.response?.statusCode == 401) return Failure.unauthorization();
      return Failure.http(e.response?.statusCode, httpReason(e));
    }
    return Failure.http(null, shortError(e));
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Result.ok(await run());
    } catch (e) {
      return Result.err(_fail(e));
    }
  }

  @override
  Future<Result<ChatPage>> searchChats(ChatQuery q) => _guard(() async {
    final p = <String, dynamic>{
      'size': 50,
      'include': 'lastMessage',
      'status': 'active,pending',
    };
    switch (q.tab) {
      case ChatTab.pending:
        p.addAll({'pending': 'true', 'resolved': 'false', 'is_active': 'true'});
      case ChatTab.assigned:
        p.addAll({
          'client_responsible': q.userId,
          'resolved': 'false',
          'pending': 'false',
        });
      case ChatTab.all:
        p.addAll({'resolved': 'false', 'pending': 'false', 'issues': 'false'});
      case ChatTab.issues:
        p.addAll({'issues': 'true', 'resolved': 'false', 'pending': 'false'});
      case ChatTab.resolved:
        p.addAll({'resolved': 'true', 'pending': 'false', 'issues': 'false'});
      case ChatTab.archived:
        p.addAll({
          'is_active': 'false',
          'resolved': 'false',
          'pending': 'false',
        });
    }
    p.addAll(q.advanced.toParams());
    final text = q.searchText.trim();
    if (text.isNotEmpty) {
      final prefix = q.searchMode.prefix;
      p['search'] = prefix == null ? text : '$prefix,$text';
    }
    if (q.cursor != null) {
      p['last_message_timestamp'] = q.cursor;
      if (q.cursorId != null) p['last_message_id'] = q.cursorId;
    }

    final data = await _remote.searchChats(p);
    final map = asMap(data);
    final rawChats = data is List ? data : asList(map?['chats']);
    final chats = <Chat>[];
    for (final raw in rawChats) {
      final c = chatFromJson(raw);
      if (c != null) chats.add(c);
    }
    final pg = asMap(map?['pagination']);
    return ChatPage(
      chats: chats,
      hasMore: asBool(pg?['has_more']) ?? false,
      cursor: asStr(pg?['next_cursor']),
      cursorId: asStr(pg?['next_cursor_id']),
    );
  });

  @override
  Future<Result<List<String>>> clientStatuses() => _guard(() async {
    final data = await _remote.clientStatuses();
    final raw = data is List ? data : asList(asMap(data)?['results']);
    return [
      for (final r in raw)
        if (nonEmpty(asStr(r)) != null) asStr(r)!.trim(),
    ];
  });

  @override
  Future<Result<List<Message>>> history(String phone, int page, int limit) =>
      _guard(() async {
        final data = await _remote.history(phone, page, limit);
        final raw = data is List ? data : asList(asMap(data)?['results']);
        final out = <Message>[];
        for (final r in raw) {
          final m = messageFromJson(r);
          if (m != null) out.add(m);
        }
        return out;
      });

  @override
  Future<Result<SendOutcome>> sendMessage({
    required Chat chat,
    required String text,
    String? userId,
    String? quoteId,
    String? quoteBody,
    String? mediaFileId,
    String? mediaFileName,
  }) async {
    try {
      final client = chat.client;
      if (client?.operationMode == 'automatic' && client?.id != null) {
        await _remote.updateClient(client!.id!, {
          'id': client.id,
          'operation_mode': 'manual',
          'operation_source': 'backoffice',
        });
      }
      final (status, body) = await _remote.sendMessage({
        'phone': chat.phone,
        'is_group': false,
        'message': text,
        'chat_id': chat.phone,
        'quote_body': quoteBody ?? 'text',
        'quote': ?quoteId,
        if (mediaFileId != null)
          'media': {'file': mediaFileId, 'file_name': mediaFileName ?? ''},
        'responsible_id': ?userId,
        'reference': 'backoffice',
      });
      if (asBool(asMap(body)?['suppressed']) == true) {
        return Result.ok(const SendOutcome(SendStatus.suppressed));
      }
      if (status != 201 && status != 200) {
        return Result.ok(SendOutcome(SendStatus.rejected, 'HTTP $status'));
      }
      try {
        await _remote.setLastSellerMessage(chat.phone);
      } catch (e) {
        pfLog('set_last_seller_message falló (ignorado): ${truncateLog(e)}');
      }
      return Result.ok(const SendOutcome(SendStatus.sent));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409) {
        return Result.ok(const SendOutcome(SendStatus.conflict));
      }
      if (status == 400) {
        return Result.ok(SendOutcome(SendStatus.rejected, httpReason(e)));
      }
      return Result.err(_failReason(e));
    } catch (e) {
      return Result.err(_failReason(e));
    }
  }

  @override
  Future<Result<bool>> markRead(String chatId) => _guard(() async {
    await _remote.readChat(chatId);
    return true;
  });

  @override
  Future<Result<bool>> markUnread(String chatId) =>
      _guard(() async => (await _remote.markUnread(chatId)) == 200);

  @override
  Future<Result<bool>> updateClient(
    String clientId,
    Map<String, Object?> fields,
  ) => _guard(() async {
    await _remote.updateClient(clientId, {'id': clientId, ...fields});
    return true;
  });

  @override
  Future<Result<bool>> usesWhatsappApi(String subsidiaryId) => _guard(() async {
    final data = asMap(await _remote.supplier(subsidiaryId));
    final configs = asList(data?['configs']);
    if (configs.isEmpty) return false;
    return asStr(asMap(configs.first)?['whatsapp_service_type']) == 'api';
  });

  @override
  Future<Result<OrderStrip?>> activeOrder(String clientId) => _guard(
    () async => orderStripFromJson(await _remote.activeOrders(clientId)),
  );

  // ---- Extras (Fase 5A) -----------------------------------------------------

  @override
  Future<Result<UploadedFile>> uploadFile({
    required Chat chat,
    required OutgoingAttachment file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return Result.ok(await _upload(chat, file, onProgress));
    } catch (e) {
      return Result.err(_failReason(e));
    }
  }

  Future<UploadedFile> _upload(
    Chat chat,
    OutgoingAttachment file,
    void Function(double progress)? onProgress,
  ) async {
    final data = asMap(
      await _remote.uploadFile(
        path: file.path,
        name: file.name,
        mime: file.mime,
        phone: chat.phone,
        onProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      ),
    );
    final id = nonEmpty(asStr(data?['file_id']));
    if (id == null) throw StateError('la respuesta no trae file_id');
    return UploadedFile(fileId: id, fileName: asStr(data?['file_name']));
  }

  static Uint8List? _decodeBase64(Object? data) {
    if (data is! String) return null;
    var s = data.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    final comma = s.indexOf(',');
    if (s.startsWith('data:') && comma >= 0) s = s.substring(comma + 1);
    s = s.replaceAll(RegExp(r'\s'), '');
    return base64.decode(base64.normalize(s));
  }

  @override
  Future<Result<MediaPreview>> mediaPreview(
    RemoteMediaKind kind,
    String mediaId,
    String messageId,
  ) => _guard(() async {
    final m = asMap(await _remote.mediaPreview(kind, mediaId, messageId));
    final pv = asMap(m?['preview']);
    List<int>? thumb;
    try {
      thumb = _decodeBase64(pv?['image']);
    } catch (_) {}
    final duration = asDouble(asMap(m?['meta'])?['duration']);
    return MediaPreview(
      id: nonEmpty(asStr(m?['id'])) ?? mediaId,
      mime: nonEmpty(asStr(m?['mime'])),
      durationSeconds: duration,
      thumbnailBytes: thumb,
      filename: nonEmpty(asStr(m?['filename'])),
      extension: nonEmpty(asStr(m?['extension'])),
    );
  });

  @override
  Future<Result<Uint8List?>> mediaDownload(RemoteMediaKind kind, String id) =>
      _guard(() async => _decodeBase64(await _remote.mediaDownload(kind, id)));

  @override
  Future<Result<List<QuickAnswer>>> quickAnswers() => _guard(() async {
    final data = await _remote.quickAnswers();
    final raw = data is List ? data : asList(asMap(data)?['results']);
    final out = <QuickAnswer>[];
    for (final r in raw) {
      final m = asMap(r);
      final id = nonEmpty(asStr(m?['id']));
      final title = nonEmpty(asStr(m?['title']));
      if (id == null || title == null) continue;
      out.add(
        QuickAnswer(
          id: id,
          title: title,
          message: nonEmpty(asStr(m?['message'])),
          imageUrl: nonEmpty(asStr(m?['image_url'])),
        ),
      );
    }
    return out;
  });

  @override
  Future<Result<Uint8List>> downloadBytes(String url) =>
      _guard(() => _remote.downloadBytes(url));

  @override
  Future<Result<List<MessageTemplate>>> templates() => _guard(() async {
    final data = await _remote.templates();
    final raw = data is List ? data : asList(asMap(data)?['results']);
    final out = <MessageTemplate>[];
    for (final r in raw) {
      final m = asMap(r);
      final name = nonEmpty(asStr(m?['name']));
      if (m == null || name == null) continue;
      final comps = <TemplateComponent>[];
      for (final c in asList(m['components'])) {
        final cm = asMap(c);
        if (cm == null) continue;
        comps.add(
          TemplateComponent(
            type: (asStr(cm['type']) ?? '').toUpperCase(),
            format: asStr(cm['format'])?.toUpperCase(),
            text: asStr(cm['text']),
            raw: cm,
          ),
        );
      }
      out.add(
        MessageTemplate(
          id: asStr(m['id']) ?? name,
          name: name,
          language: asStr(m['language']) ?? 'es',
          status: (asStr(m['status']) ?? '').toUpperCase(),
          category: asStr(m['category']),
          components: comps,
          message: asStr(m['message']),
        ),
      );
    }
    return out;
  });

  @override
  Future<Result<SendOutcome>> sendTemplate({
    required Chat chat,
    required MessageTemplate template,
    required Map<String, String> values,
    String? userId,
  }) async {
    try {
      final status = await _remote.sendTemplate({
        'recipient_phone_number': chat.phone,
        'template_name': template.name,
        'language_code': template.language,
        'components': template.buildComponents(values),
        'responsible_id': ?userId,
        'message': template.render(values),
        'reference': 'backoffice',
      });
      return Result.ok(
        status == 200 || status == 201
            ? const SendOutcome(SendStatus.sent)
            : const SendOutcome(SendStatus.rejected),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409) {
        return Result.ok(const SendOutcome(SendStatus.conflict));
      }
      if (status == 400) {
        return Result.ok(const SendOutcome(SendStatus.rejected));
      }
      return Result.err(_fail(e));
    } catch (e) {
      return Result.err(_fail(e));
    }
  }

  // ---- Notas, etiquetas, problemas y recordatorio (Fase 5B) -----------------

  List<Object?> _items(Object? data) =>
      data is List ? data : asList(asMap(data)?['results']);

  @override
  Future<Result<List<ClientNote>>> clientNotes(
    String clientId,
  ) => _guard(() async {
    final out = <ClientNote>[];
    for (final r in _items(await _remote.clientNotes(clientId))) {
      final m = asMap(r);
      final id = nonEmpty(asStr(m?['id']));
      final comment = nonEmpty(asStr(m?['comment']));
      if (id == null || comment == null) continue;
      final u = m?['user'];
      final um = asMap(u);
      final name = um == null
          ? null
          : nonEmpty(
              '${asStr(um['first_name']) ?? ''} ${asStr(um['last_name']) ?? ''}'
                  .trim(),
            );
      out.add(
        ClientNote(
          id: id,
          comment: comment,
          authorId: nonEmpty(asStr(um == null ? u : um['id'])),
          authorName: name,
          createdAt: asDate(m?['created_at']),
        ),
      );
    }
    return out;
  });

  @override
  Future<Result<bool>> addClientNote({
    required String clientId,
    required String userId,
    required String comment,
  }) => _guard(() async {
    await _remote.addClientNote({
      'client': clientId,
      'user': userId,
      'comment': comment,
    });
    return true;
  });

  @override
  Future<Result<bool>> deleteClientNote(String id) => _guard(() async {
    await _remote.deleteClientNote(id);
    return true;
  });

  List<ClientTag> _tags(Object? data) {
    final out = <ClientTag>[];
    for (final r in _items(data)) {
      final m = asMap(r);
      final id = nonEmpty(asStr(m?['id']));
      final name = nonEmpty(asStr(m?['name']));
      if (id == null || name == null) continue;
      out.add(
        ClientTag(
          id: id,
          name: name,
          color: nonEmpty(asStr(m?['color'])),
          isSystem: asBool(m?['is_system_tag']) ?? false,
        ),
      );
    }
    return out;
  }

  @override
  Future<Result<List<ClientTag>>> allTags() =>
      _guard(() async => _tags(await _remote.allTags()));

  @override
  Future<Result<List<ClientTag>>> clientTags(String clientId) =>
      _guard(() async => _tags(await _remote.clientTags(clientId)));

  @override
  Future<Result<bool>> toggleTag(String tagId, String clientId) =>
      _guard(() async {
        await _remote.toggleTag(tagId, clientId);
        return true;
      });

  @override
  Future<Result<List<ClientIssue>>> clientIssues(String clientId) =>
      _guard(() async {
        final out = <ClientIssue>[];
        for (final r in _items(await _remote.clientIssues(clientId))) {
          final m = asMap(r);
          final id = nonEmpty(asStr(m?['id']));
          if (id == null || asBool(m?['is_resolved']) == true) continue;
          out.add(
            ClientIssue(
              id: id,
              type: asStr(m?['type']) ?? 'other',
              comment: nonEmpty(asStr(m?['comment'])),
              createdAt: asDate(m?['created_at']),
            ),
          );
        }
        return out;
      });

  @override
  Future<Result<bool>> createIssue({
    required String clientId,
    required String type,
    String? comment,
  }) => _guard(() async {
    await _remote.createIssue({
      'type': type,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
      'client': clientId,
    });
    return true;
  });

  @override
  Future<Result<bool>> resolveIssue(String id) => _guard(() async {
    await _remote.resolveIssue(id);
    return true;
  });

  @override
  Future<Result<bool>> createReminder({
    required String chatId,
    required String userId,
    required String unit,
    required int time,
    required String comment,
  }) => _guard(() async {
    await _remote.createReminder({
      'reminder_type': unit,
      'chat_id': chatId,
      'responsible': userId,
      'reminder_time': time,
      'comment': comment,
    });
    return true;
  });
}
