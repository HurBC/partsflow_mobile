import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorage storage,
    required String baseUrl,
    this.onSessionExpired,
  }) : _storage = storage,
       _refreshDio = Dio(BaseOptions(baseUrl: baseUrl));

  final SecureStorage _storage;
  final Dio _refreshDio;
  final VoidCallback? onSessionExpired;

  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(StorageKeys.token);

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
    final is401 = err.response?.statusCode == 401;
    final isRefreshCall = err.requestOptions.path.contains('refresh_token');

    if (!is401 || isRefreshCall || _isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;

    try {
      final refreshed = await _tryRefresh();

      if (refreshed) {
        final newToken = await _storage.read(StorageKeys.token);

        err.requestOptions.headers['Authorization'] = newToken;

        final retried = await _refreshDio.fetch(err.requestOptions);

        handler.resolve(retried);
      } else {
        await _clearSession();

        handler.next(err);
      }
    } catch (_) {
      await _clearSession();

      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.read(StorageKeys.refreshToken);
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post(
        'users/refresh_token/',
        data: {'refresh_token': refreshToken},
      );

      await _storage.write(StorageKeys.token, response.data['token'] as String);

      final newRefresh = response.data['refresh_token'] as String?;
      if (newRefresh != null) {
        await _storage.write(StorageKeys.refreshToken, newRefresh);
      }

      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> _clearSession() async {
    await _storage.deleteAll();

    onSessionExpired?.call();
  }
}
