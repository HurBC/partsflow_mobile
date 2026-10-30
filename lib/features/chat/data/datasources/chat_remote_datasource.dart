import 'dart:typed_data';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';

/// Llamadas HTTP crudas a SAPI; devuelve el JSON sin interpretar.
/// Los errores de red/HTTP se relanzan como [DioException].
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Object?> searchChats(Map<String, dynamic> params) async =>
      (await _dio.get<Object?>('chat/search/', queryParameters: params)).data;

  Future<Object?> clientStatuses() async =>
      (await _dio.get<Object?>('clients/statuses/')).data;

  Future<Object?> history(String phone, int page, int limit) async =>
      (await _dio.get<Object?>(
        'chat/message_history/',
        queryParameters: {'phone': phone, 'limit': limit, 'offset': page},
      )).data;

  /// Devuelve (statusCode, body).
  Future<(int, Object?)> sendMessage(Map<String, Object?> body) async {
    if (pfDebugLog) {
      // Sin datos personales: teléfono enmascarado y el texto solo como largo.
      final safe = <String, Object?>{
        for (final e in body.entries)
          e.key: switch (e.key) {
            'phone' || 'chat_id' => maskPhoneForLog(e.value?.toString()),
            'message' => '<${e.value?.toString().length ?? 0} chars>',
            _ => e.value,
          },
      };
      pfLog('send_message → $safe');
    }
    final r = await _dio.post<Object?>('chat/send_message/', data: body);
    pfLog('send_message ← status=${r.statusCode} body=${truncateLog(r.data)}');
    return (r.statusCode ?? 0, r.data);
  }

  Future<void> setLastSellerMessage(String phone) =>
      _dio.patch<Object?>('clients/$phone/set_last_seller_message/');

  Future<void> readChat(String chatId) =>
      _dio.post<Object?>('chat/read_chat/', data: {'phone': chatId});

  Future<int> markUnread(String chatId) async =>
      (await _dio.patch<Object?>(
        'chat/mark_unread/',
        data: {'phone': chatId, 'unread': true},
      )).statusCode ??
      0;

  Future<void> updateClient(String clientId, Map<String, Object?> body) =>
      _dio.patch<Object?>('clients/$clientId/update/', data: body);

  Future<Object?> supplier(String subsidiaryId) async =>
      (await _dio.get<Object?>('suppliers/$subsidiaryId/')).data;

  Future<Object?> activeOrders(
    String clientId,
  ) async => (await _dio.get<Object?>(
    'orders/kanban/',
    queryParameters: {
      'client': clientId,
      'sort_by': '-created_at',
      'status':
          'identifying_car,identifying_products,searching_oems,searching_stock,order_quoted,quotation_sent,options_accepted,purchase_completed,devolution_requested',
      'limit': 5,
    },
  )).data;

  // ---- Extras (Fase 5A) -----------------------------------------------------

  static const _long = Duration(minutes: 3);

  Future<Object?> uploadFile({
    required String path,
    required String name,
    required String mime,
    required String phone,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (pfDebugLog) {
      var bytes = -1;
      try {
        bytes = await File(path).length();
      } catch (_) {}
      pfLog(
        'upload → file=$name mime=$mime bytes=$bytes '
        'phone=${maskPhoneForLog(phone)}',
      );
    }
    final form = FormData.fromMap({
      // SAPI reenvía a Wali el content-type de esta parte (no el campo `type`);
      // sin él llega como octet-stream y Wali no trata el audio como audio.
      'file': await MultipartFile.fromFile(
        path,
        filename: name,
        contentType: DioMediaType.parse(mime),
      ),
      'filename': name,
      'permission': 'public',
      'type': mime,
      'format': 'native',
      'phone': phone,
    });
    final res = await _dio.post<Object?>(
      'chat/files/upload/',
      data: form,
      onSendProgress: onProgress,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: _long,
        receiveTimeout: _long,
      ),
    );
    pfLog('upload ← status=${res.statusCode} body=${truncateLog(res.data)}');
    return res.data;
  }

  static String _kindPath(RemoteMediaKind k) => switch (k) {
    RemoteMediaKind.audio => 'audio',
    RemoteMediaKind.video => 'video',
    RemoteMediaKind.document => 'documents',
  };

  Future<Object?> mediaPreview(
    RemoteMediaKind kind,
    String mediaId,
    String messageId,
  ) async => (await _dio.get<Object?>(
    'chat/files/${_kindPath(kind)}/preview/',
    queryParameters: {'file_id': mediaId, 'message_id': messageId},
    options: Options(receiveTimeout: _long),
  )).data;

  Future<Object?> mediaDownload(RemoteMediaKind kind, String id) async =>
      (await _dio.get<Object?>(
        'chat/files/${_kindPath(kind)}/download/',
        queryParameters: {'file_id': id},
        options: Options(receiveTimeout: _long),
      )).data;

  Future<Object?> quickAnswers() async => (await _dio.get<Object?>(
    'supplier_chats/quick_answer/',
    queryParameters: {'limit': 300},
  )).data;

  /// Descarga una imagen pública (cliente sin credenciales de SAPI).
  Future<Uint8List> downloadBytes(String url) async {
    final r = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, receiveTimeout: _long),
    );
    return Uint8List.fromList(r.data ?? const []);
  }

  Future<Object?> templates() async =>
      (await _dio.get<Object?>('chat/template_messages/')).data;

  Future<int> sendTemplate(Map<String, Object?> body) async =>
      (await _dio.post<Object?>(
        'chat/send_template_message/',
        data: body,
      )).statusCode ??
      0;

  // ---- Notas, etiquetas, problemas y recordatorio (Fase 5B) -----------------

  Future<Object?> clientNotes(String clientId) async =>
      (await _dio.get<Object?>(
        'clients/comments/',
        queryParameters: {'client': clientId, 'limit': 50},
      )).data;

  Future<void> addClientNote(Map<String, Object?> body) =>
      _dio.post<Object?>('clients/comments/', data: body);

  Future<void> deleteClientNote(String id) =>
      _dio.delete<Object?>('clients/comments/$id/delete');

  Future<Object?> allTags() async => (await _dio.get<Object?>(
    'clients/tags/',
    queryParameters: {'limit': 100},
  )).data;

  Future<Object?> clientTags(String clientId) async => (await _dio.get<Object?>(
    'clients/tags/',
    queryParameters: {'client_id': clientId},
  )).data;

  /// Toggle en el servidor (sin body).
  Future<void> toggleTag(String tagId, String clientId) =>
      _dio.patch<Object?>('clients/tags/$tagId/assign/$clientId/');

  Future<Object?> clientIssues(String clientId) async =>
      (await _dio.get<Object?>(
        'clients/issues/',
        queryParameters: {'client_id': clientId},
      )).data;

  Future<void> createIssue(Map<String, Object?> body) =>
      _dio.post<Object?>('clients/issues/', data: body);

  Future<void> resolveIssue(String id) => _dio.patch<Object?>(
    'clients/issues/$id/update/',
    data: {'is_resolved': true},
  );

  Future<void> createReminder(Map<String, Object?> body) =>
      _dio.post<Object?>('clients/reminder/', data: body);
}
