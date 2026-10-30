import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/network/token_refresher.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';

/// Inyecta el JWT y lo renueva: antes de la request si vence en < 60 s, y ante
/// un 401 (una sola vez por request). El refresh va por [TokenRefresher]
/// (otro Dio, un solo vuelo), así no pasa por este interceptor.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorage storage,
    required TokenRefresher refresher,
    required Dio retryDio,
    this.onSessionExpired,
  }) : _storage = storage,
       _refresher = refresher,
       _retryDio = retryDio;

  static const _retriedKey = 'pf_auth_retried';

  final SecureStorage _storage;
  final TokenRefresher _refresher;
  final Dio _retryDio;
  final VoidCallback? onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var token = await _storage.read(StorageKeys.token);

    if (token != null && TokenRefresher.isExpiring(token)) {
      pfLog('auth: token por vencer antes de ${options.method} ${options.path}');
      final result = await _refresher.refresh();
      if (result == RefreshResult.rejected) {
        onSessionExpired?.call();
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'session_expired',
          ),
        );
      }
      token = await _storage.read(StorageKeys.token);
    }

    if (token != null) {
      options.headers['Authorization'] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final usedToken = req.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        req.extra[_retriedKey] == true ||
        usedToken == null) {
      return handler.next(err);
    }

    final current = await _storage.read(StorageKeys.token);
    if (current == null) return handler.next(err);

    // Si otro request ya renovó mientras éste volaba, basta reintentar.
    if (current == usedToken) {
      pfLog('auth: 401 en ${req.method} ${req.path}, refrescando');
      final result = await _refresher.refresh();
      if (result == RefreshResult.rejected) {
        onSessionExpired?.call();
        return handler.next(err);
      }
      if (result == RefreshResult.transient) return handler.next(err);
    }

    try {
      final newToken = await _storage.read(StorageKeys.token);
      req.headers['Authorization'] = newToken;
      req.extra[_retriedKey] = true;
      pfLog('auth: reintentando ${req.method} ${req.path}');
      handler.resolve(await _retryDio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
